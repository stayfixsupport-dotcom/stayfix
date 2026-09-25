import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/order_models.dart';
import '../../providers/hotel_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_card.dart';
import 'order_detail_screen.dart';
import 'create_order_screen.dart';
import 'order_notifications_screen.dart';

/// The main per-department live orders dashboard.
class OrderDashboardScreen extends StatelessWidget {
  const OrderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        final orders = provider.activeOrders;
        final unseen = orders.where((o) => o.status == OrderStatus.unseen).length;
        final inProgress = orders.where((o) => o.status == OrderStatus.inProgress).length;

        return Scaffold(
          backgroundColor: isDark ? SfColors.darkBgBase : SfColors.lightBgBase,
          appBar: _buildAppBar(context, provider, isDark, unseen),
          floatingActionButton: _buildFab(context),
          body: Column(
            children: [
              // Stat cards row
              _StatsRow(
                unseen: unseen,
                inProgress: inProgress,
                total: orders.length,
              ),
              // Orders list
              Expanded(
                child: orders.isEmpty
                    ? _EmptyState(
                        onCreateTap: () => _navigateToCreate(context))
                    : _OrderList(
                        orders: orders,
                        provider: provider,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context,
      OrderProvider provider, bool isDark, int unseenCount) {
    return AppBar(
      backgroundColor:
          isDark ? SfColors.darkBgBase : SfColors.lightBgBase,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tableau de bord',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? SfColors.darkTextPrimary
                  : SfColors.lightTextPrimary,
            ),
          ),
          if (provider.currentDeptId != null)
            Text(
              provider.departments
                  .where((d) => d.id == provider.currentDeptId)
                  .map((d) => d.name)
                  .firstOrNull ??
                  (provider.isDirector ? 'Directeur Général' : ''),
              style: GoogleFonts.inter(
                  fontSize: 12, color: SfColors.gold),
            ),
        ],
      ),
      actions: [
        // Notification bell
        Stack(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const OrderNotificationsScreen()),
              ),
            ),
            if (provider.unreadNotifCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: SfColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      provider.unreadNotifCount > 9
                          ? '9+'
                          : provider.unreadNotifCount.toString(),
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToCreate(context),
      backgroundColor: SfColors.gold,
      foregroundColor: Colors.black,
      icon: const Icon(LucideIcons.plus, size: 20),
      label: Text(
        'Nouvel ordre',
        style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.unseen,
    required this.inProgress,
    required this.total,
  });

  final int unseen;
  final int inProgress;
  final int total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _StatCard(
            label: 'Non vus',
            count: unseen,
            color: OrderStatus.unseen.color,
            icon: LucideIcons.eyeOff,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'En cours',
            count: inProgress,
            color: OrderStatus.inProgress.color,
            icon: LucideIcons.wrench,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Total actifs',
            count: total,
            color: SfColors.gold,
            icon: LucideIcons.clipboardList,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? SfColors.darkTextMuted
                    : SfColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order List ────────────────────────────────────────────────────────────────

class _OrderList extends StatefulWidget {
  const _OrderList({required this.orders, required this.provider});

  final List<OrgOrder> orders;
  final OrderProvider provider;

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> {
  String? _loadingOrderId;

  Future<void> _handleTake(OrgOrder order) async {
    if (widget.provider.isDirector) return;
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final user = hotelProvider.currentUser;
    if (user == null) return;
    setState(() => _loadingOrderId = order.id);
    await widget.provider.markSeen(
      orderId: order.id,
      byUserId: user.id,
      byUserName: user.fullName,
    );
    if (mounted) setState(() => _loadingOrderId = null);
  }

  Future<void> _handleComplete(OrgOrder order) async {
    if (widget.provider.isDirector) return;
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final user = hotelProvider.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terminer l\'ordre ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Terminer', style: TextStyle(color: SfColors.success)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loadingOrderId = order.id);
    await widget.provider.markCompleted(
      orderId: order.id,
      byUserId: user.id,
      byUserName: user.fullName,
    );
    if (mounted) setState(() => _loadingOrderId = null);
  }

  Future<void> _handleForward(OrgOrder order) async {
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final user = hotelProvider.currentUser;
    if (user == null) return;
    final currentDeptId = widget.provider.currentDeptId ?? order.currentDeptId;
    final otherDepts = widget.provider.departments
        .where((d) => d.id != order.currentDeptId)
        .toList();
    if (otherDepts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun autre département disponible.')),
      );
      return;
    }

    OrgDepartment? selected;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ForwardSheet(
        departments: otherDepts,
        onSelect: (dept) {
          selected = dept;
          Navigator.of(ctx).pop();
        },
      ),
    );
    if (selected == null) return;

    setState(() => _loadingOrderId = order.id);
    await widget.provider.forwardOrder(
      orderId: order.id,
      fromDeptId: currentDeptId,
      fromDeptName: widget.provider.departments
          .where((d) => d.id == currentDeptId)
          .map((d) => d.name)
          .firstOrNull ?? order.currentDeptName,
      toDeptId: selected!.id,
      toDeptName: selected!.name,
      byUserId: user.id,
      byUserName: user.fullName,
    );
    if (mounted) setState(() => _loadingOrderId = null);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<OrgOrder>.from(widget.orders)
      ..sort((a, b) {
        if (a.status == b.status) {
          return b.createdAt.compareTo(a.createdAt);
        }
        if (a.status == OrderStatus.unseen) return -1;
        if (b.status == OrderStatus.unseen) return 1;
        return 0;
      });

    final isDirector = widget.provider.isDirector;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final order = sorted[i];
        final isLoading = _loadingOrderId == order.id;
        final isDeptMember =
            !isDirector && widget.provider.currentDeptId == order.currentDeptId;
        final canTakeOrComplete = isDeptMember;
        final canForward =
            (isDirector || isDeptMember) && order.status != OrderStatus.completed;

        return IgnorePointer(
          ignoring: isLoading,
          child: Opacity(
            opacity: isLoading ? 0.6 : 1.0,
            child: OrderCard(
              order: order,
              showDepartment: isDirector,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: order),
                ),
              ),
              onTakeOrder: (canTakeOrComplete && order.status == OrderStatus.unseen)
                  ? () => _handleTake(order)
                  : null,
              onComplete: (canTakeOrComplete &&
                      (order.status == OrderStatus.inProgress ||
                          order.status == OrderStatus.unseen))
                  ? () => _handleComplete(order)
                  : null,
              onForward: canForward
                  ? () => _handleForward(order)
                  : null,
            ),
          ),
        );
      },
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SfColors.goldMuted,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(LucideIcons.clipboardList,
                  size: 36, color: SfColors.gold),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun ordre actif',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? SfColors.darkTextPrimary
                    : SfColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tous les ordres ont été traités\nou aucun ordre n\'a encore été créé.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? SfColors.darkTextMuted
                    : SfColors.lightTextMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Créer un ordre'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SfColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Forward Department Sheet ───────────────────────────────────────────────────

class _ForwardSheet extends StatelessWidget {
  const _ForwardSheet({
    required this.departments,
    required this.onSelect,
  });

  final List<OrgDepartment> departments;
  final ValueChanged<OrgDepartment> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? SfColors.darkBgSurface : SfColors.lightBgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? SfColors.darkBorder : SfColors.lightBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? SfColors.darkBorder : SfColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Transférer vers…',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? SfColors.darkTextPrimary
                    : SfColors.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...departments.map((dept) => ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SfColors.goldMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.building2,
                      size: 16, color: SfColors.gold),
                ),
                title: Text(
                  dept.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? SfColors.darkTextPrimary
                        : SfColors.lightTextPrimary,
                  ),
                ),
                trailing: const Icon(LucideIcons.arrowRight,
                    size: 16, color: SfColors.gold),
                onTap: () => onSelect(dept),
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
