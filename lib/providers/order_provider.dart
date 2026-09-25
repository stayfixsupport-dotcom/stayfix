import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';

/// ChangeNotifier provider for the Order & Intervention Management module.
/// Manages real-time Firestore streams and exposes state to the UI.
class OrderProvider extends ChangeNotifier {
  // ── Configuration ──────────────────────────────────────────────────────────
  String? _hotelId;
  String? _currentDeptId;
  bool _isDirector = false;

  // ── State ──────────────────────────────────────────────────────────────────
  List<OrgDepartment> _departments = [
    OrgDepartment(id: 'dept_maintenance', hotelId: '', name: 'Maintenance', isActive: true, createdAt: DateTime(2024)),
    OrgDepartment(id: 'dept_housekeeping', hotelId: '', name: 'Propreté', isActive: true, createdAt: DateTime(2024)),
    OrgDepartment(id: 'dept_reception', hotelId: '', name: 'Réception', isActive: true, createdAt: DateTime(2024)),
  ];
  List<OrgCategory> _categories = [];
  List<OrgOrder> _activeOrders = [];
  List<OrgOrder> _inboxOrders = [];   // orders received by this dept
  List<OrgOrder> _sentOrders = [];    // orders sent by this dept
  List<OrgOrder> _archivedOrders = [];
  List<OrderNotification> _notifications = [];

  bool _isLoading = false;
  String? _error;

  // ── Stream Subscriptions ───────────────────────────────────────────────────
  StreamSubscription<List<OrgDepartment>>? _deptsSubscription;
  StreamSubscription<List<OrgCategory>>? _catsSubscription;
  StreamSubscription<List<OrgOrder>>? _ordersSubscription;
  StreamSubscription<List<OrgOrder>>? _sentOrdersSubscription;
  StreamSubscription<List<OrgOrder>>? _archiveSubscription;
  StreamSubscription<List<OrderNotification>>? _notifsSubscription;

  // ── Getters ────────────────────────────────────────────────────────────────
  String? get hotelId => _hotelId;
  String? get currentDeptId => _currentDeptId;
  bool get isDirector => _isDirector;

  List<OrgDepartment> get departments => _departments;
  List<OrgCategory> get categories => _categories;
  List<OrgOrder> get activeOrders => _activeOrders;
  List<OrgOrder> get archivedOrders => _archivedOrders;
  List<OrderNotification> get notifications => _notifications;

  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadNotifCount =>
      _notifications.where((n) => !n.read).length;

  int get unseenOrderCount =>
      _activeOrders.where((o) => o.status == OrderStatus.unseen).length;

  int get inProgressOrderCount =>
      _activeOrders.where((o) => o.status == OrderStatus.inProgress).length;

  List<OrgDepartment> get otherDepartments =>
      _currentDeptId == null
          ? _departments
          : _departments
              .where((d) => d.id != _currentDeptId)
              .toList();

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Initialize the provider with context: hotelId, user's deptId, and role.
  /// Call this after the user is authenticated.
  void init({
    required String hotelId,
    required String deptId,
    required bool isDirector,
  }) {
    if (_hotelId == hotelId && _currentDeptId == deptId && _isDirector == isDirector) return;

    _hotelId = hotelId;
    _currentDeptId = deptId;
    _isDirector = isDirector;

    _cancelAll();
    _subscribeAll();
    notifyListeners();
  }

  void _subscribeAll() {
    final hotel = _hotelId;
    final dept = _currentDeptId;
    if (hotel == null || dept == null) return;

    // Departments are static, no need to stream
    // _deptsSubscription =
    //     OrderService.streamDepartments(hotel).listen((data) {
    //   _departments = data;
    //   notifyListeners();
    // }, onError: (e) => _setError(e.toString()));

    // Categories
    _catsSubscription =
        OrderService.streamCategories(hotel).listen((data) {
      _categories = data;
      notifyListeners();
    }, onError: (e) => _setError(e.toString()));

    if (_isDirector) {
      // Directors see ALL active orders hotel-wide.
      _ordersSubscription =
          OrderService.streamAllOrders(hotel).listen((data) {
        _activeOrders = data;
        notifyListeners();
      }, onError: (e) => _setError(e.toString()));

      // Directors see ALL archived orders.
      _archiveSubscription =
          OrderService.streamArchivedOrders(hotelId: hotel)
              .listen((data) {
        _archivedOrders = data;
        notifyListeners();
      }, onError: (e) => _setError(e.toString()));

      // Directors have no dept-scoped notification stream.
      // (They see global order state directly via the orders stream.)
    } else {
      // Active orders — ONLY orders assigned to this target department!
      _ordersSubscription = OrderService.streamOrdersForDept(
          hotelId: hotel, deptId: dept).listen((data) {
        _inboxOrders = data;
        _activeOrders = List.from(data);
        notifyListeners();
      }, onError: (e) => _setError(e.toString()));

      // Sent orders — tracked separately, NOT mixed into incoming active orders
      _sentOrdersSubscription = OrderService.streamOrdersCreatedByDept(
          hotelId: hotel, deptId: dept).listen((data) {
        _sentOrders = data;
        notifyListeners();
      }, onError: (e) => _setError(e.toString()));

      // Archive — ONLY completed orders for this target department!
      _archiveSubscription =
          OrderService.streamArchivedOrders(hotelId: hotel, deptId: dept)
              .listen((data) {
        _archivedOrders = data;
        notifyListeners();
      }, onError: (e) => _setError(e.toString()));

      // Notifications — scoped to this target department
      if (dept.isNotEmpty) {
        _notifsSubscription =
            OrderService.streamNotificationsForDept(
                    hotelId: hotel, deptId: dept)
                .listen((data) {
          _notifications = data;
          notifyListeners();
        }, onError: (e) => _setError(e.toString()));
      }
    }
  }

