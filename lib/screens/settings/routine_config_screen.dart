import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../models/order_models.dart';
import '../../models/routine_models.dart';
import '../../providers/hotel_provider.dart';
import '../../services/routine_service.dart';

class RoutineConfigScreen extends StatefulWidget {
  const RoutineConfigScreen({super.key});

  @override
  State<RoutineConfigScreen> createState() => _RoutineConfigScreenState();
}

class _RoutineConfigScreenState extends State<RoutineConfigScreen> {
  final RoutineService _routineService = RoutineService();
  late Stream<List<RoutineTask>> _tasksStream;

  @override
  void initState() {
    super.initState();
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final hotelId = hotelProvider.selectedHotel?.id ?? '';
    _tasksStream = _routineService.streamTasks(hotelId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final provider = Provider.of<HotelProvider>(context);
    final hotelId = provider.selectedHotel?.id;

    if (hotelId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journée Quotidienne')),
        body: const Center(child: Text('Veuillez sélectionner un hôtel')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "JOURNÉE QUOTIDIENNE",
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: StreamBuilder<List<RoutineTask>>(
        stream: _tasksStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: SfColors.gold),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur de chargement',
                style: GoogleFonts.inter(color: SfColors.danger),
              ),
            );
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Aucune tâche configurée",
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskTile(context, task, isDark, theme);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskForm(context, hotelId),
        backgroundColor: isDark ? SfColors.gold : SfColors.goldDark,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: Text(
          "Nouvelle tâche",
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTaskTile(BuildContext context, RoutineTask task, bool isDark, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? SfColors.darkBorder : SfColors.lightBorder,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          task.name,
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.repeat,
                    size: 14,
                    color: SfColors.gold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getRecurrenceLabel(task),
                    style: GoogleFonts.inter(
                      color: SfColors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _getDeptLabel(task.departmentId),
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    task.isActive ? "• Actif" : "• Inactif",
                    style: GoogleFonts.inter(
                      color: task.isActive ? SfColors.success : SfColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(LucideIcons.moreVertical, color: theme.colorScheme.onSurface),
          onSelected: (value) {
            if (value == 'edit') {
              _showTaskForm(context, task.hotelId, task: task);
            } else if (value == 'delete') {
              _confirmDelete(context, task);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Modifier'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Supprimer', style: TextStyle(color: SfColors.danger)),
            ),
          ],
        ),
      ),
    );
  }

  String _getRecurrenceLabel(RoutineTask task) {
    switch (task.recurrenceType) {
      case RoutineRecurrenceType.daily:
        return "Chaque jour";
      case RoutineRecurrenceType.weekly:
        return "Chaque semaine (jour ${task.recurrenceDay})";
      case RoutineRecurrenceType.everyXDays:
        return "Tous les ${task.recurrenceInterval} jours";
      case RoutineRecurrenceType.monthly:
        return "Chaque mois (le ${task.recurrenceDay})";
    }
  }

  String _getDeptLabel(String deptId) {
    switch (deptId) {
      case 'dept_maintenance':
        return '🔧 Maintenance';
      case 'dept_housekeeping':
        return '🛏️ Gouvernante';
      case 'dept_reception':
        return '🏨 Réception';
      default:
        return deptId;
    }
  }

  Future<void> _confirmDelete(BuildContext context, RoutineTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la tâche ?'),
        content: Text('Voulez-vous vraiment supprimer "${task.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: SfColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _routineService.deleteTask(task.hotelId, task.id);
    }
  }

  void _showTaskForm(BuildContext context, String hotelId, {RoutineTask? task}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineTaskFormScreen(hotelId: hotelId, task: task),
      ),
    );
  }
}

class RoutineTaskFormScreen extends StatefulWidget {
  final String hotelId;
  final RoutineTask? task;

  const RoutineTaskFormScreen({super.key, required this.hotelId, this.task});

  @override
  State<RoutineTaskFormScreen> createState() => _RoutineTaskFormScreenState();
}

