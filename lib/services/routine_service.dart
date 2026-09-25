import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/routine_models.dart';

/// Manages routine task TEMPLATES only.
/// Completion tracking is now handled via OrderService (org_orders collection)
/// with isRoutine=true flag — so routine completions appear in the main orders dashboard.
class RoutineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _tasksRef(String hotelId) =>
      _firestore.collection('hotels').doc(hotelId).collection('routine_tasks');

  /// Real-time stream of all routine task templates for a hotel.
  Stream<List<RoutineTask>> streamTasks(String hotelId) {
    return _tasksRef(hotelId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RoutineTask.fromDoc(doc)).toList();
    });
  }

  /// Create a new routine task template.
  Future<void> createTask(RoutineTask task) async {
    await _tasksRef(task.hotelId).add(task.toMap());
  }

  /// Update an existing routine task template.
  Future<void> updateTask(RoutineTask task) async {
    await _tasksRef(task.hotelId).doc(task.id).update(task.toMap());
  }

  /// Delete a routine task template.
  Future<void> deleteTask(String hotelId, String taskId) async {
    await _tasksRef(hotelId).doc(taskId).delete();
  }
}
