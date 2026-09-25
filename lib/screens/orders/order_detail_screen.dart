import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/order_models.dart';
import '../../providers/hotel_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_status_chip.dart';
import '../../widgets/order_history_timeline.dart';
import '../../services/order_service.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});

  final OrgOrder order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<OrderHistoryEntry> _history = [];
  bool _loadingHistory = true;
  bool _actionLoading = false;
  late String _localDescription;

  @override
  void initState() {
    super.initState();
    _localDescription = widget.order.description;
    _tabs = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final hist = await provider.fetchHistory(widget.order.id);
    if (mounted) {
      setState(() {
        _history = hist;
        _loadingHistory = false;
      });
    }
  }

  Future<void> _handleTakeOrder() async {
    final hotelProvider =
        Provider.of<HotelProvider>(context, listen: false);
    final orderProvider =
        Provider.of<OrderProvider>(context, listen: false);
    if (orderProvider.isDirector) return;
    final user = hotelProvider.currentUser;
    if (user == null) return;

    setState(() => _actionLoading = true);
    await orderProvider.markSeen(
      orderId: widget.order.id,
      byUserId: user.id,
      byUserName: user.fullName,
    );
    setState(() => _actionLoading = false);
  }

  Future<void> _handleComplete() async {
    final hotelProvider =
        Provider.of<HotelProvider>(context, listen: false);
    final orderProvider =
        Provider.of<OrderProvider>(context, listen: false);
    if (orderProvider.isDirector) return;
    final user = hotelProvider.currentUser;
    if (user == null) return;

    final confirm = await _showConfirmDialog(
      title: 'Terminer l\'ordre ?',
      message:
          'Cette action marquera l\'ordre comme terminé. Cette action est définitive.',
      confirmLabel: 'Terminer',
      confirmColor: SfColors.success,
    );
    if (confirm != true) return;

    setState(() => _actionLoading = true);

    await orderProvider.markCompleted(
      orderId: widget.order.id,
      byUserId: user.id,
      byUserName: user.fullName,
    );
    setState(() => _actionLoading = false);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleForward() async {
    final orderProvider =
        Provider.of<OrderProvider>(context, listen: false);
    final hotelProvider =
        Provider.of<HotelProvider>(context, listen: false);
    final user = hotelProvider.currentUser!;
    final currentDeptId = orderProvider.currentDeptId ?? widget.order.currentDeptId;

    final otherDepts = orderProvider.departments
        .where((d) => d.id != widget.order.currentDeptId)
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

    setState(() => _actionLoading = true);
    await orderProvider.forwardOrder(
      orderId: widget.order.id,
      fromDeptId: currentDeptId,
      fromDeptName: orderProvider.departments
          .where((d) => d.id == currentDeptId)
          .map((d) => d.name)
          .firstOrNull ?? widget.order.currentDeptName,
      toDeptId: selected!.id,
      toDeptName: selected!.name,
      byUserId: user.id,
      byUserName: user.fullName,
    );
    setState(() => _actionLoading = false);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleAssignCategory() async {
    final orderProvider =
        Provider.of<OrderProvider>(context, listen: false);
    final hotelProvider =
        Provider.of<HotelProvider>(context, listen: false);
    final user = hotelProvider.currentUser!;
    var categories = orderProvider.categories;

    // Fallback if the stream didn't catch old categories missing the 'isActive' field.
    if (categories.isEmpty) {
      final hotelId = hotelProvider.selectedHotel?.id;
      if (hotelId != null) {
        final allCats = await OrderService.fetchAllCategories(hotelId);
        categories = allCats.where((c) => c.isActive).toList();
      }
    }

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune catégorie disponible.')),
      );
      return;
    }

    OrgCategory? selected;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AssignCategorySheet(
        categories: categories,
        onSelect: (cat) {
          selected = cat;
          Navigator.of(ctx).pop();
        },
      ),
    );

    if (selected == null) return;

    setState(() => _actionLoading = true);
    await orderProvider.assignCategory(
      orderId: widget.order.id,
      categoryId: selected!.id,
      categoryName: selected!.name,
      byUserId: user.id,
      byUserName: user.fullName,
    );
    setState(() => _actionLoading = false);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _editDescription() async {
    final controller = TextEditingController(text: _localDescription);
    final newDesc = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier la description',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SfColors.gold, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: SfColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newDesc != null && newDesc.trim() != _localDescription) {
      setState(() => _actionLoading = true);
      final provider = Provider.of<OrderProvider>(context, listen: false);
      await provider.updateOrderDescription(widget.order.id, newDesc);
      if (mounted) {
        setState(() {
          _localDescription = newDesc.trim();
          _actionLoading = false;
        });
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(message, style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SfColors.darkBgBase : SfColors.lightBgBase;
    final cardBg = isDark ? SfColors.darkBgCard : SfColors.lightBgCard;
    final textPrimary =
        isDark ? SfColors.darkTextPrimary : SfColors.lightTextPrimary;
    final textMuted =
        isDark ? SfColors.darkTextMuted : SfColors.lightTextMuted;
    final borderColor =
        isDark ? SfColors.darkBorder : SfColors.lightBorder;
    final order = widget.order;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ordre #${order.id.substring(0, 6).toUpperCase()}',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              order.categoryName?.isNotEmpty == true
                  ? order.categoryName!
                  : '\u26A0️ Sans catégorie',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: order.categoryName?.isNotEmpty == true
                      ? SfColors.gold
                      : SfColors.danger),
            ),
          ],
        ),
        actions: [
          OrderStatusChip(status: order.status),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: SfColors.gold,
          labelColor: SfColors.gold,
          unselectedLabelColor: textMuted,
          labelStyle: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Détails'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── TAB 1: Details ──────────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Status card
              _statusCard(order, isDark, cardBg, borderColor,
                  textPrimary, textMuted),
              const SizedBox(height: 16),

              // Info grid
              _infoCard(order, isDark, cardBg, borderColor,
                  textPrimary, textMuted),
              const SizedBox(height: 16),

              // Description
              _descriptionCard(order, isDark, cardBg, borderColor,
                  textPrimary, textMuted),
              const SizedBox(height: 28),

              // Action buttons
              if (order.status != OrderStatus.completed) ...[
                Builder(builder: (context) {
                  final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                  final isDirector = orderProvider.isDirector;
                  final isAssignedDept = orderProvider.currentDeptId == order.currentDeptId;
                  final canTakeOrComplete = !isDirector && isAssignedDept;
                  final canForward = isDirector || isAssignedDept;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Assign category button for directors or department managers when order is uncategorised
                      if ((isDirector || isAssignedDept) &&
                          (order.categoryId == null ||
                              order.categoryId!.isEmpty)) ...[
                        _actionButton(
                          label: 'Assigner une catégorie',
                          icon: LucideIcons.tag,
                          color: SfColors.warning,
                          onPressed:
                              _actionLoading ? null : _handleAssignCategory,
                          loading: _actionLoading,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (canTakeOrComplete && order.status == OrderStatus.unseen) ...[
                        _actionButton(
                          label: 'Prendre en charge',
                          icon: LucideIcons.play,
                          color: SfColors.info,
                          onPressed: _actionLoading ? null : _handleTakeOrder,
                          loading: _actionLoading,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (canTakeOrComplete &&
                          (order.status == OrderStatus.inProgress ||
                           order.status == OrderStatus.unseen)) ...[
                        _actionButton(
                          label: 'Marquer comme terminé',
                          icon: LucideIcons.checkCircle,
                          color: SfColors.success,
                          onPressed: _actionLoading ? null : _handleComplete,
                          loading: _actionLoading,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (canForward)
                        _actionButton(
                          label: 'Transférer l\'ordre',
                          icon: LucideIcons.arrowRight,
                          color: SfColors.gold,
                          onPressed: _actionLoading ? null : _handleForward,
                          loading: false,
                        ),
                      if (!canTakeOrComplete && !canForward)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.eye, size: 16, color: Colors.grey),
                              const SizedBox(width: 10),
                              Text(
                                'En attente de traitement par ${order.currentDeptName}',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }),
              ] else
                _completedBanner(isDark, textMuted, order),
            ],
          ),

          // ── TAB 2: History ──────────────────────────────────────────
          _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    OrderHistoryTimeline(history: _history),
                  ],
                ),
        ],
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _statusCard(OrgOrder order, bool isDark, Color cardBg,
      Color border, Color textPrimary, Color textMuted) {
    final statusColor = order.status.color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              order.status == OrderStatus.unseen
                  ? LucideIcons.eyeOff
                  : order.status == OrderStatus.inProgress
                      ? LucideIcons.wrench
                      : LucideIcons.checkCircle,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.status.label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              Text(
                _statusSubtitle(order),
                style: GoogleFonts.inter(fontSize: 12, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusSubtitle(OrgOrder order) {
    if (order.status == OrderStatus.completed && order.completedAt != null) {
      return 'Terminé le ${_formatFull(order.completedAt!)} par ${order.completedByName ?? "?"}';
    }
    if (order.seenAt != null) {
      return 'Vu le ${_formatFull(order.seenAt!)}';
    }
    return 'Envoyé le ${_formatFull(order.createdAt)}';
  }

  Widget _infoCard(OrgOrder order, bool isDark, Color cardBg, Color border,
      Color textPrimary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        children: [
          _infoRow(
              LucideIcons.tag,
              'Catégorie',
              (order.categoryName?.isNotEmpty == true)
                  ? order.categoryName!
                  : 'Sans catégorie',
              (order.categoryName?.isNotEmpty == true)
                  ? SfColors.gold
                  : SfColors.danger,
              textMuted,
              textPrimary),
          _divider(border),
          _infoRow(
            order.locationType == OrderLocationType.room
                ? LucideIcons.bedDouble
                : LucideIcons.mapPin,
            'Emplacement',
            order.locationDisplay,
            SfColors.info,
            textMuted,
            textPrimary,
          ),
          _divider(border),
          _infoRow(LucideIcons.user, 'Créé par', order.creatorName,
              SfColors.warning, textMuted, textPrimary),
          _divider(border),
          _infoRow(LucideIcons.building2, 'Département émetteur',
              order.creatorDeptName, SfColors.warning, textMuted, textPrimary),
          _divider(border),
          _infoRow(LucideIcons.send, 'Département actuel',
              order.currentDeptName, SfColors.gold, textMuted, textPrimary),
          _divider(border),
          _infoRow(LucideIcons.calendar, 'Date de création',
              _formatFull(order.createdAt), SfColors.info, textMuted,
              textPrimary),
        ],
      ),
    );
  }

  Widget _divider(Color color) =>
      Divider(height: 16, thickness: 0.5, color: color);

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
                  style: GoogleFonts.inter(
                      fontSize: 11, color: labelColor)),
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

  Widget _descriptionCard(OrgOrder order, bool isDark, Color cardBg,
      Color border, Color textPrimary, Color textMuted) {
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final isCreator = hotelProvider.currentUser?.id == order.creatorId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textMuted)),
                const SizedBox(height: 8),
                Text(
                  _localDescription,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: textPrimary, height: 1.5),
                ),
              ],
            ),
          ),
          if (isCreator && order.status != OrderStatus.completed)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: GestureDetector(
                onTap: _editDescription,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SfColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.edit3, size: 20, color: SfColors.gold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required bool loading,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor:
              color == SfColors.gold ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 10),
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }

  Widget _completedBanner(bool isDark, Color textMuted, OrgOrder order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SfColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: SfColors.success.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.checkCircle,
              color: SfColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              order.completedByName != null
                  ? 'Terminé par ${order.completedByName}'
                  : 'Ordre terminé',
              style: GoogleFonts.inter(
                  color: SfColors.success,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFull(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

// ── Assign Category Sheet ──────────────────────────────────────────────────────

class _AssignCategorySheet extends StatelessWidget {
  const _AssignCategorySheet({
    required this.categories,
    required this.onSelect,
  });

  final List<OrgCategory> categories;
  final ValueChanged<OrgCategory> onSelect;

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
            child: Row(
              children: [
                const Icon(LucideIcons.tag, size: 18, color: SfColors.gold),
                const SizedBox(width: 10),
                Text(
                  'Assigner une catégorie',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? SfColors.darkTextPrimary
                        : SfColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...categories.map((cat) => ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SfColors.goldMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.tag,
                      size: 16, color: SfColors.gold),
                ),
                title: Text(
                  cat.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? SfColors.darkTextPrimary
                        : SfColors.lightTextPrimary,
                  ),
                ),
                trailing: const Icon(LucideIcons.arrowRight,
                    size: 16, color: SfColors.gold),
                onTap: () => onSelect(cat),
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
