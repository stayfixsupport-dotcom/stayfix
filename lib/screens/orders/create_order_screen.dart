import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/order_models.dart';
import '../../providers/hotel_provider.dart';
import '../../providers/order_provider.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _locationDetailCtrl = TextEditingController();

  OrgCategory? _selectedCategory;
  OrgDepartment? _selectedDept;
  OrderLocationType _locationType = OrderLocationType.room;

  String? _selectedOtherLocation;
  bool _isSubmitting = false;
  int _descLen = 0;

  static const _kOtherLocations = [
    'Couloir',
    'Hall',
    'Réception',
    'Bureau',
    'Salle de réunion',
    'Escalier',
    'Parking',
    'Terrasse',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _descriptionCtrl.addListener(() {
      setState(() => _descLen = _descriptionCtrl.text.length);
    });
    _roomCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _roomCtrl.dispose();
    _locationDetailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final isDirector = orderProvider.isDirector;
    if (!isDirector && _selectedCategory == null) {
      _showError('Veuillez sélectionner une catégorie.');
      return;
    }
    if (_selectedDept == null) {
      _showError('Veuillez sélectionner un département destinataire.');
      return;
    }
    if (_locationType == OrderLocationType.room && _roomCtrl.text.trim().isEmpty) {
      _showError('Veuillez indiquer le numéro de chambre.');
      return;
    }
    if (_locationType == OrderLocationType.other && _selectedOtherLocation == null) {
      _showError('Veuillez indiquer l\'emplacement.');
      return;
    }

    setState(() => _isSubmitting = true);

    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final user = hotelProvider.currentUser!;

    final creatorDeptId = orderProvider.currentDeptId ?? '';
    final creatorDeptName = orderProvider.departments
            .where((d) => d.id == creatorDeptId)
            .map((d) => d.name)
            .firstOrNull ??
        user.role;

    final orderId = await orderProvider.createOrder(
      creatorId: user.id,
      creatorName: user.fullName,
      creatorDeptId: creatorDeptId,
      creatorDeptName: creatorDeptName,
      categoryId: _selectedCategory?.id ?? '',
      categoryName: _selectedCategory?.name ?? '',
      description: _descriptionCtrl.text.trim(),
      locationType: _locationType,
      roomNumber: _locationType == OrderLocationType.room ? _roomCtrl.text.trim() : null,
      locationDetail: _locationType == OrderLocationType.other
          ? (_selectedOtherLocation == 'Autre'
              ? _locationDetailCtrl.text.trim()
              : _selectedOtherLocation)
          : null,
      destDeptId: _selectedDept!.id,
      destDeptName: _selectedDept!.name,
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;

    if (orderId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Ordre envoyé avec succès !'),
            ],
          ),
          backgroundColor: SfColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).pop();
    } else {
      _showError(orderProvider.error ?? 'Erreur lors de l\'envoi.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: SfColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SfColors.darkBgBase : SfColors.lightBgBase;
    final cardBg = isDark ? SfColors.darkBgCard : SfColors.lightBgCard;
    final textPrimary = isDark ? SfColors.darkTextPrimary : SfColors.lightTextPrimary;
    final textMuted = isDark ? SfColors.darkTextMuted : SfColors.lightTextMuted;
    final border = isDark ? SfColors.darkBorder : SfColors.lightBorder;

    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final categories = orderProvider.categories;
        final departments = orderProvider.departments;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(LucideIcons.arrowLeft, color: SfColors.gold),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Créer un ordre',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
          body: Column(
            children: [
              // ── Step Indicator ─────────────────────────────────────────
              _StepIndicator(
                textMuted: textMuted,
                step1Done: _descLen > 0,
                step2Done: _locationType == OrderLocationType.room
                    ? _roomCtrl.text.trim().isNotEmpty
                    : _selectedOtherLocation != null,
                step3Done: _selectedDept != null,
              ),
              const SizedBox(height: 4),

              // ── Scrollable Form ────────────────────────────────────────
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // ── INFORMATIONS GÉNÉRALES ─────────────────────────
                      _SectionCard(
                        icon: LucideIcons.clipboardList,
                        title: 'INFORMATIONS GÉNÉRALES',
                        cardBg: cardBg,
                        border: border,
                        children: [
                          // Catégorie
                          if (!orderProvider.isDirector) ...[
                            _FieldRow(
                              icon: LucideIcons.tag,
                              label: 'Catégorie',
                              textMuted: textMuted,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<OrgCategory>(
                              value: _selectedCategory,
                              decoration: _inputDecoration('Sélectionner une catégorie', isDark),
                              dropdownColor: isDark
                                  ? SfColors.darkBgSurface
                                  : SfColors.lightBgSurface,
                              icon: Icon(LucideIcons.chevronDown,
                                  size: 18, color: textMuted),
                              style: GoogleFonts.inter(
                                  color: textPrimary, fontSize: 14),
                              items: categories
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedCategory = v),
                              validator: (v) => v == null ? 'Requis' : null,
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, thickness: 0.5),
                            const SizedBox(height: 16),
                          ],

                          // Description
                          _FieldRow(
                            icon: LucideIcons.pencil,
                            label: 'Description',
                            textMuted: textMuted,
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              TextFormField(
                                controller: _descriptionCtrl,
                                maxLines: 5,
                                maxLength: 1000,
                                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                                    const SizedBox.shrink(),
                                style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                                decoration: _inputDecoration('Décrivez le problème en détail…', isDark)
                                    .copyWith(
                                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ),
                              Positioned(
                                bottom: 10,
                                right: 12,
                                child: Text(
                                  '$_descLen/1000',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── LOCALISATION ───────────────────────────────────
                      _SectionCard(
                        icon: LucideIcons.mapPin,
                        title: 'LOCALISATION',
                        cardBg: cardBg,
                        border: border,
                        children: [
                          _FieldRow(
                            icon: LucideIcons.mapPin,
                            label: 'Type de lieu',
                            textMuted: textMuted,
                          ),
                          const SizedBox(height: 10),

                          // Toggle row
                          Row(
                            children: [
                              _locationToggle(
                                label: 'Chambre',
                                icon: LucideIcons.bedDouble,
                                selected: _locationType == OrderLocationType.room,
                                onTap: () => setState(() => _locationType = OrderLocationType.room),
                              ),
                              const SizedBox(width: 10),
                              _locationToggle(
                                label: 'Autre',
                                icon: LucideIcons.mapPin,
                                selected: _locationType == OrderLocationType.other,
                                onTap: () => setState(() => _locationType = OrderLocationType.other),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Room number
                          if (_locationType == OrderLocationType.room) ...[
                            _FieldRow(
                              icon: LucideIcons.hash,
                              label: 'Numéro / nom de chambre',
                              textMuted: textMuted,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _roomCtrl,
                              keyboardType: TextInputType.text,
                              style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                              decoration: _inputDecoration('Numéro / nom de chambre', isDark),
                              validator: (v) =>
                                  _locationType == OrderLocationType.room &&
                                          (v == null || v.trim().isEmpty)
                                      ? 'Requis'
                                      : null,
                            ),
                          ],

                          if (_locationType == OrderLocationType.other) ...[
                            _FieldRow(
                              icon: LucideIcons.hash,
                              label: 'Préciser le lieu',
                              textMuted: textMuted,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedOtherLocation,
                              decoration: _inputDecoration('Préciser le lieu', isDark),
                              dropdownColor: isDark ? SfColors.darkBgSurface : SfColors.lightBgSurface,
                              icon: Icon(LucideIcons.chevronDown, size: 18, color: textMuted),
                              style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                              items: _kOtherLocations
                                  .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedOtherLocation = v),
                              validator: (v) =>
                                  _locationType == OrderLocationType.other && v == null
                                      ? 'Requis'
                                      : null,
                            ),
                            if (_selectedOtherLocation == 'Autre') ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _locationDetailCtrl,
                                style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                                decoration: _inputDecoration('Précisez…', isDark),
                              ),
                            ],
                          ],
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── DÉPARTEMENT DESTINATAIRE ───────────────────────
                      _SectionCard(
                        icon: LucideIcons.building2,
                        title: 'DÉPARTEMENT DESTINATAIRE',
                        cardBg: cardBg,
                        border: border,
                        children: [
                          _FieldRow(
                            icon: LucideIcons.users,
                            label: 'Envoyer à',
                            textMuted: textMuted,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<OrgDepartment>(
                            value: _selectedDept,
                            decoration: _inputDecoration('Sélectionner un département', isDark),
                            dropdownColor: isDark ? SfColors.darkBgSurface : SfColors.lightBgSurface,
                            icon: Icon(LucideIcons.chevronDown, size: 18, color: textMuted),
                            style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                            items: departments
                                .map((d) => DropdownMenuItem(
                                      value: d,
                                      child: Row(
                                        children: [
                                          const Icon(LucideIcons.building2,
                                              size: 14, color: SfColors.gold),
                                          const SizedBox(width: 8),
                                          Text(d.name),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedDept = v),
                            validator: (v) => v == null ? 'Requis' : null,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Fixed Bottom Send Button ───────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(
                    top: BorderSide(color: border, width: 0.5),
                  ),
                ),
                child: GestureDetector(
                  onTap: _isSubmitting ? null : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: _isSubmitting
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFE8C27A), Color(0xFFD6A85A)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      color: _isSubmitting ? SfColors.darkBgCard : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _isSubmitting
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.send,
                                  size: 18, color: Colors.black),
                              Container(
                                width: 1,
                                height: 22,
                                margin: const EdgeInsets.symmetric(horizontal: 14),
                                color: Colors.black.withOpacity(0.25),
                              ),
                              Text(
                                'Envoyer l\'ordre',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Location toggle ─────────────────────────────────────────────────────────

  Widget _locationToggle({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? SfColors.gold.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? SfColors.gold : SfColors.darkBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: selected ? SfColors.gold : SfColors.darkTextMuted),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? SfColors.gold : SfColors.darkTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 13,
        color: isDark ? SfColors.darkTextMuted : SfColors.lightTextMuted,
      ),
      filled: true,
      fillColor: isDark ? SfColors.darkBgField : SfColors.lightBgField,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SfColors.gold, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

// ── Step Indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.textMuted,
    required this.step1Done,
    required this.step2Done,
    required this.step3Done,
  });
  final Color textMuted;
  final bool step1Done;
  final bool step2Done;
  final bool step3Done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _Step(number: 1, label: 'Informations', isActive: true, isCompleted: step1Done),
          _StepLine(active: step1Done),
          _Step(number: 2, label: 'Localisation', isActive: step1Done, isCompleted: step2Done),
          _StepLine(active: step2Done),
          _Step(number: 3, label: 'Destination', isActive: step2Done, isCompleted: step3Done),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final int number;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final bool lit = isActive || isCompleted;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? SfColors.gold
                : (isActive ? SfColors.gold.withOpacity(0.18) : Colors.transparent),
            border: Border.all(
              color: lit ? SfColors.gold : const Color(0xFF3D3D3D),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 15, color: Colors.black)
                : Text(
                    '$number',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: lit ? SfColors.gold : const Color(0xFF6B6B6B),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: lit ? FontWeight.w600 : FontWeight.w400,
            color: lit ? SfColors.gold : const Color(0xFF6B6B6B),
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.only(bottom: 16),
        color: active ? SfColors.gold : const Color(0xFF3D3D3D),
      ),
    );
  }
}

// ── Section Card ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.cardBg,
    required this.border,
    required this.children,
  });

  final IconData icon;
  final String title;
  final Color cardBg;
  final Color border;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: SfColors.gold),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field Row Label ────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.textMuted,
  });

  final IconData icon;
  final String label;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: SfColors.gold),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
