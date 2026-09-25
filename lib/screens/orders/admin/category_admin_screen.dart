import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_models.dart';
import '../../../services/order_service.dart';

/// Admin screen for managing intervention categories.
class CategoryAdminScreen extends StatefulWidget {
  const CategoryAdminScreen({super.key});

  @override
  State<CategoryAdminScreen> createState() => _CategoryAdminScreenState();
}

class _CategoryAdminScreenState extends State<CategoryAdminScreen> {
  List<OrgCategory> _all = [];
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
    final all = await OrderService.fetchAllCategories(hotelId);
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
        title: Text('Nouvelle catégorie',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Ex: Plomberie, Électricité…',
            hintStyle: GoogleFonts.inter(fontSize: 13),
          ),
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
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);
    await provider.createCategory(result);
    await _load();
  }

  Future<void> _showEditDialog(OrgCategory cat) async {
    final ctrl = TextEditingController(text: cat.name);
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
    await provider.updateCategory(catId: cat.id, name: result);
    await _load();
  }

  Future<void> _showDeleteDialog(OrgCategory cat) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: SfColors.danger)),
        content: Text('Voulez-vous vraiment supprimer la catégorie "${cat.name}" ?',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SfColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);
    await provider.deleteCategory(cat.id);
    await _load();
  }

  // Sample categories to quickly seed the database
  static const _kSeedCategories = [
    'Plomberie',
    'Électricité',
    'Climatisation',
    'Nettoyage',
    'Serrurerie',
    'Peinture',
    'Wi-Fi / Réseau',
    'Mobilier',
    'Autre',
  ];

  Future<void> _seedDefaults() async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    for (final name in _kSeedCategories) {
      await provider.createCategory(name);
    }
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
        title: Text('Gestion des catégories',
            style:
                GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (_all.isEmpty)
            TextButton(
              onPressed: _seedDefaults,
              child: Text(
                'Importer défauts',
                style: GoogleFonts.inter(
                    color: SfColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
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
                    final cat = _all[i];
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
                              color: cat.isActive
                                  ? SfColors.goldMuted
                                  : isDark
                                      ? SfColors.darkBgField
                                      : SfColors.lightBgField,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(LucideIcons.tag,
                                size: 18,
                                color: cat.isActive
                                    ? SfColors.gold
                                    : textMuted),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat.name,
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary)),
                                Text(
                                    cat.isActive ? 'Active' : 'Désactivée',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: cat.isActive
                                            ? SfColors.success
                                            : textMuted)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.pencil, size: 16),
                            color: SfColors.gold,
                            onPressed: () => _showEditDialog(cat),
                          ),
                          IconButton(
                            icon: Icon(
                              cat.isActive
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 16,
                            ),
                            color: cat.isActive
                                ? SfColors.danger
                                : SfColors.success,
                            onPressed: () async {
                              final provider = Provider.of<OrderProvider>(
                                  context,
                                  listen: false);
                              await provider.updateCategory(
                                  catId: cat.id,
                                  isActive: !cat.isActive);
                              await _load();
                            },
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 16),
                            color: SfColors.danger,
                            onPressed: () => _showDeleteDialog(cat),
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
          const Icon(LucideIcons.tag, size: 48, color: SfColors.gold),
          const SizedBox(height: 16),
          Text('Aucune catégorie',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 6),
          Text(
              'Appuyez sur + ou importez les catégories par défaut.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: SfColors.darkTextMuted)),
        ],
      ),
    );
  }
}
