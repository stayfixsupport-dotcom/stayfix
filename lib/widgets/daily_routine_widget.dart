import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../core/theme_provider.dart';
import '../models/hotel_models.dart';
import '../models/order_models.dart';
import '../models/routine_models.dart';
import '../providers/hotel_provider.dart';
import '../screens/orders/order_detail_screen.dart';
import '../services/order_service.dart';
import '../services/routine_service.dart';

class DailyRoutineWidget extends StatefulWidget {
  const DailyRoutineWidget({super.key});

  @override
  State<DailyRoutineWidget> createState() => _DailyRoutineWidgetState();
}

class _DailyRoutineWidgetState extends State<DailyRoutineWidget> {
  final RoutineService _routineService = RoutineService();

  bool _shouldRunToday(RoutineTask task, DateTime date) {
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
    return '';
  }

  static String _deptNameForId(String id) {
    switch (id) {
      case 'dept_maintenance':
        return 'Maintenance';
      case 'dept_housekeeping':
        return 'Gouvernante';
      case 'dept_reception':
        return 'Réception';
      default:
        return id;
    }
  }

  /// Shows order-style detail sheet for a pending task (not yet completed today).
  void _showPendingDetail(
    BuildContext context,
    RoutineTask task,
    String todayString,
    HotelUser user,
    String deptId,
    String hotelId,
    bool isDark,
    ThemeData theme,
  ) {
    final textPrimary = theme.colorScheme.onSurface;
    final textMuted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final border = isDark ? SfColors.darkBorder : SfColors.lightBorder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SfColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.assignment_outlined,
                          color: SfColors.gold, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Journée Quotidienne',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: SfColors.gold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Status card (pending)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SfColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: SfColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: SfColors.warning.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.clock,
                                color: SfColors.warning, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'En attente',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: SfColors.warning,
                                ),
                              ),
                              Text(
                                "Prévu pour aujourd'hui",
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          _infoRow(LucideIcons.tag, 'Catégorie',
                              'Journée Quotidienne', SfColors.gold, textMuted, textPrimary),
                          Divider(height: 16, thickness: 0.5, color: border),
                          _infoRow(Icons.assignment_outlined, 'Tâche',
                              task.name, SfColors.info, textMuted, textPrimary),
                          Divider(height: 16, thickness: 0.5, color: border),
                          _infoRow(LucideIcons.building2, 'Département',
                              _deptNameForId(task.departmentId), SfColors.warning,
                              textMuted, textPrimary),
                          Divider(height: 16, thickness: 0.5, color: border),
                          _infoRow(Icons.repeat, 'Récurrence',
                              _recurrenceLabel(task), SfColors.info, textMuted,
                              textPrimary),
                          Divider(height: 16, thickness: 0.5, color: border),
                          _infoRow(LucideIcons.calendar, 'Date',
                              DateFormat('d MMMM yyyy', 'fr_FR').format(DateTime.now()),
                              SfColors.info, textMuted, textPrimary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description card
                    if (task.description.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Instructions',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted)),
                            const SizedBox(height: 8),
                            Text(task.description,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: textPrimary,
                                    height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Complete button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await OrderService.launchRoutineTask(
                            hotelId: hotelId,
                            templateId: task.id,
                            taskName: task.name,
                            deptId: deptId.isEmpty ? task.departmentId : deptId,
                            deptName: _deptNameForId(
                                deptId.isEmpty ? task.departmentId : deptId),
                            categoryId: task.categoryId,
                            categoryName: task.categoryName,
                            locationType: task.locationType,
                            roomNumber: task.roomNumber,
                            locationDetail: task.locationDetail,
                            byUserId: user.id,
                            byUserName: user.fullName,
                            dateString: todayString,
                          );
                        },
                        icon: const Icon(LucideIcons.play,
                            size: 18, color: Colors.white),
                        label: Text(
                          "Lancer l'ordre",
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SfColors.gold,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color iconColor,
      Color labelColor, Color valueColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(fontSize: 11, color: labelColor)),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor)),
            ],
          ),
        ),
      ],
    );
  }

  String _recurrenceLabel(RoutineTask task) {
    switch (task.recurrenceType) {
      case RoutineRecurrenceType.daily:
        return 'Chaque jour';
      case RoutineRecurrenceType.weekly:
        return 'Chaque semaine';
      case RoutineRecurrenceType.everyXDays:
        return 'Tous les ${task.recurrenceInterval} jours';
      case RoutineRecurrenceType.monthly:
        return 'Chaque mois (le ${task.recurrenceDay})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final provider = Provider.of<HotelProvider>(context);
    final user = provider.currentUser;
    final hotelId = provider.selectedHotel?.id;

    if (user == null || hotelId == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final todayString = DateFormat('yyyy-MM-dd').format(now);
    final displayDate = DateFormat('d MMMM', 'fr_FR').format(now).toUpperCase();
    final userDeptId = _deptIdForRole(user.role);

    return StreamBuilder<List<RoutineTask>>(
      stream: _routineService.streamTasks(hotelId),
      builder: (context, taskSnapshot) {
        if (!taskSnapshot.hasData) return const SizedBox.shrink();

        final allTasks = taskSnapshot.data!;
        final deptTasks = userDeptId.isEmpty
            ? allTasks
            : allTasks.where((t) => t.departmentId == userDeptId).toList();
        final todaysTasks =
            deptTasks.where((t) => _shouldRunToday(t, now)).toList();

        if (todaysTasks.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<List<OrgOrder>>(
          stream: OrderService.streamRoutineOrdersForDate(
            hotelId: hotelId,
            dateString: todayString,
            deptId: userDeptId.isEmpty ? null : userDeptId,
          ),
          builder: (context, orderSnapshot) {
            final completedMap = <String, OrgOrder>{};
            for (final order in (orderSnapshot.data ?? [])) {
              if (order.routineTemplateId != null) {
                completedMap[order.routineTemplateId!] = order;
              }
            }

            final launchedCount = todaysTasks
                .where((t) => completedMap.containsKey(t.id))
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "JOURNÉE QUOTIDIENNE — $displayDate",
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "$launchedCount / ${todaysTasks.length} lancées",
                      style: GoogleFonts.inter(
                        color: launchedCount == todaysTasks.length
                            ? SfColors.success
                            : SfColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: todaysTasks.length,
                    itemBuilder: (context, index) {
                      final task = todaysTasks[index];
                      final isCompleted = completedMap.containsKey(task.id);
                      final completedOrder = completedMap[task.id];
                      return _buildTaskTile(
                        context,
                        task: task,
                        isCompleted: isCompleted,
                        completedOrder: completedOrder,
                        todayString: todayString,
                        user: user,
                        deptId: userDeptId,
                        hotelId: hotelId,
                        isDark: isDark,
                        theme: theme,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTaskTile(
    BuildContext context, {
    required RoutineTask task,
    required bool isCompleted,
    required OrgOrder? completedOrder,
    required String todayString,
    required HotelUser user,
    required String deptId,
    required String hotelId,
    required bool isDark,
    required ThemeData theme,
  }) {
    final isActuallyCompleted =
        completedOrder?.status == OrderStatus.completed;

    return GestureDetector(
      onTap: () {
        if (isCompleted && completedOrder != null) {
          // Tap → open the real OrderDetailScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(order: completedOrder),
            ),
          );
        } else {
          // Tap → show pending task detail sheet (order-style)
          _showPendingDetail(
            context,
            task,
            todayString,
            user,
            deptId,
            hotelId,
            isDark,
            theme,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isActuallyCompleted
              ? (isDark ? const Color(0xFF141A14) : const Color(0xFFF0FDF4))
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActuallyCompleted
                ? SfColors.success.withValues(alpha: 0.3)
                : (isDark ? SfColors.darkBorder : SfColors.lightBorder),
          ),
        ),
        child: ListTile(
          leading: Icon(
            isActuallyCompleted ? LucideIcons.checkCircle : LucideIcons.circle,
            color: isActuallyCompleted
                ? SfColors.success
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          title: Text(
            task.name,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface,
              fontWeight: isActuallyCompleted ? FontWeight.normal : FontWeight.bold,
              decoration: isActuallyCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: isCompleted && completedOrder != null
              ? Text(
                  "${completedOrder.status.label} — ${DateFormat('HH:mm').format(completedOrder.createdAt)}",
                  style: GoogleFonts.inter(
                    color: completedOrder.status.color,
                    fontSize: 12,
                  ),
                )
              : (task.description.isNotEmpty
                  ? Text(
                      task.description,
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null),
          trailing: isCompleted
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      completedOrder!.status.label,
                      style: GoogleFonts.inter(
                        color: completedOrder.status.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.chevronRight,
                        size: 14,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3)),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Créer",
                      style: GoogleFonts.inter(
                        color: SfColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.chevronRight,
                        size: 14, color: SfColors.gold),
                  ],
                ),
        ),
      ),
    );
  }
}
