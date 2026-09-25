import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_models.dart';
import '../core/theme.dart';

/// Vertical timeline showing all history entries for an order.
class OrderHistoryTimeline extends StatelessWidget {
  const OrderHistoryTimeline({
    super.key,
    required this.history,
  });

  final List<OrderHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Aucun historique disponible.'),
      );
    }

    return Column(
      children: List.generate(history.length, (index) {
        final entry = history[index];
        final isLast = index == history.length - 1;
        return _TimelineItem(
          entry: entry,
          isLast: isLast,
          isFirst: index == 0,
        );
      }),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.isLast,
    required this.isFirst,
  });

  final OrderHistoryEntry entry;
  final bool isLast;
  final bool isFirst;

  Color get _dotColor {
    switch (entry.action) {
      case 'created':
        return SfColors.info;
      case 'seen':
        return SfColors.warning;
      case 'in_progress':
        return const Color(0xFFF97316);
      case 'completed':
        return SfColors.success;
      case 'forwarded':
        return SfColors.gold;
      default:
        return SfColors.darkTextMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor =
        isDark ? SfColors.darkBorder : SfColors.lightBorder;
    final textPrimary = isDark
        ? SfColors.darkTextPrimary
        : SfColors.lightTextPrimary;
    final textMuted = isDark
        ? SfColors.darkTextMuted
        : SfColors.lightTextMuted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 36,
            child: Column(
              children: [
                // Top connector
                if (!isFirst)
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: lineColor,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 8),

                // Dot
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _dotColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _dotColor, width: 2),
                  ),
                  child: Icon(
                    entry.actionIcon,
                    size: 14,
                    color: _dotColor,
                  ),
                ),

                // Bottom connector
                if (!isLast)
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: lineColor,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.actionLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(entry.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Par ${entry.byUserName}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: textMuted,
                    ),
                  ),
                  if (entry.action == 'forwarded' &&
                      entry.fromDeptName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _deptBadge(entry.fromDeptName ?? '', isDark),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward,
                              size: 12, color: SfColors.gold),
                        ),
                        _deptBadge(entry.toDeptName ?? '', isDark),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deptBadge(String name, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: SfColors.goldMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: SfColors.gold,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
