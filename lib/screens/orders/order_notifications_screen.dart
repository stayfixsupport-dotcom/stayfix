import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/order_provider.dart';
import 'order_detail_screen.dart';

/// Screen showing the notification feed for the current department.
class OrderNotificationsScreen extends StatefulWidget {
  const OrderNotificationsScreen({super.key});

  @override
  State<OrderNotificationsScreen> createState() =>
      _OrderNotificationsScreenState();
}

class _OrderNotificationsScreenState
    extends State<OrderNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false)
            .markAllNotificationsRead();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SfColors.darkBgBase : SfColors.lightBgBase;
    final textPrimary =
        isDark ? SfColors.darkTextPrimary : SfColors.lightTextPrimary;
    final textMuted =
        isDark ? SfColors.darkTextMuted : SfColors.lightTextMuted;

    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        final notifs = provider.notifications;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Notifications',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (notifs.isNotEmpty)
                TextButton(
                  onPressed: provider.markAllNotificationsRead,
                  child: Text(
                    'Tout lire',
                    style: GoogleFonts.inter(
                        color: SfColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          body: notifs.isEmpty
              ? _emptyState(isDark, textPrimary, textMuted)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final notif = notifs[i];
                    return _NotifCard(
                      notif: notif,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      onTap: () async {
                        await provider
                            .markNotificationRead(notif.id);
                        if (!mounted) return;
                        // Find the order and navigate
                        final order = provider.activeOrders
                            .where((o) => o.id == notif.orderId)
                            .firstOrNull;
                        if (order != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderDetailScreen(order: order),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _emptyState(bool isDark, Color textPrimary, Color textMuted) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: SfColors.goldMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(LucideIcons.bell,
                size: 30, color: SfColors.gold),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Les nouvelles notifications apparaîtront ici.',
            style:
                GoogleFonts.inter(fontSize: 12, color: textMuted),
          ),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.notif,
    required this.isDark,
    required this.textPrimary,
    required this.textMuted,
    required this.onTap,
  });

  final dynamic notif;
  final bool isDark;
  final Color textPrimary;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notif.read as bool;
    final cardBg = isDark ? SfColors.darkBgCard : SfColors.lightBgCard;
    final borderColor = isRead
        ? (isDark ? SfColors.darkBorder : SfColors.lightBorder)
        : SfColors.gold.withOpacity(0.4);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? cardBg : SfColors.goldMuted.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isRead
                    ? (isDark
                        ? SfColors.darkBgField
                        : SfColors.lightBgField)
                    : SfColors.goldMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                notif.title.toString().contains('transféré')
                    ? LucideIcons.arrowRight
                    : LucideIcons.bell,
                size: 18,
                color: isRead ? textMuted : SfColors.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: SfColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notif.createdAt as DateTime),
                    style: GoogleFonts.inter(
                        fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronRight,
                size: 14, color: SfColors.gold),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
