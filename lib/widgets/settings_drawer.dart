import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/theme_provider.dart';
import '../providers/hotel_provider.dart';
import '../screens/profile_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/privacy_account_center_screen.dart';
import '../screens/selection_screen.dart';
import '../models/hotel_models.dart';
import '../screens/orders/order_hub_screen.dart';
import '../screens/settings/routine_config_screen.dart';
import '../screens/coming_soon_screen.dart';
import '../screens/orders/order_archive_screen.dart';
import '../screens/add_staff_screen.dart';
import '../services/ai_sound_service.dart';
import 'dart:async';

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final hotelProvider = Provider.of<HotelProvider>(context);
    final user = hotelProvider.currentUser;

    if (user == null) {
      return const Drawer(child: SizedBox.shrink());
    }

    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF8F9FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header (Profile Info)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isDark ? const Color(0xFF18181b) : Colors.grey[200],
                    child: Icon(LucideIcons.user, size: 30, color: textPrimary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.role,
                          style: GoogleFonts.inter(
                            color: SfColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Settings Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(
                    icon: LucideIcons.user,
                    title: 'Mon Profil',
                    textColor: textPrimary,
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                  if (user.role == UserRoles.director)
                    _drawerItem(
                      icon: Icons.archive_outlined,
                      title: 'Archives',
                      textColor: textPrimary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrderArchiveScreen()),
                        );
                      },
                    ),
                  if (user.role == UserRoles.director || user.role == UserRoles.maintenanceManager)
                    _drawerItem(
                      icon: Icons.assignment_outlined,
                      title: 'Journée Quotidienne',
                      textColor: textPrimary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoutineConfigScreen(),
                          ),
                        );
                      },
                    ),
                  if (user.role == UserRoles.director) ...[
                    _drawerItem(
                      icon: LucideIcons.userPlus,
                      title: 'Ajouter Directeur',
                      textColor: textPrimary,
                      onTap: () {
                        // Don't pop the drawer first — _showAddDirectorModal handles full dismissal
                        _showAddDirectorModal(context, user);
                      },
                    ),
                    _drawerItem(
                      icon: LucideIcons.users,
                      title: 'Directeurs de département',
                      textColor: textPrimary,
                      onTap: () {
                        Navigator.pop(context);
                        _showDepartmentDirectorsSheet(context);
                      },
                    ),
                    _drawerItem(
                      icon: LucideIcons.eye,
                      title: 'Ajouter Superviseur',
                      textColor: textPrimary,
                      onTap: () {
                        // Capture navigator before closing drawer
                        final nav = Navigator.of(context);
                        nav.pop(); // close drawer
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => AddStaffScreen(
                              currentUserRole: user.role,
                              isAddingSupervisorMode: true,
                            ),
                          ),
                        );
                      },
                    ),
                    _drawerItem(
                      icon: Icons.folder_outlined,
                      title: 'Les références',
                      textColor: textPrimary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComingSoonScreen(title: 'Les références'),
                          ),
                        );
                      },
                    ),
                    _drawerItem(
                      icon: Icons.inventory_2_outlined,
                      title: 'Le stock',
                      textColor: textPrimary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComingSoonScreen(title: 'Le stock'),
                          ),
                        );
                      },
                    ),
                  ],
                  _drawerItem(
                    icon: LucideIcons.shieldCheck,
                    title: 'Confidentialité et compte',
                    textColor: textPrimary,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyAccountCenterScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    icon: isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                    title: isDark ? 'Mode clair' : 'Mode sombre',
                    textColor: textPrimary,
                    onTap: () {
                      themeProvider.toggleTheme();
                    },
                  ),
                ],
              ),
            ),

            // Logout Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  final hotelProvider =
                      Provider.of<HotelProvider>(context, listen: false);
                  
                  // Navigate immediately for instant UX
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                  
                  // Perform heavy sign-out tasks in the background
                  hotelProvider.logout();
                },
                icon: const Icon(LucideIcons.logOut, color: SfColors.danger),
                label: Text(
                  "DÉCONNEXION",
                  style: GoogleFonts.inter(
                    color: SfColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: SfColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showDepartmentDirectorsSheet(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final provider = Provider.of<HotelProvider>(context, listen: false);
    final staff = provider.hotelStaff
        .where((u) => u.role != UserRoles.director)
        .toList();

    final bg = isDark ? const Color(0xFF141417) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: SfColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.users,
                            color: SfColors.gold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Directeurs de département',
                              style: GoogleFonts.inter(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${staff.length} membre${staff.length != 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                color: textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(color: borderColor, height: 1),
                  // Staff list
                  Expanded(
                    child: staff.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun personnel ajouté.',
                              style: GoogleFonts.inter(color: textMuted),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: staff.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final member = staff[i];
                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1C1C1F)
                                      : const Color(0xFFF4F4F5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        SfColors.gold.withValues(alpha: 0.15),
                                    child: Icon(
                                      LucideIcons.user,
                                      color: isDark
                                          ? SfColors.gold
                                          : SfColors.goldDark,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    member.fullName,
                                    style: GoogleFonts.inter(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    member.role,
                                    style: GoogleFonts.inter(
                                      color: textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddDirectorModal(BuildContext context, HotelUser user) {

    unawaited(AiSoundService.playSelect());
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    // Capture the navigator NOW, while context is still valid (drawer is still open)
    final navigator = Navigator.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141417) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : SfColors.lightBorder,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SfColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.userPlus,
                      color: SfColors.gold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Ajouter un Directeur",
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Sélectionnez le département à rattacher",
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDirectorChoiceCard(
                navigator: navigator,
                context: ctx,
                title: "Directeur Maintenance",
                subtitle: "Suivi technique et réparations",
                icon: LucideIcons.wrench,
                role: UserRoles.maintenanceManager,
                user: user,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildDirectorChoiceCard(
                navigator: navigator,
                context: ctx,
                title: "Directeur Propreté",
                subtitle: "Gouvernante et hygiène",
                icon: LucideIcons.sparkles,
                role: UserRoles.housekeepingManager,
                user: user,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildDirectorChoiceCard(
                navigator: navigator,
                context: ctx,
                title: "Directeur Réception",
                subtitle: "Accueil et réservations",
                icon: LucideIcons.conciergeBell,
                role: UserRoles.receptionManager,
                user: user,
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDirectorChoiceCard({
    required NavigatorState navigator,
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String role,
    required HotelUser user,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context); // Close bottom sheet
          navigator.pop();        // Close drawer
          navigator.push(         // Navigate to AddStaffScreen
            MaterialPageRoute(
              builder: (_) => AddStaffScreen(
                currentUserRole: user.role,
                isAddingSupervisorMode: false,
                initialRole: role,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDark ? SfColors.gold : SfColors.goldDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