  /// Switch the active department view (for directors or managers switching context).
  void selectDepartment(String deptId) {
    if (_currentDeptId == deptId) return;
    _currentDeptId = deptId;
    _cancelAll();
    _subscribeAll();
    notifyListeners();
  }

  void _cancelAll() {
    _deptsSubscription?.cancel();
    _catsSubscription?.cancel();
    _ordersSubscription?.cancel();
    _sentOrdersSubscription?.cancel();
    _archiveSubscription?.cancel();
    _notifsSubscription?.cancel();
  }

  void _setError(String msg) {
    _error = msg;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Order Actions ──────────────────────────────────────────────────────────

  Future<String?> createOrder({
    required String creatorId,
    required String creatorName,
    required String creatorDeptId,
    required String creatorDeptName,
    required String categoryId,
    required String categoryName,
    required String description,
    required OrderLocationType locationType,
    String? roomNumber,
    String? locationDetail,
    required String destDeptId,
    required String destDeptName,
  }) async {
    final hotel = _hotelId;
    if (hotel == null) return null;
    _setLoading(true);
    try {
      final id = await OrderService.createOrder(
        hotelId: hotel,
        creatorId: creatorId,
        creatorName: creatorName,
        creatorDeptId: creatorDeptId,
        creatorDeptName: creatorDeptName,
        categoryId: categoryId,
        categoryName: categoryName,
        description: description,
        locationType: locationType,
        roomNumber: roomNumber,
        locationDetail: locationDetail,
        destDeptId: destDeptId,
        destDeptName: destDeptName,
      );
      return id;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateOrderDescription(String orderId, String description) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    _setLoading(true);
    try {
      await OrderService.updateOrderDescription(
        hotelId: hotel,
        orderId: orderId,
        description: description,
      );
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markSeen({
    required String orderId,
    required String byUserId,
    required String byUserName,
  }) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    try {
      await OrderService.markSeen(
        hotelId: hotel,
        orderId: orderId,
        byUserId: byUserId,
        byUserName: byUserName,
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> markCompleted({
    required String orderId,
    required String byUserId,
    required String byUserName,
  }) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    try {
      await OrderService.markCompleted(
        hotelId: hotel,
        orderId: orderId,
        byUserId: byUserId,
        byUserName: byUserName,
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> forwardOrder({
    required String orderId,
    required String fromDeptId,
    required String fromDeptName,
    required String toDeptId,
    required String toDeptName,
    required String byUserId,
    required String byUserName,
  }) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    try {
      await OrderService.forwardOrder(
        hotelId: hotel,
        orderId: orderId,
        fromDeptId: fromDeptId,
        fromDeptName: fromDeptName,
        toDeptId: toDeptId,
        toDeptName: toDeptName,
        byUserId: byUserId,
        byUserName: byUserName,
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> assignCategory({
    required String orderId,
    required String categoryId,
    required String categoryName,
    required String byUserId,
    required String byUserName,
  }) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    try {
      await OrderService.assignCategory(
        hotelId: hotel,
        orderId: orderId,
        categoryId: categoryId,
        categoryName: categoryName,
        byUserId: byUserId,
        byUserName: byUserName,
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<List<OrderHistoryEntry>> fetchHistory(String orderId) async {
    final hotel = _hotelId;
    if (hotel == null) return [];
    try {
      return await OrderService.fetchHistory(
          hotelId: hotel, orderId: orderId);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<List<OrgOrder>> fetchOrdersForDate(DateTime date) async {
    final hotel = _hotelId;
    if (hotel == null) return [];
    try {
      return await OrderService.fetchOrdersForDate(
          hotelId: hotel, date: date);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  // ── Notification Actions ───────────────────────────────────────────────────

  Future<void> markNotificationRead(String notifId) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    await OrderService.markNotificationRead(
        hotelId: hotel, notifId: notifId);
  }

  Future<void> markAllNotificationsRead() async {
    final hotel = _hotelId;
    final dept = _currentDeptId;
    if (hotel == null || dept == null) return;
    await OrderService.markAllNotificationsRead(
        hotelId: hotel, deptId: dept);
  }

  // ── Admin Actions ──────────────────────────────────────────────────────────

  Future<void> createDepartment(String name) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    _setLoading(true);
    try {
      await OrderService.createDepartment(hotelId: hotel, name: name);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateDepartment(
      {required String deptId, String? name, bool? isActive}) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    _setLoading(true);
    try {
      await OrderService.updateDepartment(
          hotelId: hotel,
          deptId: deptId,
          name: name,
          isActive: isActive);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createCategory(String name) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    _setLoading(true);
    try {
      await OrderService.createCategory(hotelId: hotel, name: name);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateCategory(
      {required String catId, String? name, bool? isActive}) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    _setLoading(true);
    try {
      await OrderService.updateCategory(
          hotelId: hotel, catId: catId, name: name, isActive: isActive);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteCategory(String catId) async {
    final hotel = _hotelId;
    if (hotel == null) return;
    _setLoading(true);
    try {
      await OrderService.deleteCategory(hotelId: hotel, catId: catId);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrgUsers() async {
    final hotel = _hotelId;
    if (hotel == null) return [];
    return await OrderService.fetchOrgUsers(hotel);
  }

  Future<void> assignUserToDepartment({
    required String userId,
    required String deptId,
    required String deptName,
    required String orgRole,
  }) async {
    await OrderService.assignUserToDepartment(
        userId: userId,
        deptId: deptId,
        deptName: deptName,
        orgRole: orgRole);
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }
}
