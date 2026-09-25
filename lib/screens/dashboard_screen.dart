import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/theme_provider.dart';
import '../services/ai_sound_service.dart';
import '../models/hotel_models.dart';
import '../providers/hotel_provider.dart';
import '../providers/order_provider.dart';
import 'add_staff_screen.dart';
import 'auth_screen.dart';
import 'room_list_screen.dart';
import 'supervisor_dashboard.dart';
import '../widgets/settings_drawer.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenOrders;

  const DashboardScreen({super.key, this.onOpenOrders});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initData();
    }
  }

  void _initData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<HotelProvider>(context, listen: false);
        if (provider.currentUser != null && provider.selectedHotel != null) {
          // listenToHotelData() internally refreshes staff — no need to call
          // fetchHotelStaff() separately here, and generateDefaultRooms()
          // must NOT be called on every resume (it writes 469 documents!).
          provider.listenToHotelData();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<HotelProvider>(
      builder: (context, provider, child) {
        final user = provider.currentUser;

        if (_isLoggingOut) {
          return Scaffold(backgroundColor: theme.scaffoldBackgroundColor);
        }

        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            }
          });
          return Scaffold(backgroundColor: theme.scaffoldBackgroundColor);
        }

        if (user.role == UserRoles.director && provider.selectedHotel == null) {
          // Wait for listenToMyHotels to auto-select the first hotel
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            ),
          );
        }

        if (user.role.contains('Superviseur')) {
          return const SupervisorDashboard();
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          drawer: const SettingsDrawer(),
          appBar: _buildAppBar(context, user, provider),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              children: [
                _buildRoleBasedView(user, provider),
              ],
            ),
          ),
          floatingActionButton: _buildFab(context, user),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, HotelUser user, HotelProvider provider) {
    final theme = Theme.of(context);
    final isDirector = user.role == UserRoles.director;

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      toolbarHeight: 68,
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.fullName.toUpperCase(),
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: user.role,
                    style: GoogleFonts.inter(
                      color: isDirector
                          ? SfColors.gold
                          : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: isDirector ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (provider.selectedHotel?.name != null &&
                      provider.selectedHotel!.name.isNotEmpty) ...[
                    TextSpan(
                      text: " • ${provider.selectedHotel!.name}",
                      style: GoogleFonts.inter(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      actions: const [], // Actions moved to the Settings Drawer
    );
  }

  Widget _buildRoleBasedView(HotelUser user, HotelProvider provider) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    if (user.role == UserRoles.director) {
      return Expanded(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDirectorOverview(context, isDark, theme),
              const SizedBox(height: 16),
              _buildQuickActions(context, isDark, theme, user),
              const SizedBox(height: 24),
              Text(
                "ORDRES & INTERVENTIONS",
                style: GoogleFonts.inter(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              // ── Orders & Interventions Module ────────────────────────
              _ordersModuleTile(context, isDark, theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    if (user.role == UserRoles.housekeeping ||
        user.role == UserRoles.houseman ||
        user.role == UserRoles.staff) {
      final tasks = provider.rooms
          .where((r) => r.status.contains('Service') || r.status == 'Checkout')
          .toList();
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statCard("À Nettoyer", "${tasks.length}", LucideIcons.sprayCan),
            const SizedBox(height: 24),
            Text(
              "MES TÂCHES",
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        "Aucune chambre à nettoyer.",
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (ctx, i) {
                        final r = tasks[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: r.status == 'Checkout'
                                    ? SfColors.warning
                                    : SfColors.info,
                                width: 4,
                              ),
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              LucideIcons.bed,
                              color: theme.colorScheme.onSurface,
                            ),
                            title: Text(
                              "Chambre ${r.number}",
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              r.status.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                LucideIcons.checkCircle,
                                color: SfColors.success,
                              ),
                              onPressed: () =>
                                  provider.updateRoomStatus(r.id, 'Libre'),
                            ),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      );
    }

    bool canViewRooms = [
      UserRoles.housekeepingManager,
      UserRoles.maintenanceManager,
      UserRoles.receptionManager
    ].contains(user.role);
    if (canViewRooms) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _roomStatsCard(context, provider),
            const SizedBox(height: 24),
            Text(
              "ÉTAT DES CHAMBRES",
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: provider.rooms.isEmpty
                  ? Center(
                      child: Text(
                        "Aucune chambre.",
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: provider.rooms.length,
                      itemBuilder: (ctx, i) {
                        final r = provider.rooms[i];
                        if (r.status == 'Libre') return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              LucideIcons.bed,
                              color: r.status == 'Vendu'
                                  ? SfColors.danger
                                  : SfColors.warning,
                            ),
                            title: Text(
                              "Chambre ${r.number}",
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              r.status.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                            trailing: Text(
                              r.type,
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              height: 30,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MON ÉQUIPE",
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddStaffScreen(currentUserRole: user.role),
                    ),
                  ),
                  icon: const Icon(LucideIcons.userPlus, size: 14),
                  label: Text(
                    "Ajouter ouvrier",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? SfColors.gold : SfColors.goldDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: provider.hotelStaff.isEmpty
                  ? Center(
                      child: Text(
                        "Aucune équipe.",
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView(
                      children: provider.hotelStaff
                          .where((u) {
                            if (u.role == UserRoles.director || u.role == user.role) return false;
                            if (user.role == UserRoles.receptionManager) {
                              return u.role == UserRoles.staff;
                            } else if (user.role == UserRoles.maintenanceManager) {
                              return u.role == UserRoles.supervisor;
                            } else if (user.role == UserRoles.housekeepingManager) {
                              return u.role == UserRoles.housekeeping || u.role == UserRoles.houseman;
                            }
                            return false;
                          })
                          .map((staff) => _buildStaffTile(staff))
                          .toList(),
                    ),
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: Center(
        child: Text(
          "Bienvenue",
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showCreateRoomsDialog(BuildContext context, HotelProvider provider) {
    final TextEditingController controller = TextEditingController();
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141417) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Nombre de chambres",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Combien de chambres possède votre hôtel ?",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: "Ex: 50",
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? SfColors.darkBorder : SfColors.lightBorder,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: SfColors.gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Annuler",
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SfColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              int? count = int.tryParse(controller.text.trim());
              if (count != null && count > 0) {
                Navigator.pop(ctx);
                await provider.generateDefaultRooms(count: count);
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoomListScreen()),
                  );
                }
              }
            },
            child: const Text("Valider", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Premium banner tile that launches the Orders & Interventions module.
  Widget _ordersModuleTile(
      BuildContext context, bool isDark, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        if (widget.onOpenOrders != null) {
          widget.onOpenOrders!();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              SfColors.gold.withValues(alpha: 0.18),
              SfColors.goldDark.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: SfColors.gold.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: SfColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                LucideIcons.clipboardList,
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
                    'Ordres & Interventions',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? SfColors.darkTextPrimary
                          : SfColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Créer, gérer et tracer les ordres de travail',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? SfColors.darkTextMuted
                          : SfColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: SfColors.gold,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffTile(HotelUser staff) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? SfColors.darkBorder : SfColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: SfColors.gold.withValues(alpha: 0.15),
          child: Icon(
            _getRoleIcon(staff.role),
            color: isDark ? SfColors.gold : SfColors.goldDark,
            size: 18,
          ),
        ),
        title: Text(
          staff.fullName,
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          staff.role,
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _roomStatsCard(BuildContext context, HotelProvider provider) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? SfColors.darkBorder : SfColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                LucideIcons.bed,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (provider.rooms.isEmpty) {
                    _showCreateRoomsDialog(context, provider);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RoomListScreen()),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: SfColors.gold.withValues(alpha: 0.12),
                    border: Border.all(
                      color: isDark ? SfColors.gold : SfColors.goldDark,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    provider.rooms.isEmpty ? "CRÉER" : "VOIR",
                    style: GoogleFonts.inter(
                      color: isDark ? SfColors.gold : SfColors.goldDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "${provider.rooms.length}",
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Chambres Totales",
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    if (role.contains('Réception')) {
      return LucideIcons.conciergeBell;
    }
    if (role.contains('Gouvernante') || role.contains('Propreté')) {
      return LucideIcons.sparkles;
    }
    if (role.contains('Maintenance')) {
      return LucideIcons.hammer;
    }
    if (role.contains('Superviseur')) {
      return LucideIcons.eye;
    }
    return LucideIcons.user;
  }

  Widget? _buildFab(BuildContext context, HotelUser user) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    if (user.role == UserRoles.director ||
        [UserRoles.housekeeping, UserRoles.houseman, UserRoles.staff]
            .contains(user.role)) {
      return null;
    }
    return FloatingActionButton(
      backgroundColor: isDark ? SfColors.gold : SfColors.goldDark,
      child: const Icon(LucideIcons.userPlus, color: Colors.white),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddStaffScreen(currentUserRole: user.role),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? SfColors.darkBorder : SfColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            size: 24,
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDirectorModal(BuildContext context, HotelUser user) {
    unawaited(AiSoundService.playSelect());
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

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
          Navigator.pop(context);
          Navigator.push(
            this.context,
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

  Widget _buildDirectorOverview(BuildContext context, bool isDark, ThemeData theme) {
    final hotelProvider = Provider.of<HotelProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final totalRooms = hotelProvider.rooms.length;
    final cleanRooms = hotelProvider.rooms.where((r) => r.status == 'Libre').length;
    final totalStaff = hotelProvider.hotelStaff.length;
    final activeOrders = orderProvider.activeOrders.length;
    final inProgress = orderProvider.inProgressOrderCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "VUE D'ENSEMBLE",
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: SfColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SfColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: SfColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "En direct",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SfColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: "Ordres Actifs",
                value: "$activeOrders",
                subtitle: inProgress > 0 ? "$inProgress en cours" : "Aucun retard",
                icon: LucideIcons.clipboardList,
                accentColor: SfColors.gold,
                isDark: isDark,
                onTap: () {
                  if (widget.onOpenOrders != null) {
                    widget.onOpenOrders!();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: "Chambres",
                value: "$totalRooms",
                subtitle: "$cleanRooms prêtes",
                icon: LucideIcons.bedDouble,
                accentColor: const Color(0xFF38BDF8),
                isDark: isDark,
                onTap: () {
                  if (hotelProvider.rooms.isEmpty) {
                    _showCreateRoomsDialog(context, hotelProvider);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RoomListScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: "Équipe",
                value: "$totalStaff",
                subtitle: "Collaborateurs",
                icon: LucideIcons.users,
                accentColor: const Color(0xFFA78BFA),
                isDark: isDark,
                onTap: () {
                  final u = hotelProvider.currentUser;
                  if (u != null) {
                    _showAddDirectorModal(context, u);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: "Résolus",
                value: "${orderProvider.archivedOrders.length}",
                subtitle: "Clôturés",
                icon: LucideIcons.checkCircle2,
                accentColor: SfColors.success,
                isDark: isDark,
                onTap: () {
                  if (widget.onOpenOrders != null) {
                    widget.onOpenOrders!();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16161A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 18),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    color: isDark ? Colors.white24 : Colors.black26,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(
      BuildContext context, bool isDark, ThemeData theme, HotelUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ACTIONS RAPIDES",
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                label: "Ajouter Staff",
                icon: LucideIcons.userPlus,
                accentColor: SfColors.gold,
                isDark: isDark,
                onTap: () => _showAddDirectorModal(context, user),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                label: "Interventions",
                icon: LucideIcons.clipboardList,
                accentColor: const Color(0xFF38BDF8),
                isDark: isDark,
                onTap: () {
                  if (widget.onOpenOrders != null) {
                    widget.onOpenOrders!();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                label: "Chambres",
                icon: LucideIcons.doorOpen,
                accentColor: const Color(0xFFA78BFA),
                isDark: isDark,
                onTap: () {
                  final provider = Provider.of<HotelProvider>(context, listen: false);
                  if (provider.rooms.isEmpty) {
                    _showCreateRoomsDialog(context, provider);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RoomListScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          unawaited(AiSoundService.playSelect());
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16161A) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
