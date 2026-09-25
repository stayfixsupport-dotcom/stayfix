import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/order_models.dart';
import '../core/theme.dart';
import 'order_status_chip.dart';

/// A rich order summary card used in the dashboard and archive lists.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.showDepartment = false,
    this.onTakeOrder,
    this.onComplete,
    this.onForward,
  });

  final OrgOrder order;
  final VoidCallback? onTap;

  /// When true, shows the current destination department (useful for director view).
  final bool showDepartment;

  /// Quick action callbacks — when provided, a shortcut bar is shown on the card.
  final VoidCallback? onTakeOrder;
  final VoidCallback? onComplete;
  final VoidCallback? onForward;


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = order.status.color;
    final cardBg =
        isDark ? SfColors.darkBgCard : SfColors.lightBgCard;
    final borderColor = order.status == OrderStatus.unseen
        ? statusColor.withOpacity(0.6)
        : isDark
            ? SfColors.darkBorder
            : SfColors.lightBorder;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            if (order.status == OrderStatus.unseen)
              BoxShadow(
                color: statusColor.withOpacity(0.12),
                blurRadius: 16,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header bar ─────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.07),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  // Status dot
                  OrderStatusChip(status: order.status),
                  const SizedBox(width: 10),
                  // Order ID
                  Text(
                    '#${order.id.substring(0, 6).toUpperCase()}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? SfColors.darkTextMuted
                          : SfColors.lightTextMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  // Date
                  Text(
                    _formatDate(order.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? SfColors.darkTextMuted
                          : SfColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + Location row
                  Row(
                    children: [
                      _iconLabel(
                        context,
                        icon: LucideIcons.tag,
                        label: order.categoryName?.isNotEmpty == true
                            ? order.categoryName!
                            : 'Sans catégorie',
                        primary: true,
                      ),
                      const SizedBox(width: 12),
                      _iconLabel(
                        context,
                        icon: order.locationType == OrderLocationType.room
                            ? LucideIcons.bedDouble
                            : LucideIcons.mapPin,
                        label: order.locationDisplay,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Text(
                    order.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark
                          ? SfColors.darkTextPrimary
                          : SfColors.lightTextPrimary,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 10),

                  // Sender + Department info
                  Row(
                    children: [
                      _iconLabel(
                        context,
                        icon: LucideIcons.user,
                        label: order.creatorName,
                      ),
                      const SizedBox(width: 12),
                      _iconLabel(
                        context,
                        icon: LucideIcons.building2,
                        label: order.creatorDeptName,
                      ),
                      if (showDepartment) ...[
                        const Spacer(),
                        _deptTag(context, order.currentDeptName),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // ── Quick Actions Bar ────────────────────────────────────────────
            if (onTakeOrder != null || onComplete != null || onForward != null)
              _QuickActionsBar(
                order: order,
                onTakeOrder: onTakeOrder,
                onComplete: onComplete,
                onForward: onForward,
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconLabel(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool primary = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = primary
        ? SfColors.gold
        : isDark
            ? SfColors.darkTextSecondary
            : SfColors.lightTextSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: textColor),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: textColor,
              fontWeight: primary ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _deptTag(BuildContext context, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SfColors.goldMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SfColors.darkBorder, width: 1),
      ),
      child: Text(
        name,
        style: GoogleFonts.inter(
          fontSize: 10,
          color: SfColors.gold,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Quick Actions Bar ──────────────────────────────────────────────────────────

class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar({
    required this.order,
    this.onTakeOrder,
    this.onComplete,
    this.onForward,
  });

  final OrgOrder order;
  final VoidCallback? onTakeOrder;
  final VoidCallback? onComplete;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = order.status == OrderStatus.completed;
    if (isCompleted) return const SizedBox.shrink();

    final showTake = onTakeOrder != null && order.status == OrderStatus.unseen;
    final showComplete = onComplete != null &&
        (order.status == OrderStatus.inProgress ||
            order.status == OrderStatus.unseen);
    final showForward = onForward != null;

    if (!showTake && !showComplete && !showForward) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          if (showTake) ...[
            _QuickBtn(
              icon: LucideIcons.play,
              label: 'Prendre',
              color: SfColors.info,
              onTap: onTakeOrder!,
            ),
            const SizedBox(width: 8),
          ],
          if (showComplete) ...[
            _QuickBtn(
              icon: LucideIcons.checkCircle,
              label: 'Terminé',
              color: SfColors.success,
              onTap: onComplete!,
            ),
            const SizedBox(width: 8),
          ],
          if (showForward)
            _QuickBtn(
              icon: LucideIcons.arrowRight,
              label: 'Transférer',
              color: SfColors.gold,
              onTap: onForward!,
            ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
