import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/order_provider.dart';
import '../../providers/hotel_provider.dart';
import 'order_dashboard_screen.dart';
import 'order_calendar_screen.dart';
import 'admin/department_admin_screen.dart';
import 'admin/category_admin_screen.dart';
import 'admin/user_admin_screen.dart';
import '../../models/hotel_models.dart';
import '../coming_soon_screen.dart';
import '../dashboard_screen.dart';
import '../manager_messages_screen.dart';

/// Entry point hub for the Orders & Interventions module.
class OrderHubScreen extends StatefulWidget {
  const OrderHubScreen({super.key});

  @override
  State<OrderHubScreen> createState() => _OrderHubScreenState();
}

class _OrderHubScreenState extends State<OrderHubScreen> {
  int _tab = 0;

  /// Tracks the last (hotelId, deptId) pair used to init so we don't
  /// re-subscribe on unrelated HotelProvider notifications.
  String _lastInitKey = '';

  @override
  void initState() {
    super.initState();
    // Attempt immediately AND listen for future changes (user/hotel may load late).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryInitOrderProvider();
      // Re-run whenever HotelProvider notifies (e.g. user data or hotel loads).
      Provider.of<HotelProvider>(context, listen: false)
          .addListener(_tryInitOrderProvider);
    });
  }

  @override
  void dispose() {
    // Remove the listener safely (context may already be detached).
    try {
      Provider.of<HotelProvider>(context, listen: false)
          .removeListener(_tryInitOrderProvider);
    } catch (_) {}
    super.dispose();
  }

  /// Maps a user role to its fixed department ID.
  static String _deptIdForRole(String role) {
    if (role == UserRoles.maintenanceManager ||
        role == UserRoles.supervisor) {
      return 'dept_maintenance';
    }
    if (role == UserRoles.housekeepingManager ||
        role == UserRoles.housekeeping ||
        role == UserRoles.houseman) {
      return 'dept_housekeeping';
    }
    if (role == UserRoles.receptionManager ||
        role == UserRoles.staff) {
      return 'dept_reception';
    }
    return ''; // director or unknown → empty (all-orders stream)
  }

  void _tryInitOrderProvider() {
    if (!mounted) return;
    final hotelProvider =
        Provider.of<HotelProvider>(context, listen: false);
    final orderProvider =
        Provider.of<OrderProvider>(context, listen: false);

    final user = hotelProvider.currentUser;
    final hotel = hotelProvider.selectedHotel;

    // Wait until both are available.
    if (user == null || hotel == null) return;

    final isDirector = hotelProvider.isDirector;
    final deptId = isDirector ? '' : _deptIdForRole(user.role);

    // Deduplicate: skip if nothing changed.
    final initKey = '${hotel.id}|$deptId|$isDirector';
    if (initKey == _lastInitKey) return;
    _lastInitKey = initKey;

    orderProvider.init(
      hotelId: hotel.id,
      deptId: deptId,
      isDirector: isDirector,
    );
  }

  bool get _isDirector {
    final hotelProvider =
        Provider.of<HotelProvider>(context, listen: false);
    return hotelProvider.isDirector;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SfColors.darkBgBase : SfColors.lightBgBase;

    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final List<_TabItem> currentTabs = [
          const _TabItem(icon: LucideIcons.home, label: 'Accueil'),
          const _TabItem(icon: LucideIcons.messageSquare, label: 'Chat'),
          const _TabItem(icon: LucideIcons.layoutGrid, label: 'Ordres'),
          const _TabItem(icon: LucideIcons.calendarDays, label: 'Calendrier'),
        ];

        final pages = [
          DashboardScreen(onOpenOrders: () {
            if (mounted) setState(() => _tab = 2);
          }),
          const ManagerMessagesScreen(hideBottomNav: true),
          const OrderDashboardScreen(),
          const OrderCalendarScreen(),
        ];

        // Ensure _tab is within bounds if tabs change
        if (_tab >= pages.length) {
          _tab = pages.length - 1;
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: (_tab == 0 || _tab == 1)
              ? null
              : AppBar(
                  backgroundColor: bg,
                  elevation: 0,
                  leading: _tab == 2
                      ? null
                      : IconButton(
                          icon: const Icon(LucideIcons.arrowLeft),
                          onPressed: () => setState(() => _tab = 2),
                        ),
                  title: Text(
                    currentTabs[_tab].label,
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  actions: [
                    if (_isDirector)
                      PopupMenuButton<String>(
                        icon: const Icon(LucideIcons.settings),
                        color: isDark
                            ? SfColors.darkBgSurface
                            : SfColors.lightBgSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        itemBuilder: (_) => [
                          _menuItem('categories', LucideIcons.tag, 'Catégories'),
                        ],
                        onSelected: (val) => _navigateAdmin(context, val),
                      ),
                  ],
                ),
          body: Column(
            children: [
              if ((orderProvider.currentDeptId?.isEmpty ?? true) &&
                  !_isDirector &&
                  _tab > 0)
                _deptWarningBanner(isDark),
              Expanded(child: pages[_tab]),
            ],
          ),
          bottomNavigationBar: _BottomNav(
            currentIndex: _tab,
            tabs: currentTabs,
            onTap: (i) => setState(() => _tab = i),
            isDark: isDark,
          ),
          floatingActionButton: _isDirector && _tab > 2
              ? FloatingActionButton(
                  onPressed: () => _navigateAdmin(context, 'categories'),
                  backgroundColor: SfColors.gold,
                  foregroundColor: Colors.black,
                  mini: true,
                  child: const Icon(LucideIcons.settings, size: 18),
                )
              : null,
        );
      },
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: SfColors.gold),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(fontSize: 14)),
        ],
      ),
    );
  }

  void _navigateAdmin(BuildContext context, String type) {
    if (type == 'references' || type == 'stock') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComingSoonScreen(
            title: type == 'references' ? 'Les références' : 'Le stock',
          ),
        ),
      );
      return;
    }

    Widget screen;
    switch (type) {
      case 'departments':
        screen = const DepartmentAdminScreen();
        break;
      case 'categories':
        screen = const CategoryAdminScreen();
        break;
      default:
        screen = const UserAdminScreen();
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _deptWarningBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: SfColors.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle,
              size: 16, color: SfColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre compte n\'est pas encore assigné à un département. '
              'Demandez à votre administrateur de vous assigner.',
              style:
                  GoogleFonts.inter(fontSize: 11, color: SfColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
    required this.isDark,
  });

  final int currentIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset > 0 ? 6 : 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xF0111111)
                : const Color(0xF0FFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : SfColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ...List.generate(tabs.length, (i) {
                final selected = i == currentIndex;
                return Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tabs[i].icon,
                          size: 20,
                          color: selected
                              ? (isDark ? SfColors.gold : SfColors.goldDark)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.52),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tabs[i].label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? (isDark ? SfColors.gold : SfColors.goldDark)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.52),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
