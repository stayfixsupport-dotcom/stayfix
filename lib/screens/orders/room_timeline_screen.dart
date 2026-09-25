import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/order_models.dart';
import '../../providers/order_provider.dart';
import 'order_detail_screen.dart';

/// Screen displaying the chronological timeline of interventions for a specific room.
class RoomTimelineScreen extends StatelessWidget {
  const RoomTimelineScreen({
    super.key,
    required this.roomNumber,
    this.onBack,
  });

  final String roomNumber;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF8F9FA);
    final cardBg = isDark ? const Color(0xFF141416) : Colors.white;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        // Find all archived & active orders for this room
        final allOrders = [
          ...provider.archivedOrders,
          ...provider.activeOrders,
        ];
        final roomOrders = allOrders
            .where((o) =>
                o.locationType == OrderLocationType.room &&
                o.roomNumber == roomNumber)
            .toList();

        // Sort descending by date (newest first)
        roomOrders.sort((a, b) =>
            (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                LucideIcons.arrowLeft,
                color: textPrimary,
                size: 20,
              ),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Timeline de Chambre $roomNumber',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
          body: Column(
            children: [
              // Top Room Summary Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6A85A).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD6A85A).withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.mapPin,
                          color: Color(0xFFD6A85A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chambre $roomNumber',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${roomOrders.length} ordres totaux · ${roomOrders.length} résolus',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Vertical Timeline List
              Expanded(
                child: roomOrders.isEmpty
                    ? _buildEmptyState(textPrimary, textMuted)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: roomOrders.length,
                        itemBuilder: (context, index) {
                          final order = roomOrders[index];
                          final isFirst = index == 0;
                          final isLast = index == roomOrders.length - 1;
                          return _TimelineItem(
                            order: order,
                            isFirst: isFirst,
                            isLast: isLast,
                            isDark: isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OrderDetailScreen(order: order),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textMuted) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFD6A85A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.clock,
                size: 28, color: Color(0xFFD6A85A)),
          ),
          const SizedBox(height: 14),
          Text(
            'Aucune intervention enregistrée',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Les ordres pour la chambre $roomNumber s\'afficheront ici.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.order,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
    required this.onTap,
  });

  final OrgOrder order;
  final bool isFirst;
  final bool isLast;
  final bool isDark;
  final VoidCallback onTap;

  IconData get _icon {
    final cat = (order.categoryName ?? '').toLowerCase();
    if (cat.contains('peint')) return LucideIcons.paintbrush;
    if (cat.contains('électr') || cat.contains('electr')) return LucideIcons.zap;
    if (cat.contains('plomb')) return LucideIcons.wrench;
    if (cat.contains('clim')) return LucideIcons.sprayCan;
    return LucideIcons.wrench;
  }

  Color get _nodeColor {
    final cat = (order.categoryName ?? '').toLowerCase();
    final desc = order.description.toLowerCase();
    if (desc.contains('critique') || desc.contains('urgent')) {
      return const Color(0xFFEF4444);
    }
    if (cat.contains('peint')) return const Color(0xFFD6A85A);
    if (cat.contains('électr') || cat.contains('electr')) {
      return const Color(0xFF22C55E);
    }
    if (cat.contains('plomb')) return const Color(0xFFF97316);
    return const Color(0xFFD6A85A);
  }

  bool get _isHighlighted {
    final desc = order.description.toLowerCase();
    return desc.contains('critique') || desc.contains('urgent');
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final nodeColor = _nodeColor;
    final cardBg = _isHighlighted
        ? (isDark ? const Color(0xFF241516) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF141416) : Colors.white);
    final borderColor = _isHighlighted
        ? (isDark ? const Color(0xFF5A2323) : const Color(0xFFFECACA))
        : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7));
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    final shortCode = order.id.length >= 6
        ? order.id.substring(0, 6).toUpperCase()
        : order.id.toUpperCase();
    final dateStr = _formatDate(order.completedAt ?? order.createdAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Timeline track & circular node
          SizedBox(
            width: 44,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Connecting line
                Positioned(
                  top: isFirst ? 20 : 0,
                  bottom: isLast ? 20 : 0,
                  child: Container(
                    width: 2,
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                  ),
                ),
                // Circular node with icon
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: nodeColor,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: nodeColor.withValues(alpha: 0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    _icon,
                    size: 16,
                    color: nodeColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right Card
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: Category title + Chevron
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.categoryName?.isNotEmpty == true
                                ? order.categoryName!
                                : '#$shortCode',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Order code subtitle
                    Text(
                      '${order.categoryName ?? ''} #$shortCode',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),

                    // Description
                    if (order.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Date & Completed status
                    Row(
                      children: [
                        Text(
                          '$dateStr · ',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: textMuted,
                          ),
                        ),
                        Text(
                          'Terminé',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF22C55E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
