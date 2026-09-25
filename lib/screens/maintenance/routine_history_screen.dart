import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../models/hotel_models.dart';
import '../../models/order_models.dart';
import '../../models/routine_models.dart';
import '../../providers/hotel_provider.dart';
import '../../services/order_service.dart';
import '../../services/routine_service.dart';

class RoutineHistoryScreen extends StatefulWidget {
  const RoutineHistoryScreen({super.key});

  @override
  State<RoutineHistoryScreen> createState() => _RoutineHistoryScreenState();
}

class _RoutineHistoryScreenState extends State<RoutineHistoryScreen> {
  final RoutineService _routineService = RoutineService();
  DateTime _selectedDate = DateTime.now();

  bool _shouldRunOnDate(RoutineTask task, DateTime date) {
    if (!task.isActive) return false;
    switch (task.recurrenceType) {
      case RoutineRecurrenceType.daily:
        return true;
      case RoutineRecurrenceType.weekly:
        return date.weekday == task.recurrenceDay;
      case RoutineRecurrenceType.monthly:
        return date.day == task.recurrenceDay;
      case RoutineRecurrenceType.everyXDays:
        final diff = date.difference(task.createdAt).inDays;
        if (diff < 0) return false;
        return (diff % task.recurrenceInterval) == 0;
    }
  }

  static String _deptIdForRole(String role) {
    if (role == UserRoles.maintenanceManager || role == UserRoles.supervisor) {
      return 'dept_maintenance';
    }
    if (role == UserRoles.housekeepingManager ||
        role == UserRoles.housekeeping ||
        role == UserRoles.houseman) {
      return 'dept_housekeeping';
    }
    if (role == UserRoles.receptionManager || role == UserRoles.staff) {
      return 'dept_reception';
    }
    return ''; // Director → all
  }

  Future<void> _pickDate() async {
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: SfColors.gold,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final provider = Provider.of<HotelProvider>(context);
    final user = provider.currentUser;
    final hotelId = provider.selectedHotel?.id;
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final displayDate = DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDate);

    if (hotelId == null || user == null) return const Scaffold();

    final userDeptId = _deptIdForRole(user.role);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "HISTORIQUE ROUTINES",
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          // Date Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: isDark ? SfColors.darkBorder : SfColors.lightBorder),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Date sélectionnée",
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayDate.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(LucideIcons.calendar, size: 16, color: Colors.white),
                  label: Text(
                    "Changer",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? SfColors.gold : SfColors.goldDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: StreamBuilder<List<RoutineTask>>(
              stream: _routineService.streamTasks(hotelId),
              builder: (context, taskSnapshot) {
                if (taskSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: SfColors.gold));
                }

                final allTasks = taskSnapshot.data ?? [];
                // Filter by department for non-directors
                final deptTasks = userDeptId.isEmpty
                    ? allTasks
                    : allTasks
                        .where((t) => t.departmentId == userDeptId)
                        .toList();
                final scheduledTasks =
                    deptTasks.where((t) => _shouldRunOnDate(t, _selectedDate)).toList();

                if (scheduledTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.coffee_outlined,
                            size: 48,
                            color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          "Aucune tâche prévue ce jour-là.",
                          style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  );
                }

                // Stream the completed routine orders from org_orders
                return StreamBuilder<List<OrgOrder>>(
                  stream: OrderService.streamRoutineOrdersForDate(
                    hotelId: hotelId,
                    dateString: dateString,
                    deptId: userDeptId.isEmpty ? null : userDeptId,
                  ),
                  builder: (context, orderSnapshot) {
                    // Map templateId → OrgOrder
                    final completedMap = <String, OrgOrder>{};
                    for (final order in (orderSnapshot.data ?? [])) {
                      if (order.routineTemplateId != null) {
                        completedMap[order.routineTemplateId!] = order;
                      }
                    }

                    final launchedCount = completedMap.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            "$launchedCount / ${scheduledTasks.length} TÂCHES LANCÉES",
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: scheduledTasks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final task = scheduledTasks[i];
                              final order = completedMap[task.id];
                              final isCompleted = order != null;

                              return Container(
                                decoration: BoxDecoration(
                                  color: theme.cardTheme.color,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? SfColors.darkBorder
                                        : SfColors.lightBorder,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 8),
                                  leading: Icon(
                                    isCompleted
                                        ? LucideIcons.checkCircle
                                        : LucideIcons.circle,
                                    color: isCompleted
                                        ? SfColors.success
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.3),
                                  ),
                                  title: Text(
                                    task.name,
                                    style: GoogleFonts.inter(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: isCompleted
                                        ? Text(
                                            "${order.status.label} — ${DateFormat('HH:mm').format(order.createdAt)}",
                                            style: GoogleFonts.inter(
                                              color: order.status.color,
                                              fontSize: 13,
                                            ),
                                          )
                                        : Text(
                                            "Non lancée",
                                            style: GoogleFonts.inter(
                                              color: SfColors.warning,
                                              fontSize: 13,
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