class _RoutineTaskFormScreenState extends State<RoutineTaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _locationController; // replaces locationType + detail/room

  late RoutineRecurrenceType _recurrenceType;
  late int _recurrenceInterval;
  late int _recurrenceDay;
  late bool _isActive;
  late String _departmentId;
  bool _isSubmitting = false;

  int _descLen = 0;

  // Department options
  static const List<Map<String, String>> _departments = [
    {'id': 'dept_maintenance', 'label': 'Maintenance', 'icon': '🔧'},
    {'id': 'dept_housekeeping', 'label': 'Gouvernante', 'icon': '🛏️'},
    {'id': 'dept_reception', 'label': 'Réception', 'icon': '🏨'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _descController = TextEditingController(text: widget.task?.description ?? '');
    // Restore location text: prefer locationDetail, fall back to roomNumber
    final existingLocation = widget.task?.locationDetail?.isNotEmpty == true
        ? widget.task!.locationDetail!
        : (widget.task?.roomNumber ?? '');
    _locationController = TextEditingController(text: existingLocation);

    _descLen = _descController.text.length;
    _descController.addListener(() {
      setState(() => _descLen = _descController.text.length);
    });
    _nameController.addListener(() => setState(() {}));
    _locationController.addListener(() => setState(() {}));

    _recurrenceType = widget.task?.recurrenceType ?? RoutineRecurrenceType.daily;
    _recurrenceInterval = widget.task?.recurrenceInterval ?? 1;
    _recurrenceDay = widget.task?.recurrenceDay ?? 1;
    _isActive = widget.task?.isActive ?? true;
    _departmentId = widget.task?.departmentId ?? 'dept_maintenance';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final service = RoutineService();
    final locationText = _locationController.text.trim();
    try {
      if (widget.task == null) {
        final newTask = RoutineTask(
          id: '',
          hotelId: widget.hotelId,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          isActive: _isActive,
          departmentId: _departmentId,
          locationType: OrderLocationType.other,
          locationDetail: locationText.isEmpty ? null : locationText,
          categoryId: 'routine',
          categoryName: 'Journée Quotidienne',
          recurrenceType: _recurrenceType,
          recurrenceInterval: _recurrenceInterval,
          recurrenceDay: _recurrenceDay,
          createdAt: DateTime.now(),
        );
        service.createTask(newTask);
      } else {
        final updatedTask = widget.task!.copyWith(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          isActive: _isActive,
          departmentId: _departmentId,
          locationType: OrderLocationType.other,
          locationDetail: locationText.isEmpty ? null : locationText,
          categoryId: 'routine',
          categoryName: 'Journée Quotidienne',
          recurrenceType: _recurrenceType,
          recurrenceInterval: _recurrenceInterval,
          recurrenceDay: _recurrenceDay,
        );
        service.updateTask(updatedTask);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text(widget.task == null ? 'Tâche créée avec succès !' : 'Tâche modifiée !'),
              ],
            ),
            backgroundColor: SfColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bg = isDark ? SfColors.darkBgBase : SfColors.lightBgBase;
    final cardBg = isDark ? SfColors.darkBgCard : SfColors.lightBgCard;
    final textPrimary = isDark ? SfColors.darkTextPrimary : SfColors.lightTextPrimary;
    final textMuted = isDark ? SfColors.darkTextMuted : SfColors.lightTextMuted;
    final border = isDark ? SfColors.darkBorder : SfColors.lightBorder;

    final step1Done = _nameController.text.trim().isNotEmpty;
    final step2Done = _locationController.text.trim().isNotEmpty;
    final step3Done = _departmentId.isNotEmpty;

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
          widget.task == null ? 'Nouvelle Tâche Routine' : 'Modifier Tâche',
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
          _RoutineStepIndicator(
            textMuted: textMuted,
            step1Done: step1Done,
            step2Done: step2Done,
            step3Done: step3Done,
          ),
          const SizedBox(height: 4),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // ── INFORMATIONS GÉNÉRALES ─────────────────────────
                  _RoutineSectionCard(
                    icon: LucideIcons.clipboardList,
                    title: 'INFORMATIONS GÉNÉRALES',
                    cardBg: cardBg,
                    border: border,
                    children: [
                      _RoutineFieldRow(icon: Icons.text_fields, label: 'Nom de la tâche'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                        decoration: _inputDecoration('Ex: Contrôler le PC', isDark),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 0.5),
                      const SizedBox(height: 16),

                      _RoutineFieldRow(icon: LucideIcons.pencil, label: 'Description (Optionnel)'),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          TextFormField(
                            controller: _descController,
                            maxLines: 4,
                            maxLength: 1000,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
                            style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                            decoration: _inputDecoration('Instructions supplémentaires…', isDark).copyWith(
                              contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            right: 12,
                            child: Text(
                              '$_descLen/1000',
                              style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── LIEU ───────────────────────────────────────────
                  _RoutineSectionCard(
                    icon: LucideIcons.mapPin,
                    title: 'LIEU',
                    cardBg: cardBg,
                    border: border,
                    children: [
                      _RoutineFieldRow(icon: LucideIcons.mapPin, label: 'Où se déroule la tâche ? (Optionnel)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                        decoration: _inputDecoration('Ex: Salle mécanique, Couloir RDC, Chambre 305…', isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── DÉPARTEMENT DESTINATAIRE ───────────────────────
                  _RoutineSectionCard(
                    icon: LucideIcons.building2,
                    title: 'DÉPARTEMENT & RÉCURRENCE',
                    cardBg: cardBg,
                    border: border,
                    children: [
                      _RoutineFieldRow(icon: LucideIcons.users, label: 'Département'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _departmentId,
                        decoration: _inputDecoration('Sélectionner un département', isDark),
                        dropdownColor: isDark ? SfColors.darkBgSurface : SfColors.lightBgSurface,
                        icon: Icon(LucideIcons.chevronDown, size: 18, color: textMuted),
                        style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                        items: _departments.map((d) => DropdownMenuItem(
                          value: d['id'],
                          child: Row(
                            children: [
                              Text(d['icon']!, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(d['label']!),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) { if (v != null) setState(() => _departmentId = v); },
                      ),
                      
                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 0.5),
                      const SizedBox(height: 16),

                      _RoutineFieldRow(icon: Icons.repeat, label: 'Récurrence'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<RoutineRecurrenceType>(
                        value: _recurrenceType,
                        decoration: _inputDecoration('', isDark),
                        dropdownColor: isDark ? SfColors.darkBgSurface : SfColors.lightBgSurface,
                        icon: Icon(LucideIcons.chevronDown, size: 18, color: textMuted),
                        style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                        items: RoutineRecurrenceType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.label))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _recurrenceType = v); },
                      ),

                      if (_recurrenceType == RoutineRecurrenceType.everyXDays) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: _recurrenceInterval.toString(),
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                          decoration: _inputDecoration('Nombre de jours (ex: 15)', isDark),
                          onChanged: (v) => _recurrenceInterval = int.tryParse(v) ?? 1,
                        ),
                      ],
                      if (_recurrenceType == RoutineRecurrenceType.monthly) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: _recurrenceDay.toString(),
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                          decoration: _inputDecoration('Jour du mois (1-31)', isDark),
                          onChanged: (v) => _recurrenceDay = int.tryParse(v) ?? 1,
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 0.5),
                      const SizedBox(height: 4),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Tâche active", style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                        value: _isActive,
                        activeColor: SfColors.gold,
                        onChanged: (val) => setState(() => _isActive = val),
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
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: bg,
              border: Border(top: BorderSide(color: border, width: 0.5)),
            ),
            child: GestureDetector(
              onTap: _isSubmitting ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 54,
                decoration: BoxDecoration(
                  gradient: _isSubmitting ? null : const LinearGradient(
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
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.save, size: 18, color: Colors.black),
                          Container(
                            width: 1, height: 22,
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                            color: Colors.black.withOpacity(0.25),
                          ),
                          Text(
                            'Enregistrer',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black),
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


  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: isDark ? SfColors.darkTextMuted : SfColors.lightTextMuted),
      filled: true,
      fillColor: isDark ? SfColors.darkBgField : SfColors.lightBgField,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SfColors.gold, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class _RoutineStepIndicator extends StatelessWidget {
  const _RoutineStepIndicator({required this.textMuted, required this.step1Done, required this.step2Done, required this.step3Done});
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
          _RoutineStep(number: 1, label: 'Informations', isActive: true, isCompleted: step1Done),
          _RoutineStepLine(active: step1Done),
          _RoutineStep(number: 2, label: 'Lieu', isActive: step1Done, isCompleted: step2Done),
          _RoutineStepLine(active: step2Done),
          _RoutineStep(number: 3, label: 'Destination', isActive: step2Done, isCompleted: step3Done),
        ],
      ),
    );
  }
}

class _RoutineStep extends StatelessWidget {
  const _RoutineStep({required this.number, required this.label, required this.isActive, required this.isCompleted});
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
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? SfColors.gold : (isActive ? SfColors.gold.withOpacity(0.18) : Colors.transparent),
            border: Border.all(color: lit ? SfColors.gold : const Color(0xFF3D3D3D), width: 1.5),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 15, color: Colors.black)
                : Text('$number', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: lit ? SfColors.gold : const Color(0xFF6B6B6B))),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: lit ? FontWeight.w600 : FontWeight.w400, color: lit ? SfColors.gold : const Color(0xFF6B6B6B))),
      ],
    );
  }
}

class _RoutineStepLine extends StatelessWidget {
  const _RoutineStepLine({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(height: 1.5, margin: const EdgeInsets.only(bottom: 16), color: active ? SfColors.gold : const Color(0xFF3D3D3D)),
    );
  }
}

class _RoutineSectionCard extends StatelessWidget {
  const _RoutineSectionCard({required this.icon, required this.title, required this.cardBg, required this.border, required this.children});
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: SfColors.gold),
                const SizedBox(width: 8),
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0)),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

class _RoutineFieldRow extends StatelessWidget {
  const _RoutineFieldRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: SfColors.gold),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}
