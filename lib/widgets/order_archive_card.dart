import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/order_models.dart';
import '../screens/orders/order_detail_screen.dart';

/// Style variants for the archive card ribbon and status.
enum ArchiveCardUrgency {
  critical,
  warning,
  normal,
}

/// Custom ribbon bookmark painter on the left edge of the archive card.
class BookmarkRibbonPainter extends CustomPainter {
  final Color color;

  BookmarkRibbonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - 6);
    // V-shaped bookmark notch at the bottom
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height - 6);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BookmarkRibbonPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Rich archive order card matching the Stayfix design mockup.
class OrderArchiveCard extends StatelessWidget {
  const OrderArchiveCard({
    super.key,
    required this.order,
    this.onTap,
  });

  final OrgOrder order;
  final VoidCallback? onTap;

  /// Determine urgency from order details or SLA.
  ArchiveCardUrgency get _urgency {
    final desc = order.description.toLowerCase();
    final cat = (order.categoryName ?? '').toLowerCase();
    if (desc.contains('urgent') ||
        desc.contains('critique') ||
        cat.contains('urgent') ||
        cat.contains('critique')) {
      return ArchiveCardUrgency.critical;
    }

    // Check SLA delay if available
    final completed = order.completedAt ?? order.createdAt;
    final duration = completed.difference(order.createdAt).inHours;
    if (duration >= 3) {
      return ArchiveCardUrgency.critical;
    } else if (duration >= 1) {
      return ArchiveCardUrgency.warning;
    }

    return ArchiveCardUrgency.normal;
  }

  Color get _ribbonColor {
    switch (_urgency) {
      case ArchiveCardUrgency.critical:
        return const Color(0xFFEF4444); // Red
      case ArchiveCardUrgency.warning:
        return const Color(0xFFF59E0B); // Yellow/Amber
      case ArchiveCardUrgency.normal:
        return const Color(0xFF22C55E); // Green
    }
  }

  String get _timeAgo {
    final now = DateTime.now();
    final dt = order.completedAt ?? order.createdAt;
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  String get _orderCode {
    final short = order.id.length >= 6
        ? order.id.substring(0, 6).toUpperCase()
        : order.id.toUpperCase();
    return '#$short';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141416) : Colors.white;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    final urgency = _urgency;
    final ribbonColor = _ribbonColor;

    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(order: order),
              ),
            );
          },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Left Bookmark Ribbon
            Positioned(
              left: 14,
              top: 0,
              child: CustomPaint(
                size: const Size(14, 26),
                painter: BookmarkRibbonPainter(color: ribbonColor),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Status dot / icon + Order #ID and relative time
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ribbonColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ordre $_orderCode',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Status with heart icon + description/SLA
                  Row(
                    children: [
                      Icon(
                        LucideIcons.heart,
                        size: 13,
                        color: urgency == ArchiveCardUrgency.critical
                            ? const Color(0xFFEF4444)
                            : urgency == ArchiveCardUrgency.warning
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        urgency == ArchiveCardUrgency.critical
                            ? 'Terminé - Critique'
                            : 'Terminé',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: urgency == ArchiveCardUrgency.critical
                              ? const Color(0xFFEF4444)
                              : urgency == ArchiveCardUrgency.warning
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  // SLA / Context Subtitle
                  Text(
                    urgency == ArchiveCardUrgency.critical
                        ? 'SLA (3h) dépassé'
                        : urgency == ArchiveCardUrgency.warning
                            ? 'Retard SLA (2h)'
                            : '${order.categoryName ?? 'Sans catégorie'} - ${order.locationDisplay}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: urgency == ArchiveCardUrgency.critical
                          ? const Color(0xFFF87171)
                          : urgency == ArchiveCardUrgency.warning
                              ? const Color(0xFFFBBF24)
                              : textMuted,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Row 3: Footer badges (Intervenant, Creator role, Department)
                  Row(
                    children: [
                      // Assignee / Intervenant
                      Text(
                        order.completedByName?.isNotEmpty == true
                            ? order.completedByName!
                            : 'À test',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Creator info with User icon
                      Icon(
                        LucideIcons.user,
                        size: 12,
                        color: textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.creatorName.isNotEmpty
                            ? order.creatorName
                            : 'Directeur Général',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),

                      const Spacer(),

                      // Department badge with gold-tinted outline
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6A85A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFD6A85A).withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          order.currentDeptName.isNotEmpty
                              ? order.currentDeptName
                              : 'Maintenance',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD6A85A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
