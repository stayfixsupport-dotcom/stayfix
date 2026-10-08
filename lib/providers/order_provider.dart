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
  String? _currentUserId;
  bool _isDirector = false;
  String _userRole = ''; // the role of the logged-in user

  // ── State ──────────────────────────────────────────────────────────────────
  static final List<OrgDepartment> _allDepartments = [
    OrgDepartment(id: 'dept_maintenance', hotelId: '', name: 'Maintenance', isActive: true, createdAt: DateTime.utc(2024)),
    OrgDepartment(id: 'dept_housekeeping', hotelId: '', name: 'Propreté', isActive: true, createdAt: DateTime.utc(2024)),
    OrgDepartment(id: 'dept_reception', hotelId: '', name: 'Réception', isActive: true, createdAt: DateTime.utc(2024)),
  ];

  /// Dept IDs that have at least one director-role user — null means not yet loaded.
  Set<String>? _deptIdsWithDirector;
  /// Map of deptId → director's fullName.
  Map<String, String> _directorNames = {};
  List<OrgCategory> _categories = [];
  List<OrgOrder> _activeOrders = [];
  List<OrgOrder> _inboxOrders = [];   // orders received by this dept
  List<OrgOrder> _sentOrders = [];    // orders sent by this dept
  List<OrgOrder> _archivedOrders = [];
  List<OrderNotification> _notifications = [];
  /// Each item: {id, firstName, lastName, fullName, role, deptId}
  List<Map<String, String>> _directorUsers = [];

  bool _isLoading = false;
  String? _error;

  // ── Stream Subscriptions ───────────────────────────────────────────────────
  StreamSubscription<List<OrgDepartment>>? _deptsSubscription;
  StreamSubscription<Set<String>>? _directorDeptsSubscription;
  StreamSubscription<Map<String, String>>? _directorNamesSubscription;
  StreamSubscription<List<Map<String, String>>>? _directorUsersSubscription;
  StreamSubscription<List<OrgCategory>>? _catsSubscription;
  StreamSubscription<List<OrgOrder>>? _ordersSubscription;
  StreamSubscription<List<OrgOrder>>? _sentOrdersSubscription;
  StreamSubscription<List<OrgOrder>>? _archiveSubscription;
  StreamSubscription<List<OrderNotification>>? _notifsSubscription;

  // ── Getters ────────────────────────────────────────────────────────────────
  String? get hotelId => _hotelId;
  String? get currentDeptId => _currentDeptId;
  bool get isDirector => _isDirector;

  /// Returns only departments that have at least one director assigned.
  /// Falls back to all departments while the stream hasn't loaded yet.
  List<OrgDepartment> get departments {
    final ids = _deptIdsWithDirector;
    if (ids == null) return _allDepartments; // not yet loaded → show all
    return _allDepartments.where((d) => ids.contains(d.id)).toList();
  }
  /// Map of deptId → director's fullName (empty string if not yet loaded).
  Map<String, String> get directorNames => _directorNames;
  /// All individual director/manager users (one entry per person).
  List<Map<String, String>> get directorUsers => _directorUsers;
  List<OrgCategory> get categories => _categories;
  List<OrgOrder> get activeOrders => _activeOrders;
  /// Orders sent BY this department (outbox). Separate from inbox.
  List<OrgOrder> get sentOrders => _sentOrders;
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
          ? departments
          : departments
              .where((d) => d.id != _currentDeptId)
              .toList();

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Initialize the provider with context: hotelId, user's deptId, and role.
  /// Call this after the user is authenticated.
  void init({
    required String hotelId,
    required String deptId,
    required bool isDirector,
    String? userId,
    String? userRole,
  }) {
    if (_hotelId == hotelId && _currentDeptId == deptId && _isDirector == isDirector && _currentUserId == userId) return;

    _hotelId = hotelId;
    _currentDeptId = deptId;
    _isDirector = isDirector;
    _currentUserId = userId;
    _userRole = userRole ?? '';

    _cancelAll();
    _subscribeAll();
    notifyListeners();
  }

  void _subscribeAll() {
    final hotel = _hotelId;
    final dept = _currentDeptId;
    if (hotel == null || dept == null) return;

    // Stream which dept IDs have a director assigned — filters the dropdown.
    _directorDeptsSubscription =
        OrderService.streamDeptIdsWithDirector(hotel).listen((ids) {
      _deptIdsWithDirector = ids;
      notifyListeners();
    }, onError: (_) {
      // On error show all depts as a safe fallback.
      _deptIdsWithDirector = {'dept_maintenance', 'dept_housekeeping', 'dept_reception'};
      notifyListeners();
    });

    // Stream director names for the dropdown labels.
    _directorNamesSubscription =
        OrderService.streamDirectorNamesByDept(hotel).listen((names) {
      _directorNames = names;
      notifyListeners();
    }, onError: (_) {});

    // Stream recipient users for the "Envoyer à" picker in create_order.
    // - Director Général → shows the three sub-directors.
    // - Sub-directors and others → shows all worker-role team members.
    final isSubDirector = [
      'Directeur Maintenance',
      'Directeur Gouvernante',
      'Directeur Réception',
    ].contains(_userRole);
    final recipientStream = isSubDirector
        ? OrderService.streamTeamUsers(hotel)
        : OrderService.streamDirectorUsers(hotel);
    _directorUsersSubscription = recipientStream.listen((users) {
      _directorUsers = users;
      notifyListeners();
    }, onError: (_) { _directorUsers = []; });

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
      final uid = _currentUserId ?? '';

      // Active orders — department inbox + orders personally assigned to this user.
      _ordersSubscription = OrderService.streamOrdersForDept(
          hotelId: hotel, deptId: dept, userId: uid).listen((data) {
        _inboxOrders = data;
        _updateActiveOrders();
      }, onError: (e) => _setError(e.toString()));

      // Sent orders — tracked separately, NOT mixed into incoming active orders
      _sentOrdersSubscription = OrderService.streamOrdersCreatedByDept(
          hotelId: hotel, deptId: dept).listen((data) {
        _sentOrders = data;
        _updateActiveOrders();
      }, onError: (e) => _setError(e.toString()));

      // Archive — completed orders for this dept OR personally assigned to this user.
      _archiveSubscription =
          OrderService.streamArchivedOrders(hotelId: hotel, deptId: dept, userId: uid)
              .listen((data) {
        _archivedOrders = data;
        notifyListeners();
      }, onError: (e) => _setError(e.toString()));

      // Notifications — dept-scoped + user-specific personal notifications.
      if (dept.isNotEmpty || uid.isNotEmpty) {
        _notifsSubscription =
            OrderService.streamNotificationsForUser(
                    hotelId: hotel, deptId: dept, userId: uid)
                .listen((data) {
          _notifications = data;
          notifyListeners();
        }, onError: (e) => _setError(e.toString()));
      }
    }
  }

  void _updateActiveOrders() {
    final uniqueOrders = <String, OrgOrder>{};
    for (var o in _inboxOrders) {
      uniqueOrders[o.id] = o;
    }
    for (var o in _sentOrders) {
      uniqueOrders[o.id] = o;
    }
    _activeOrders = uniqueOrders.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
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
    _directorDeptsSubscription?.cancel();
    _directorNamesSubscription?.cancel();
    _directorUsersSubscription?.cancel();
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
    List<String> assignedUserIds = const [],
    List<String> assignedUserNames = const [],
    String? assigneeName,
    bool isForSelf = false,
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
        assignedUserIds: assignedUserIds,
        assignedUserNames: assignedUserNames,
        assigneeName: assigneeName,
        isForSelf: isForSelf,
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
