import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_models.dart';

enum RoutineRecurrenceType {
  daily,
  weekly,
  everyXDays,
  monthly;

  static RoutineRecurrenceType fromString(String? value) {
    switch (value) {
      case 'weekly':
        return RoutineRecurrenceType.weekly;
      case 'everyXDays':
        return RoutineRecurrenceType.everyXDays;
      case 'monthly':
        return RoutineRecurrenceType.monthly;
      case 'daily':
      default:
        return RoutineRecurrenceType.daily;
    }
  }

  String toValue() => name;

  String get label {
    switch (this) {
      case RoutineRecurrenceType.daily:
        return 'Chaque jour';
      case RoutineRecurrenceType.weekly:
        return 'Chaque semaine';
      case RoutineRecurrenceType.everyXDays:
        return 'Tous les X jours';
      case RoutineRecurrenceType.monthly:
        return 'Chaque mois';
    }
  }
}

class RoutineTask {
  final String id;
  final String hotelId;
  final String name;
  final String description;
  final String categoryId;
  final String categoryName;
  final String priority;
  final bool isActive;
  final String departmentId; // e.g. 'dept_maintenance', 'dept_housekeeping', 'dept_reception'
  final OrderLocationType locationType;
  final String? roomNumber;
  final String? locationDetail;
  final RoutineRecurrenceType recurrenceType;
  final int recurrenceInterval;
  final int recurrenceDay;
  final DateTime createdAt;

  const RoutineTask({
    required this.id,
    required this.hotelId,
    required this.name,
    this.description = '',
    this.categoryId = 'routine',
    this.categoryName = 'Journée Quotidienne',
    this.priority = 'Normale',
    this.isActive = true,
    this.departmentId = 'dept_maintenance',
    this.locationType = OrderLocationType.other,
    this.roomNumber,
    this.locationDetail,
    this.recurrenceType = RoutineRecurrenceType.daily,
    this.recurrenceInterval = 1,
    this.recurrenceDay = 1,
    required this.createdAt,
  });

  factory RoutineTask.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoutineTask(
      id: doc.id,
      hotelId: (data['hotelId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      categoryId: (data['categoryId'] as String?) ?? 'routine',
      categoryName: (data['categoryName'] as String?) ?? 'Journée Quotidienne',
      priority: (data['priority'] as String?) ?? 'Normale',
      isActive: (data['isActive'] as bool?) ?? true,
      departmentId: (data['departmentId'] as String?) ?? 'dept_maintenance',
      locationType: OrderLocationType.fromString(data['locationType'] as String?),
      roomNumber: data['roomNumber'] as String?,
      locationDetail: data['locationDetail'] as String?,
      recurrenceType: RoutineRecurrenceType.fromString(data['recurrenceType'] as String?),
      recurrenceInterval: (data['recurrenceInterval'] as int?) ?? 1,
      recurrenceDay: (data['recurrenceDay'] as int?) ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'hotelId': hotelId,
        'name': name,
        'description': description,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'priority': priority,
        'isActive': isActive,
        'departmentId': departmentId,
        'locationType': locationType.toValue(),
        if (roomNumber != null && roomNumber!.isNotEmpty) 'roomNumber': roomNumber,
        if (locationDetail != null && locationDetail!.isNotEmpty) 'locationDetail': locationDetail,
        'recurrenceType': recurrenceType.toValue(),
        'recurrenceInterval': recurrenceInterval,
        'recurrenceDay': recurrenceDay,
        'createdAt': FieldValue.serverTimestamp(),
      };

  RoutineTask copyWith({
    String? name,
    String? description,
    String? categoryId,
    String? categoryName,
    String? priority,
    bool? isActive,
    String? departmentId,
    OrderLocationType? locationType,
    String? roomNumber,
    String? locationDetail,
    RoutineRecurrenceType? recurrenceType,
    int? recurrenceInterval,
    int? recurrenceDay,
  }) {
    return RoutineTask(
      id: id,
      hotelId: hotelId,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      departmentId: departmentId ?? this.departmentId,
      locationType: locationType ?? this.locationType,
      roomNumber: roomNumber ?? this.roomNumber,
      locationDetail: locationDetail ?? this.locationDetail,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceDay: recurrenceDay ?? this.recurrenceDay,
      createdAt: createdAt,
    );
  }
}

class RoutineTaskLog {
  final String id;
  final String taskId;
  final String hotelId;
  final String dateString; // e.g. 'YYYY-MM-DD' for easy querying
  final String completedBy;
  final String completedByName;
  final DateTime completedAt;

  const RoutineTaskLog({
    required this.id,
    required this.taskId,
    required this.hotelId,
    required this.dateString,
    required this.completedBy,
    required this.completedByName,
    required this.completedAt,
  });

  factory RoutineTaskLog.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoutineTaskLog(
      id: doc.id,
      taskId: (data['taskId'] as String?) ?? '',
      hotelId: (data['hotelId'] as String?) ?? '',
      dateString: (data['dateString'] as String?) ?? '',
      completedBy: (data['completedBy'] as String?) ?? '',
      completedByName: (data['completedByName'] as String?) ?? '',
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'hotelId': hotelId,
        'dateString': dateString,
        'completedBy': completedBy,
        'completedByName': completedByName,
        'completedAt': FieldValue.serverTimestamp(),
      };
}
