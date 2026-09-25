import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─── Status Enum ──────────────────────────────────────────────────────────────

enum OrderStatus {
  unseen,
  inProgress,
  completed;

  static OrderStatus fromString(String? value) {
    switch (value) {
      case 'in_progress':
        return OrderStatus.inProgress;
      case 'completed':
        return OrderStatus.completed;
      default:
        return OrderStatus.unseen;
    }
  }

  String toFirestoreValue() {
    switch (this) {
      case OrderStatus.unseen:
        return 'unseen';
      case OrderStatus.inProgress:
        return 'in_progress';
      case OrderStatus.completed:
        return 'completed';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.unseen:
        return 'Non vu';
      case OrderStatus.inProgress:
        return 'En cours';
      case OrderStatus.completed:
        return 'Terminé';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.unseen:
        return const Color(0xFFEF4444); // Red
      case OrderStatus.inProgress:
        return const Color(0xFFF97316); // Orange
      case OrderStatus.completed:
        return const Color(0xFF22C55E); // Green
    }
  }

  String get emoji {
    switch (this) {
      case OrderStatus.unseen:
        return '🔴';
      case OrderStatus.inProgress:
        return '🟠';
      case OrderStatus.completed:
        return '🟢';
    }
  }
}

// ─── Location Type ─────────────────────────────────────────────────────────

enum OrderLocationType {
  room,
  other;

  static OrderLocationType fromString(String? value) {
    return value == 'room' ? OrderLocationType.room : OrderLocationType.other;
  }

  String toValue() => name;
  String get label => this == OrderLocationType.room ? 'Chambre' : 'Autre';
}

// ─── OrgDepartment ────────────────────────────────────────────────────────────

class OrgDepartment {
  final String id;
  final String name;
  final bool isActive;
  final String hotelId;
  final DateTime createdAt;

  const OrgDepartment({
    required this.id,
    required this.name,
    required this.isActive,
    required this.hotelId,
    required this.createdAt,
  });

