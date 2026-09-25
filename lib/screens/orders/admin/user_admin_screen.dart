import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_models.dart';

/// Admin screen for assigning users to departments and setting org roles.
class UserAdminScreen extends StatefulWidget {
  const UserAdminScreen({super.key});

  @override
  State<UserAdminScreen> createState() => _UserAdminScreenState();
}

class _UserAdminScreenState extends State<UserAdminScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final users = await provider.fetchOrgUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _loading = false;
      });
    }
  }

  Future<void> _showAssignDialog(Map<String, dynamic> user) async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final departments = provider.departments;
    OrgDepartment? selectedDept;
    String selectedRole = 'staff';

    final currentDeptId = user['orgDeptId'] as String?;
    if (currentDeptId != null) {
      selectedDept = departments
          .where((d) => d.id == currentDeptId)
          .firstOrNull;
    }
    if (user['orgRole'] != null) {
      selectedRole = user['orgRole'] as String;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark =
              Theme.of(context).brightness == Brightness.dark;
          return Container(
            margin: const EdgeInsets.all(12),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? SfColors.darkBgSurface
                  : SfColors.lightBgSurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigner ${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),

                // Department picker
                Text('Département',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SfColors.darkTextMuted)),
                const SizedBox(height: 6),
                DropdownButtonFormField<OrgDepartment>(
                  value: selectedDept,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LucideIcons.building2,
                        size: 16, color: SfColors.gold),
                  ),
                  dropdownColor: isDark
                      ? SfColors.darkBgSurface
                      : SfColors.lightBgSurface,
                  items: departments
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setModalState(() => selectedDept = v),
                  hint: const Text('Sélectionner un département'),
                ),
                const SizedBox(height: 14),

                // Role picker
                Text('Rôle organisationnel',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SfColors.darkTextMuted)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LucideIcons.shieldCheck,
                        size: 16, color: SfColors.gold),
                  ),
                  dropdownColor: isDark
                      ? SfColors.darkBgSurface
                      : SfColors.lightBgSurface,
                  items: const [
                    DropdownMenuItem(
                        value: 'director',
                        child: Text('Directeur Général')),
                    DropdownMenuItem(
                        value: 'manager',
                        child: Text('Responsable département')),
                    DropdownMenuItem(
                        value: 'staff',
                        child: Text('Employé / Staff')),
                  ],
                  onChanged: (v) =>
                      setModalState(() => selectedRole = v ?? 'staff'),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    // Remove assignment
                    if (currentDeptId != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await provider
                                .assignUserToDepartment(
                              userId: user['id'] as String,
                              deptId: '',
                              deptName: '',
                              orgRole: '',
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              await _load();
                            }
                          },
                          icon: const Icon(LucideIcons.userX,
                              size: 16, color: SfColors.danger),
                          label: Text('Retirer',
                              style: GoogleFonts.inter(
                                  color: SfColors.danger)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: SfColors.danger),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    if (currentDeptId != null)
                      const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: selectedDept == null
                            ? null
                            : () async {
                                await provider
                                    .assignUserToDepartment(
                                  userId: user['id'] as String,
                                  deptId: selectedDept!.id,
                                  deptName: selectedDept!.name,
                                  orgRole: selectedRole,
                                );
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  await _load();
                                }
                              },
                        icon: const Icon(LucideIcons.save, size: 16),
                        label: Text('Enregistrer',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SfColors.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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
        title: Text('Gestion des utilisateurs',
            style:
                GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCcw, size: 18),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text(
                    'Aucun utilisateur trouvé.',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: textMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final user = _users[i];
                    final name =
                        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                            .trim();
                    final role = user['role'] as String? ?? '';
                    final orgDept = user['orgDeptName'] as String?;
                    final orgRole = user['orgRole'] as String?;
                    final hasAssignment =
                        orgDept != null && orgDept.isNotEmpty;

                    return GestureDetector(
                      onTap: () => _showAssignDialog(user),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: hasAssignment
                                  ? SfColors.goldMuted.withOpacity(0.5)
                                  : border,
                              width: 1),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: hasAssignment
                                    ? SfColors.goldMuted
                                    : isDark
                                        ? SfColors.darkBgField
                                        : SfColors.lightBgField,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: hasAssignment
                                        ? SfColors.gold
                                        : textMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isNotEmpty
                                        ? name
                                        : user['email'] ?? 'Inconnu',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary),
                                  ),
                                  Text(role,
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: textMuted)),
                                  if (hasAssignment) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                            LucideIcons.building2,
                                            size: 10,
                                            color: SfColors.gold),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$orgDept${orgRole != null ? ' · ${_roleLabel(orgRole)}' : ''}',
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: SfColors.gold,
                                              fontWeight:
                                                  FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              hasAssignment
                                  ? LucideIcons.pencil
                                  : LucideIcons.userPlus,
                              size: 16,
                              color: SfColors.gold,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'director':
        return 'Directeur';
      case 'manager':
        return 'Responsable';
      default:
        return 'Staff';
    }
  }
}
