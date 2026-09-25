import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_models.dart';

/// Central service for all Order & Intervention module Firestore operations.
/// All data is scoped under /hotels/{hotelId}/.
class OrderService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Collection Helpers ─────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _depts(String hotelId) =>
      _db.collection('hotels').doc(hotelId).collection('org_departments');

  static CollectionReference<Map<String, dynamic>> _cats(String hotelId) =>
      _db.collection('hotels').doc(hotelId).collection('org_categories');

  static CollectionReference<Map<String, dynamic>> _orders(String hotelId) =>
      _db.collection('hotels').doc(hotelId).collection('org_orders');

  static CollectionReference<Map<String, dynamic>> _history(
          String hotelId, String orderId) =>
      _db
          .collection('hotels')
          .doc(hotelId)
          .collection('org_orders')
          .doc(orderId)
          .collection('history');

  static CollectionReference<Map<String, dynamic>> _notifs(String hotelId) =>
      _db.collection('hotels').doc(hotelId).collection('org_notifications');

  // ── Current User Helper ───────────────────────────────────────────────────

  static String get _uid => _auth.currentUser?.uid ?? '';

  // ══════════════════════════════════════════════════════════════════════════
  //  DEPARTMENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Real-time stream of all active departments for a hotel.
  static Stream<List<OrgDepartment>> streamDepartments(String hotelId) {
    return _depts(hotelId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => OrgDepartment.fromDoc(d)).toList());
  }

  /// One-time fetch of all departments (including inactive) for admin use.
  static Future<List<OrgDepartment>> fetchAllDepartments(
      String hotelId) async {
    final snap =
        await _depts(hotelId).orderBy('name').get();
    return snap.docs.map((d) => OrgDepartment.fromDoc(d)).toList();
  }

  /// Create a new department.
  static Future<void> createDepartment(
      {required String hotelId, required String name}) async {
    await _depts(hotelId).add({
      'name': name.trim(),
      'isActive': true,
      'hotelId': hotelId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _uid,
    });
  }

  /// Update a department's name or active status.
  static Future<void> updateDepartment(
      {required String hotelId,
      required String deptId,
      String? name,
      bool? isActive}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (isActive != null) updates['isActive'] = isActive;
    if (updates.isEmpty) return;
    await _depts(hotelId).doc(deptId).update(updates);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CATEGORIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Real-time stream of all active categories.
  static Stream<List<OrgCategory>> streamCategories(String hotelId) {
    return _cats(hotelId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => OrgCategory.fromDoc(d))
              .where((c) => c.isActive)
              .toList();
          list.sort((a, b) => a.name.compareTo(b.name));
          return list;
        });
  }

  /// One-time fetch of all categories (including inactive) for admin.
  static Future<List<OrgCategory>> fetchAllCategories(
      String hotelId) async {
    final snap = await _cats(hotelId).orderBy('name').get();
    return snap.docs.map((d) => OrgCategory.fromDoc(d)).toList();
  }

  /// Create a new category.
  static Future<void> createCategory(
      {required String hotelId, required String name}) async {
    await _cats(hotelId).add({
      'name': name.trim(),
      'isActive': true,
      'hotelId': hotelId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _uid,
    });
  }

  /// Update a category's name or active status.
  static Future<void> updateCategory(
      {required String hotelId,
      required String catId,
      String? name,
      bool? isActive}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (isActive != null) updates['isActive'] = isActive;
    if (updates.isEmpty) return;
    await _cats(hotelId).doc(catId).update(updates);
  }

  /// Delete a category.
  static Future<void> deleteCategory(
      {required String hotelId, required String catId}) async {
    await _cats(hotelId).doc(catId).delete();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ASSIGN CATEGORY (Director action on uncategorised orders)
  // ══════════════════════════════════════════════════════════════════════════

  /// Assign (or update) the category of an existing order.
  /// Used by department directors when they receive an uncategorised order.
  static Future<void> assignCategory({
    required String hotelId,
    required String orderId,
    required String categoryId,
    required String categoryName,
    required String byUserId,
    required String byUserName,
  }) async {
    final batch = _db.batch();

    // Update the order document
    batch.update(_orders(hotelId).doc(orderId), {
      'categoryId': categoryId,
      'categoryName': categoryName,
    });

    // History entry
    final histRef = _history(hotelId, orderId).doc();
    batch.set(histRef, {
      'action': 'category_assigned',
      'byUserId': byUserId,
      'byUserName': byUserName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ORDERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Real-time stream of orders for a department (active only — not completed).
  static Stream<List<OrgOrder>> streamOrdersForDept(
      {required String hotelId, required String deptId}) {
    return _orders(hotelId)
        .where('currentDeptId', isEqualTo: deptId)
        .where('status', whereIn: ['unseen', 'in_progress'])
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => OrgOrder.fromDoc(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Real-time stream of orders CREATED BY a department (sent outbox view).
  static Stream<List<OrgOrder>> streamOrdersCreatedByDept(
      {required String hotelId, required String deptId}) {
    return _orders(hotelId)
        .where('creatorDeptId', isEqualTo: deptId)
        .where('status', whereIn: ['unseen', 'in_progress'])
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => OrgOrder.fromDoc(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Real-time stream of ALL orders for the hotel (Director view).
  static Stream<List<OrgOrder>> streamAllOrders(String hotelId) {
    return _orders(hotelId)
        .where('status', whereIn: ['unseen', 'in_progress'])
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => OrgOrder.fromDoc(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Real-time stream of completed (archived) orders for a specific department (or all).
  static Stream<List<OrgOrder>> streamArchivedOrders(
      {required String hotelId, String? deptId}) {
    Query<Map<String, dynamic>> query =
        _orders(hotelId).where('status', isEqualTo: 'completed');
    if (deptId != null && deptId.isNotEmpty) {
      query = query.where('currentDeptId', isEqualTo: deptId);
    }
    // Limit to the most recent 100 to prevent massive delays on app launch
    return query.limit(100).snapshots().map((snap) {
      final list = snap.docs.map((d) => OrgOrder.fromDoc(d)).toList();
      list.sort((a, b) => (b.completedAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.createdAt));
      return list;
    });
  }

  /// Fetch completed orders for a specific date (for calendar).
  static Future<List<OrgOrder>> fetchOrdersForDate({
    required String hotelId,
    required DateTime date,
    String? deptId,
  }) async {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
    Query<Map<String, dynamic>> query = _orders(hotelId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(end));
    if (deptId != null && deptId.isNotEmpty) {
      query = query.where('currentDeptId', isEqualTo: deptId);
    }
    final snap = await query.orderBy('completedAt', descending: false).get();
    return snap.docs.map((d) => OrgOrder.fromDoc(d)).toList();
  }

  /// Fetch the history sub-collection for an order.
  static Future<List<OrderHistoryEntry>> fetchHistory(
      {required String hotelId, required String orderId}) async {
    final snap = await _history(hotelId, orderId)
        .orderBy('timestamp', descending: false)
        .get();
    return snap.docs
        .map((d) => OrderHistoryEntry.fromDoc(d))
        .toList();
  }

  /// Create a new order and its first history entry in a batch write.
  static Future<String> createOrder({
    required String hotelId,
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
    final batch = _db.batch();

    // Order document
    final orderRef = _orders(hotelId).doc();
    final orderData = {
      'hotelId': hotelId,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorDeptId': creatorDeptId,
      'creatorDeptName': creatorDeptName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'description': description.trim(),
      'locationType': locationType.toValue(),
      if (roomNumber != null && roomNumber.isNotEmpty)
        'roomNumber': roomNumber.trim(),
      if (locationDetail != null && locationDetail.isNotEmpty)
        'locationDetail': locationDetail.trim(),
      'currentDeptId': destDeptId,
      'currentDeptName': destDeptName,
      'initialDeptId': destDeptId,
      'initialDeptName': destDeptName,
      'status': 'unseen',
      'createdAt': FieldValue.serverTimestamp(),
    };
    batch.set(orderRef, orderData);

    // First history entry
    final historyRef = _history(hotelId, orderRef.id).doc();
    batch.set(historyRef, {
      'action': 'created',
      'toDeptId': destDeptId,
      'toDeptName': destDeptName,
      'byUserId': creatorId,
      'byUserName': creatorName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Notification to destination department members
    final notifRef = _notifs(hotelId).doc();
    batch.set(notifRef, {
      'hotelId': hotelId,
      'deptId': destDeptId,
      'orderId': orderRef.id,
      'title': 'Nouvel ordre reçu',
      'message':
          'Un nouvel ordre vous a été envoyé par $creatorName ($creatorDeptName).',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return orderRef.id;
  }

  /// Create a routine order as 'unseen' so it flows into the active orders dashboard.
  static Future<void> launchRoutineTask({
    required String hotelId,
    required String templateId,
    required String taskName,
    required String deptId,
    required String deptName,
    required String categoryId,
    required String categoryName,
    required OrderLocationType locationType,
    String? roomNumber,
    String? locationDetail,
    required String byUserId,
    required String byUserName,
    required String dateString,
  }) async {
    final batch = _db.batch();

    final orderRef = _orders(hotelId).doc();
    batch.set(orderRef, {
      'hotelId': hotelId,
      'creatorId': byUserId,
      'creatorName': byUserName,
      'creatorDeptId': deptId,
      'creatorDeptName': deptName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'description': taskName,
      'locationType': locationType.toValue(),
      if (roomNumber != null && roomNumber.isNotEmpty)
        'roomNumber': roomNumber.trim(),
      if (locationDetail != null && locationDetail.isNotEmpty)
        'locationDetail': locationDetail.trim(),
      'currentDeptId': deptId,
      'currentDeptName': deptName,
      'initialDeptId': deptId,
      'initialDeptName': deptName,
      'status': 'unseen', // <--- Changed from completed
      'isRoutine': true,
      'routineTemplateId': templateId,
      'routineDateString': dateString,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // History entry
    final histRef = _history(hotelId, orderRef.id).doc();
    batch.set(histRef, {
      'action': 'created',
      'byUserId': byUserId,
      'byUserName': byUserName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Undo a routine task completion for today (deletes the order).
  static Future<void> uncompleteRoutineTask({
    required String hotelId,
    required String templateId,
    required String dateString,
  }) async {
    final snap = await _orders(hotelId)
        .where('isRoutine', isEqualTo: true)
        .where('routineTemplateId', isEqualTo: templateId)
        .where('routineDateString', isEqualTo: dateString)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Stream routine orders (completed or not) for a specific date.
  static Stream<List<OrgOrder>> streamRoutineOrdersForDate({
    required String hotelId,
    required String dateString,
    String? deptId,
  }) {
    Query<Map<String, dynamic>> query = _orders(hotelId)
        .where('isRoutine', isEqualTo: true)
        .where('routineDateString', isEqualTo: dateString);
    if (deptId != null && deptId.isNotEmpty) {
      query = query.where('currentDeptId', isEqualTo: deptId);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => OrgOrder.fromDoc(d)).toList());
  }

  /// Update an order's description.
  static Future<void> updateOrderDescription({
    required String hotelId,
    required String orderId,
    required String description,
  }) async {
    await _orders(hotelId).doc(orderId).update({
      'description': description.trim(),
    });
  }

  /// Mark an order as seen (status: in_progress).
  static Future<void> markSeen({
    required String hotelId,
    required String orderId,
    required String byUserId,
    required String byUserName,
  }) async {
    final batch = _db.batch();

    batch.update(_orders(hotelId).doc(orderId), {
      'status': 'in_progress',
      'seenAt': FieldValue.serverTimestamp(),
    });

    final histRef = _history(hotelId, orderId).doc();
    batch.set(histRef, {
      'action': 'seen',
      'byUserId': byUserId,
      'byUserName': byUserName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Mark an order as in_progress explicitly.
  static Future<void> markInProgress({
    required String hotelId,
    required String orderId,
    required String byUserId,
    required String byUserName,
  }) async {
    final batch = _db.batch();

    batch.update(_orders(hotelId).doc(orderId), {
      'status': 'in_progress',
    });

    final histRef = _history(hotelId, orderId).doc();
    batch.set(histRef, {
      'action': 'in_progress',
      'byUserId': byUserId,
      'byUserName': byUserName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Mark an order as completed.
  static Future<void> markCompleted({
    required String hotelId,
    required String orderId,
    required String byUserId,
    required String byUserName,
  }) async {
    final batch = _db.batch();

    batch.update(_orders(hotelId).doc(orderId), {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'completedById': byUserId,
      'completedByName': byUserName,
    });

    final histRef = _history(hotelId, orderId).doc();
    batch.set(histRef, {
      'action': 'completed',
      'byUserId': byUserId,
      'byUserName': byUserName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Forward an order to another department.
  static Future<void> forwardOrder({
    required String hotelId,
    required String orderId,
    required String fromDeptId,
    required String fromDeptName,
    required String toDeptId,
    required String toDeptName,
    required String byUserId,
    required String byUserName,
  }) async {
    final batch = _db.batch();

    batch.update(_orders(hotelId).doc(orderId), {
      'currentDeptId': toDeptId,
      'currentDeptName': toDeptName,
      'status': 'unseen',
      'seenAt': null,
    });

    final histRef = _history(hotelId, orderId).doc();
    batch.set(histRef, {
      'action': 'forwarded',
      'fromDeptId': fromDeptId,
      'fromDeptName': fromDeptName,
      'toDeptId': toDeptId,
      'toDeptName': toDeptName,
      'byUserId': byUserId,
      'byUserName': byUserName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Notification for new destination
    final notifRef = _notifs(hotelId).doc();
    batch.set(notifRef, {
      'hotelId': hotelId,
      'deptId': toDeptId,
      'orderId': orderId,
      'title': 'Ordre transféré',
      'message':
          '$byUserName ($fromDeptName) vous a transféré un ordre.',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Real-time stream of notifications for a department.
  static Stream<List<OrderNotification>> streamNotificationsForDept(
      {required String hotelId, required String deptId}) {
    return _notifs(hotelId)
        .where('deptId', isEqualTo: deptId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => OrderNotification.fromDoc(d)).toList());
  }

  /// Mark a notification as read.
  static Future<void> markNotificationRead(
      {required String hotelId, required String notifId}) async {
    await _notifs(hotelId).doc(notifId).update({'read': true});
  }

  /// Mark all notifications for a department as read.
  static Future<void> markAllNotificationsRead(
      {required String hotelId, required String deptId}) async {
    final snap = await _notifs(hotelId)
        .where('deptId', isEqualTo: deptId)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  USER DEPARTMENT ASSIGNMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all users for a hotel who have a departmentId.
  static Future<List<Map<String, dynamic>>> fetchOrgUsers(
      String hotelId) async {
    final snap = await _db
        .collection('users')
        .where('hotelId', isEqualTo: hotelId)
        .get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList();
  }

  /// Assign a user to a department.
  static Future<void> assignUserToDepartment({
    required String userId,
    required String deptId,
    required String deptName,
    required String orgRole, // 'director', 'manager', 'staff'
  }) async {
    await _db.collection('users').doc(userId).update({
      'orgDeptId': deptId,
      'orgDeptName': deptName,
      'orgRole': orgRole,
    });
  }

  /// Remove a user from their department assignment.
  static Future<void> removeUserFromDepartment(String userId) async {
    await _db.collection('users').doc(userId).update({
      'orgDeptId': FieldValue.delete(),
      'orgDeptName': FieldValue.delete(),
      'orgRole': FieldValue.delete(),
    });
  }
}
