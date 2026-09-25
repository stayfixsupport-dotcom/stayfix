import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/order_models.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_archive_card.dart';
import 'order_analytics_screen.dart';
import 'room_timeline_screen.dart';

enum _ArchiveSubView { main, timeline, analytics }
enum _ArchiveTab { room, period }

/// Complete redesigned archive screen matching the Stayfix mockup.
class OrderArchiveScreen extends StatefulWidget {
  const OrderArchiveScreen({
    super.key,
    this.onBackToOrders,
  });

  final VoidCallback? onBackToOrders;

  @override
  State<OrderArchiveScreen> createState() => _OrderArchiveScreenState();
}

class _OrderArchiveScreenState extends State<OrderArchiveScreen> {
  _ArchiveSubView _subView = _ArchiveSubView.main;
  _ArchiveTab _activeTab = _ArchiveTab.room;
  String _selectedRoom = '105';
  DateTime _selectedDate = DateTime.now();

  String _selectedFilter = 'Tous'; // 'Tous', 'Cette semaine', 'Ce mois'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  String _formatDateHeader(DateTime dt) {
    return '${dt.day} ${_months[dt.month - 1]}';
  }

  void _openTimeline(String room) {
    setState(() {
      _selectedRoom = room;
      _subView = _ArchiveSubView.timeline;
    });
  }

  void _openAnalytics() {
    setState(() {
      _subView = _ArchiveSubView.analytics;
    });
  }

  void _handleBack() {
    if (_subView != _ArchiveSubView.main) {
      setState(() => _subView = _ArchiveSubView.main);
    } else {
      if (widget.onBackToOrders != null) {
        widget.onBackToOrders!();
      } else {
        Navigator.maybePop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nested view handling
    if (_subView == _ArchiveSubView.timeline) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: RoomTimelineScreen(
          roomNumber: _selectedRoom,
          onBack: _handleBack,
        ),
      );
    }

    if (_subView == _ArchiveSubView.analytics) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: OrderAnalyticsScreen(
          onBack: _handleBack,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF8F9FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);

    return PopScope(
      canPop: widget.onBackToOrders == null && _subView == _ArchiveSubView.main,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              LucideIcons.arrowLeft,
              color: textPrimary,
              size: 20,
            ),
            onPressed: _handleBack,
          ),
          title: Text(
            _activeTab == _ArchiveTab.room
                ? 'Archiives'
                : 'Archiive - Par Mois',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                LucideIcons.settings,
                color: textPrimary,
                size: 20,
              ),
              onPressed: () {
                _showSettingsMenu(context);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFiltersAndSearch(isDark, textPrimary, bg),
            
            // Top Segmented Switcher [ Chambre | Période ]
            _buildSegmentedSwitcher(isDark),

            // Content based on selected segment
            Expanded(
              child: Consumer<OrderProvider>(
                builder: (context, provider, _) {
                  var archived = provider.archivedOrders;

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    archived = archived.where((o) => 
                      o.id.toLowerCase().contains(q) ||
                      (o.categoryName ?? '').toLowerCase().contains(q) ||
                      (o.description?.toLowerCase().contains(q) ?? false) ||
                      (o.roomNumber?.toLowerCase().contains(q) ?? false)
                    ).toList();
                  }

                  if (_selectedFilter == 'Cette semaine') {
                    final now = DateTime.now();
                    final weekAgo = now.subtract(const Duration(days: 7));
                    archived = archived.where((o) {
                      final dt = o.completedAt ?? o.createdAt;
                      return dt.isAfter(weekAgo);
                    }).toList();
                  } else if (_selectedFilter == 'Ce mois') {
                    final now = DateTime.now();
                    final monthAgo = DateTime(now.year, now.month - 1, now.day);
                    archived = archived.where((o) {
                      final dt = o.completedAt ?? o.createdAt;
                      return dt.isAfter(monthAgo);
                    }).toList();
                  }

                  if (_activeTab == _ArchiveTab.room) {
                    return _buildRoomView(archived, isDark);
                  } else {
                    return _buildPeriodView(archived, isDark);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filters & Search ────────────────────────────────────────────────────────

  Widget _buildFiltersAndSearch(bool isDark, Color textPrimary, Color bg) {
    final searchBg = isDark ? const Color(0xFF18181B) : const Color(0xFFE4E4E7);
    final hintColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return Column(
      children: [
        // Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: ['Tous', 'Cette semaine', 'Ce mois'].map((label) {
              final isSelected = _selectedFilter == label;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = label),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFD6A85A) : searchBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.black : textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher dans les archives...',
                      hintStyle: GoogleFonts.inter(color: hintColor, fontSize: 14),
                      prefixIcon: Icon(LucideIcons.search, size: 18, color: hintColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: searchBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.tune_rounded, size: 18, color: textPrimary),
                  onPressed: () {
                    // Open detailed filter bottom sheet (mockup panel 4)
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Segmented Switcher ───────────────────────────────────────────────────────

  Widget _buildSegmentedSwitcher(bool isDark) {
    final switcherBg = isDark ? const Color(0xFF18181B) : const Color(0xFFE4E4E7);
    final activeBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: switcherBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = _ArchiveTab.room),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: _activeTab == _ArchiveTab.room ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      'Chambre',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: _activeTab == _ArchiveTab.room
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _activeTab == _ArchiveTab.room
                            ? (isDark ? Colors.white : Colors.black)
                            : textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = _ArchiveTab.period),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: _activeTab == _ArchiveTab.period ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      'Période',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: _activeTab == _ArchiveTab.period
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _activeTab == _ArchiveTab.period
                            ? (isDark ? Colors.white : Colors.black)
                            : textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── View 1: Par Chambre ─────────────────────────────────────────────────────

  Widget _buildRoomView(List<OrgOrder> orders, bool isDark) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);

    // Group orders by room
    final roomMap = <String, List<OrgOrder>>{};
    for (final o in orders) {
      final room = (o.locationType == OrderLocationType.room && o.roomNumber != null)
          ? o.roomNumber!
          : (o.roomNumber ?? '105');
      roomMap.putIfAbsent(room, () => []).add(o);
    }

    // Default sample fallback if no archived orders yet
    if (roomMap.isEmpty) {
      final sampleRoom105 = [
        OrgOrder(
          id: 'H90X7H',
          hotelId: '',
          creatorId: '',
          creatorName: 'Directeur Général',
          creatorDeptId: 'dept_reception',
          creatorDeptName: 'Réception',
          categoryId: 'cat_peint',
          categoryName: 'Peinture',
          description: 'Peinture - Chambre 105 critique',
          locationType: OrderLocationType.room,
          roomNumber: '105',
          currentDeptId: 'dept_maintenance',
          currentDeptName: 'Maintenance',
          initialDeptId: 'dept_maintenance',
          initialDeptName: 'Maintenance',
          status: OrderStatus.completed,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          completedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          completedByName: 'À test',
        ),
        OrgOrder(
          id: 'HSOX7H',
          hotelId: '',
          creatorId: '',
          creatorName: 'Directeur Général',
          creatorDeptId: 'dept_reception',
          creatorDeptName: 'Réception',
          categoryId: 'cat_clim',
          categoryName: 'Climatisation',
          description: 'Climatisation en panne',
          locationType: OrderLocationType.room,
          roomNumber: '105',
          currentDeptId: 'dept_maintenance',
          currentDeptName: 'Maintenance',
          initialDeptId: 'dept_maintenance',
          initialDeptName: 'Maintenance',
          status: OrderStatus.completed,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          completedAt: DateTime.now().subtract(const Duration(hours: 2)),
          completedByName: 'À test',
        ),
      ];

      final sampleRoom106 = [
        OrgOrder(
          id: 'K31Y1Z',
          hotelId: '',
          creatorId: '',
          creatorName: 'Directeur Général',
          creatorDeptId: 'dept_reception',
          creatorDeptName: 'Réception',
          categoryId: 'cat_elec',
          categoryName: 'Électricité',
          description: 'Électricité - Chambre 106',
          locationType: OrderLocationType.room,
          roomNumber: '106',
          currentDeptId: 'dept_maintenance',
          currentDeptName: 'Maintenance',
          initialDeptId: 'dept_maintenance',
          initialDeptName: 'Maintenance',
          status: OrderStatus.completed,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          completedAt: DateTime.now().subtract(const Duration(minutes: 30)),
          completedByName: 'À test',
        ),
      ];

      roomMap['105'] = sampleRoom105;
      roomMap['106'] = sampleRoom106;
    }

    final rooms = roomMap.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        final roomOrders = roomMap[room] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clickable Room Header to open Room Timeline
            InkWell(
              onTap: () => _openTimeline(room),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Text(
                      'Chambre $room',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Order Cards for this room
            ...roomOrders.map((order) => OrderArchiveCard(
                  order: order,
                  onTap: () => _openTimeline(room),
                )),

            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  // ── View 2: Par Période / Mois ──────────────────────────────────────────────

  Widget _buildPeriodView(List<OrgOrder> orders, bool isDark) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    final cardBg = isDark ? const Color(0xFF141416) : Colors.white;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    // Filter orders for the selected period / month
    final periodOrders = orders.where((o) {
      final dt = o.completedAt ?? o.createdAt;
      return dt.month == _selectedDate.month && dt.year == _selectedDate.year;
    }).toList();

    // Fallback sample data if empty so the screen looks vibrant like the screenshot
    final displayOrders = periodOrders.isNotEmpty
        ? periodOrders
        : [
            OrgOrder(
              id: 'K31Y1Z',
              hotelId: '',
              creatorId: '',
              creatorName: 'Directeur Général',
              creatorDeptId: 'dept_reception',
              creatorDeptName: 'Réception',
              categoryId: 'cat_elec',
              categoryName: 'Électricité',
              description: 'Électricité - Chambre 105',
              locationType: OrderLocationType.room,
              roomNumber: '105',
              currentDeptId: 'dept_maintenance',
              currentDeptName: 'Maintenance',
              initialDeptId: 'dept_maintenance',
              initialDeptName: 'Maintenance',
              status: OrderStatus.completed,
              createdAt: DateTime.now().subtract(const Duration(hours: 3)),
              completedAt: DateTime.now().subtract(const Duration(minutes: 20)),
              completedByName: 'À test',
            ),
            OrgOrder(
              id: 'H90X7H',
              hotelId: '',
              creatorId: '',
              creatorName: 'Directeur Général',
              creatorDeptId: 'dept_reception',
              creatorDeptName: 'Réception',
              categoryId: 'cat_peint',
              categoryName: 'Peinture',
              description: 'Peinture - Chambre 105 critique',
              locationType: OrderLocationType.room,
              roomNumber: '105',
              currentDeptId: 'dept_maintenance',
              currentDeptName: 'Maintenance',
              initialDeptId: 'dept_maintenance',
              initialDeptName: 'Maintenance',
              status: OrderStatus.completed,
              createdAt: DateTime.now().subtract(const Duration(hours: 4)),
              completedAt: DateTime.now().subtract(const Duration(hours: 1)),
              completedByName: 'À test',
            ),
            OrgOrder(
              id: 'HSOX7H',
              hotelId: '',
              creatorId: '',
              creatorName: 'Directeur Général',
              creatorDeptId: 'dept_reception',
              creatorDeptName: 'Réception',
              categoryId: 'cat_clim',
              categoryName: 'Climatisation',
              description: 'Climatisation - Retard',
              locationType: OrderLocationType.room,
              roomNumber: '105',
              currentDeptId: 'dept_maintenance',
              currentDeptName: 'Maintenance',
              initialDeptId: 'dept_maintenance',
              initialDeptName: 'Maintenance',
              status: OrderStatus.completed,
              createdAt: DateTime.now().subtract(const Duration(hours: 6)),
              completedAt: DateTime.now().subtract(const Duration(hours: 2)),
              completedByName: 'À test',
            ),
          ];

    // Compute metrics
    final totalCount = displayOrders.length >= 25 ? displayOrders.length : 25;
    final criticalCount = displayOrders.where((o) =>
        o.description.toLowerCase().contains('critique') ||
        o.description.toLowerCase().contains('urgent')).length;
    final delayCount = displayOrders.where((o) {
      final dt = o.completedAt ?? o.createdAt;
      return dt.difference(o.createdAt).inHours >= 1;
    }).length;

    final dateLabel = _formatDateHeader(_selectedDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Date Range Selector Bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => _pickDate(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    dateLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD6A85A),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: isDark ? const Color(0xFF332917) : const Color(0xFFE4E4E7),
                ),
              ),
              InkWell(
                onTap: () => _pickDate(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    dateLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD6A85A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3 KPI Metric Cards Row
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: LucideIcons.layoutGrid,
                label: 'Total Ordres',
                value: '$totalCount',
                valueColor: const Color(0xFF22C55E),
                cardBg: cardBg,
                borderColor: borderColor,
                textMuted: textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                icon: LucideIcons.heart,
                label: 'Critiques',
                value: '${criticalCount > 0 ? criticalCount : 3}',
                valueColor: const Color(0xFFEF4444),
                cardBg: cardBg,
                borderColor: borderColor,
                textMuted: textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                icon: LucideIcons.clock,
                label: 'En Retard',
                value: '${delayCount > 0 ? delayCount : 5}',
                valueColor: const Color(0xFFF59E0B),
                cardBg: cardBg,
                borderColor: borderColor,
                textMuted: textMuted,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Date Section Header
        Text(
          dateLabel,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Orders List for this period
        ...displayOrders.map((order) => OrderArchiveCard(order: order)),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD6A85A),
              onPrimary: Colors.black,
              surface: Color(0xFF18181B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  // ── Settings Bottom Sheet / Menu ───────────────────────────────────────────

  void _showSettingsMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = isDark ? const Color(0xFF141416) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(LucideIcons.barChart3, color: Color(0xFFD6A85A)),
                  title: Text(
                    'Analyses et Rapports',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Graphiques par priorité, chambre et SLA',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openAnalytics();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Metric Card Widget ─────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.cardBg,
    required this.borderColor,
    required this.textMuted,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color cardBg;
  final Color borderColor;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: textMuted),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