  factory OrgDepartment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrgDepartment(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      isActive: (data['isActive'] as bool?) ?? true,
      hotelId: (data['hotelId'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'isActive': isActive,
        'hotelId': hotelId,
        'createdAt': FieldValue.serverTimestamp(),
      };

  OrgDepartment copyWith({String? name, bool? isActive}) => OrgDepartment(
        id: id,
        name: name ?? this.name,
        isActive: isActive ?? this.isActive,
        hotelId: hotelId,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrgDepartment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ─── OrgCategory ──────────────────────────────────────────────────────────────

class OrgCategory {
  final String id;
  final String name;
  final bool isActive;
  final String hotelId;
  final DateTime createdAt;

  const OrgCategory({
    required this.id,
    required this.name,
    required this.isActive,
    required this.hotelId,
    required this.createdAt,
  });

  factory OrgCategory.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrgCategory(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      isActive: (data['isActive'] as bool?) ?? true,
      hotelId: (data['hotelId'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'isActive': isActive,
        'hotelId': hotelId,
        'createdAt': FieldValue.serverTimestamp(),
      };

  OrgCategory copyWith({String? name, bool? isActive}) => OrgCategory(
        id: id,
        name: name ?? this.name,
        isActive: isActive ?? this.isActive,
        hotelId: hotelId,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrgCategory && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ─── OrderHistoryEntry ────────────────────────────────────────────────────────

class OrderHistoryEntry {
  final String id;
  final String action; // created, seen, in_progress, completed, forwarded
  final String? fromDeptId;
  final String? fromDeptName;
  final String? toDeptId;
  final String? toDeptName;
  final String byUserId;
  final String byUserName;
  final DateTime timestamp;

  const OrderHistoryEntry({
    required this.id,
    required this.action,
    this.fromDeptId,
    this.fromDeptName,
    this.toDeptId,
    this.toDeptName,
    required this.byUserId,
    required this.byUserName,
    required this.timestamp,
  });

  factory OrderHistoryEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderHistoryEntry(
      id: doc.id,
      action: (data['action'] as String?) ?? '',
      fromDeptId: data['fromDeptId'] as String?,
      fromDeptName: data['fromDeptName'] as String?,
      toDeptId: data['toDeptId'] as String?,
      toDeptName: data['toDeptName'] as String?,
      byUserId: (data['byUserId'] as String?) ?? '',
      byUserName: (data['byUserName'] as String?) ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'action': action,
        if (fromDeptId != null) 'fromDeptId': fromDeptId,
        if (fromDeptName != null) 'fromDeptName': fromDeptName,
        if (toDeptId != null) 'toDeptId': toDeptId,
        if (toDeptName != null) 'toDeptName': toDeptName,
        'byUserId': byUserId,
        'byUserName': byUserName,
        'timestamp': FieldValue.serverTimestamp(),
      };

  String get actionLabel {
    switch (action) {
      case 'created':
        return 'Ordre créé';
      case 'seen':
        return 'Ordre vu';
      case 'in_progress':
        return 'Prise en charge';
      case 'completed':
        return 'Ordre terminé';
      case 'forwarded':
        return 'Transféré vers ${toDeptName ?? toDeptId ?? '?'}';
      case 'category_assigned':
        return 'Catégorie assignée';
      default:
        return action;
    }
  }

  IconData get actionIcon {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline;
      case 'seen':
        return Icons.visibility_outlined;
      case 'in_progress':
        return Icons.construction_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'forwarded':
        return Icons.forward_outlined;
      case 'category_assigned':
        return Icons.label_outline;
      default:
        return Icons.info_outline;
    }
  }
}

// ─── OrgOrder ─────────────────────────────────────────────────────────────────

class OrgOrder {
  final String id;
  final String hotelId;

  // Creator info
  final String creatorId;
  final String creatorName;
  final String creatorDeptId;
  final String creatorDeptName;

  // Content
  final String? categoryId;   // null when created by director without category
  final String? categoryName; // null when created by director without category
  final String description;
  final OrderLocationType locationType;
  final String? roomNumber;
  final String? locationDetail;

  // Routing
  final String currentDeptId;
  final String currentDeptName;
  final String initialDeptId;
  final String initialDeptName;

  // Status & timestamps
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? seenAt;
  final DateTime? completedAt;
  final String? completedById;
  final String? completedByName;

  // Routine-specific (null for regular orders)
  final bool isRoutine;
  final String? routineTemplateId;
  final String? routineDateString; // 'YYYY-MM-DD'

  // Optional sub-collection (loaded separately)
  final List<OrderHistoryEntry> history;

  const OrgOrder({
    required this.id,
    required this.hotelId,
    required this.creatorId,
    required this.creatorName,
    required this.creatorDeptId,
    required this.creatorDeptName,
    this.categoryId,
    this.categoryName,
    required this.description,
    required this.locationType,
    this.roomNumber,
    this.locationDetail,
    required this.currentDeptId,
    required this.currentDeptName,
    required this.initialDeptId,
    required this.initialDeptName,
    required this.status,
    required this.createdAt,
    this.seenAt,
    this.completedAt,
    this.completedById,
    this.completedByName,
    this.isRoutine = false,
    this.routineTemplateId,
    this.routineDateString,
    this.history = const [],
  });

  factory OrgOrder.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrgOrder(
      id: doc.id,
      hotelId: (data['hotelId'] as String?) ?? '',
      creatorId: (data['creatorId'] as String?) ?? '',
      creatorName: (data['creatorName'] as String?) ?? '',
      creatorDeptId: (data['creatorDeptId'] as String?) ?? '',
      creatorDeptName: (data['creatorDeptName'] as String?) ?? '',
      categoryId: data['categoryId'] as String?,
      categoryName: data['categoryName'] as String?,
      description: (data['description'] as String?) ?? '',
      locationType:
          OrderLocationType.fromString(data['locationType'] as String?),
      roomNumber: data['roomNumber'] as String?,
      locationDetail: data['locationDetail'] as String?,
      currentDeptId: (data['currentDeptId'] as String?) ?? '',
      currentDeptName: (data['currentDeptName'] as String?) ?? '',
      initialDeptId: (data['initialDeptId'] as String?) ?? '',
      initialDeptName: (data['initialDeptName'] as String?) ?? '',
      status: OrderStatus.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seenAt: (data['seenAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      completedById: data['completedById'] as String?,
      completedByName: data['completedByName'] as String?,
      isRoutine: (data['isRoutine'] as bool?) ?? false,
      routineTemplateId: data['routineTemplateId'] as String?,
      routineDateString: data['routineDateString'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'hotelId': hotelId,
        'creatorId': creatorId,
        'creatorName': creatorName,
        'creatorDeptId': creatorDeptId,
        'creatorDeptName': creatorDeptName,
        if (categoryId != null && categoryId!.isNotEmpty) 'categoryId': categoryId,
        if (categoryName != null && categoryName!.isNotEmpty) 'categoryName': categoryName,
        'description': description,
        'locationType': locationType.toValue(),
        if (roomNumber != null) 'roomNumber': roomNumber,
        if (locationDetail != null) 'locationDetail': locationDetail,
        'currentDeptId': currentDeptId,
        'currentDeptName': currentDeptName,
        'initialDeptId': initialDeptId,
        'initialDeptName': initialDeptName,
        'status': status.toFirestoreValue(),
        'createdAt': FieldValue.serverTimestamp(),
        if (seenAt != null) 'seenAt': Timestamp.fromDate(seenAt!),
        if (completedAt != null)
          'completedAt': Timestamp.fromDate(completedAt!),
        if (completedById != null) 'completedById': completedById,
        if (completedByName != null) 'completedByName': completedByName,
        if (isRoutine) 'isRoutine': true,
        if (routineTemplateId != null) 'routineTemplateId': routineTemplateId,
        if (routineDateString != null) 'routineDateString': routineDateString,
      };

  String get locationDisplay {
    if (locationType == OrderLocationType.room) {
      return 'Chambre ${roomNumber ?? '?'}';
    }
    return locationDetail ?? 'Autre';
  }

  OrgOrder copyWith({
    OrderStatus? status,
    String? categoryId,
    String? categoryName,
    String? currentDeptId,
    String? currentDeptName,
    DateTime? seenAt,
    DateTime? completedAt,
    String? completedById,
    String? completedByName,
    List<OrderHistoryEntry>? history,
  }) {
    return OrgOrder(
      id: id,
      hotelId: hotelId,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorDeptId: creatorDeptId,
      creatorDeptName: creatorDeptName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description,
      locationType: locationType,
      roomNumber: roomNumber,
      locationDetail: locationDetail,
      currentDeptId: currentDeptId ?? this.currentDeptId,
      currentDeptName: currentDeptName ?? this.currentDeptName,
      initialDeptId: initialDeptId,
      initialDeptName: initialDeptName,
      status: status ?? this.status,
      createdAt: createdAt,
      seenAt: seenAt ?? this.seenAt,
      completedAt: completedAt ?? this.completedAt,
      completedById: completedById ?? this.completedById,
      completedByName: completedByName ?? this.completedByName,
      isRoutine: isRoutine,
      routineTemplateId: routineTemplateId,
      routineDateString: routineDateString,
      history: history ?? this.history,
    );
  }
}

// ─── OrderNotification ────────────────────────────────────────────────────────

class OrderNotification {
  final String id;
  final String hotelId;
  final String userId;
  final String deptId;
  final String orderId;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;

  const OrderNotification({
    required this.id,
    required this.hotelId,
    required this.userId,
    required this.deptId,
    required this.orderId,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory OrderNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderNotification(
      id: doc.id,
      hotelId: (data['hotelId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      deptId: (data['deptId'] as String?) ?? '',
      orderId: (data['orderId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      read: (data['read'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'hotelId': hotelId,
        'userId': userId,
        'deptId': deptId,
        'orderId': orderId,
        'title': title,
        'message': message,
        'read': read,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
