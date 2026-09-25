import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_models.dart';
import '../../../services/order_service.dart';

/// Admin screen for managing departments (create, edit, enable/disable).
class DepartmentAdminScreen extends StatefulWidget {
  const DepartmentAdminScreen({super.key});

  @override
  State<DepartmentAdminScreen> createState() => _DepartmentAdminScreenState();
}

class _DepartmentAdminScreenState extends State<DepartmentAdminScreen> {
  List<OrgDepartment> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final hotelId = provider.hotelId;
    if (hotelId == null) return;
    final all = await OrderService.fetchAllDepartments(hotelId);
    if (mounted) {
      setState(() {
        _all = all;
        _loading = false;
      });
    }
  }

  Future<void> _showCreateDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nouveau département',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Nom du département',
            hintStyle: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: SfColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);
    await provider.createDepartment(result);
    await _load();
  }

  Future<void> _showEditDialog(OrgDepartment dept) async {
    final ctrl = TextEditingController(text: dept.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
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
    if (result == null || result.isEmpty) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);
    await provider.updateDepartment(deptId: dept.id, name: result);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SfColors.darkBgBase : SfColors.lightBgBase;
    final cardBg = isDark ? SfColors.darkBgCard : SfColors.lightBgCard;
    final border = isDark ? SfColors.darkBorder : SfColors.lightBorder;
    final textPrimary =
        isDark ? SfColors.darkTextPrimary : SfColors.lightTextPrimary;
    final textMuted =
        isDark ? SfColors.darkTextMuted : SfColors.lightTextMuted;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Gestion des départements',
            style:
                GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: SfColors.gold,
        foregroundColor: Colors.black,
        icon: const Icon(LucideIcons.plus, size: 18),
        label: Text('Ajouter',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _all.isEmpty
              ? _emptyState(isDark, textPrimary)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _all.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final dept = _all[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: dept.isActive
                                  ? SfColors.goldMuted
                                  : isDark
                                      ? SfColors.darkBgField
                                      : SfColors.lightBgField,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(LucideIcons.building2,
                                size: 18,
                                color: dept.isActive
                                    ? SfColors.gold
                                    : textMuted),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dept.name,
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary)),
                                Text(
                                    dept.isActive ? 'Actif' : 'Désactivé',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: dept.isActive
                                            ? SfColors.success
                                            : textMuted)),
                              ],
                            ),
                          ),
                          // Edit
                          IconButton(
                            icon: const Icon(LucideIcons.pencil,
                                size: 16),
                            color: SfColors.gold,
                            onPressed: () => _showEditDialog(dept),
                          ),
                          // Toggle active
                          IconButton(
                            icon: Icon(
                              dept.isActive
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 16,
                            ),
                            color: dept.isActive
                                ? SfColors.danger
                                : SfColors.success,
                            onPressed: () async {
                              final provider = Provider.of<OrderProvider>(
                                  context,
                                  listen: false);
                              await provider.updateDepartment(
                                  deptId: dept.id,
                                  isActive: !dept.isActive);
                              await _load();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _emptyState(bool isDark, Color textPrimary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.building2, size: 48, color: SfColors.gold),
          const SizedBox(height: 16),
          Text('Aucun département',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 6),
          Text('Appuyez sur + pour ajouter un département.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: SfColors.darkTextMuted)),
        ],
      ),
    );
  }
}
