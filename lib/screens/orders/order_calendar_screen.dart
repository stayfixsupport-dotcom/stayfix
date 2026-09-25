import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/order_models.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_card.dart';
import 'order_detail_screen.dart';

/// Calendar screen: pick a date, see orders completed on that date.
class OrderCalendarScreen extends StatefulWidget {
  const OrderCalendarScreen({super.key});

  @override
  State<OrderCalendarScreen> createState() => _OrderCalendarScreenState();
}

class _OrderCalendarScreenState extends State<OrderCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  List<OrgOrder> _ordersForDate = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadForDate(_selectedDate);
  }

  Future<void> _loadForDate(DateTime date) async {
    setState(() => _loading = true);
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final orders = await provider.fetchOrdersForDate(date);
    if (mounted) {
      setState(() {
        _ordersForDate = orders;
        _loading = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SfColors.darkBgBase : SfColors.lightBgBase;
    final textPrimary =
        isDark ? SfColors.darkTextPrimary : SfColors.lightTextPrimary;
    final textMuted =
        isDark ? SfColors.darkTextMuted : SfColors.lightTextMuted;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Calendar widget ───────────────────────────────────────
          _CustomCalendar(
            focusedMonth: _focusedMonth,
            selectedDate: _selectedDate,
            isDark: isDark,
            textPrimary: textPrimary,
            textMuted: textMuted,
            onPreviousMonth: _previousMonth,
            onNextMonth: _nextMonth,
            onDateSelected: (date) {
              setState(() => _selectedDate = date);
              _loadForDate(date);
            },
          ),

          // ── Results ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  _formatSelectedDate(_selectedDate),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SfColors.gold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: SfColors.goldMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_ordersForDate.length} ordre${_ordersForDate.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: SfColors.gold,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _ordersForDate.isEmpty
                    ? _emptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _ordersForDate.length,
                        itemBuilder: (context, i) => OrderCard(
                          order: _ordersForDate[i],
                          showDepartment: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailScreen(
                                  order: _ordersForDate[i]),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: SfColors.goldMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(LucideIcons.calendarCheck,
                size: 28, color: SfColors.gold),
          ),
          const SizedBox(height: 14),
          Text(
            'Aucune intervention ce jour',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? SfColors.darkTextPrimary
                  : SfColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sélectionnez une autre date.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark
                  ? SfColors.darkTextMuted
                  : SfColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSelectedDate(DateTime dt) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Custom Calendar ────────────────────────────────────────────────────────────

class _CustomCalendar extends StatelessWidget {
  const _CustomCalendar({
    required this.focusedMonth,
    required this.selectedDate,
    required this.isDark,
    required this.textPrimary,
    required this.textMuted,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final bool isDark;
  final Color textPrimary;
  final Color textMuted;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;

  static const _dayNames = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static const _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  @override
  Widget build(BuildContext context) {
    final cardBg =
        isDark ? SfColors.darkBgCard : SfColors.lightBgCard;
    final border =
        isDark ? SfColors.darkBorder : SfColors.lightBorder;

    final firstDay =
        DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    // Monday = 0 offset
    final startWeekday = (firstDay.weekday - 1) % 7;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        children: [
          // Month header
          Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.arrowLeft,
                    size: 18, color: SfColors.gold),
                onPressed: onPreviousMonth,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[focusedMonth.month - 1]} ${focusedMonth.year}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.chevronRight,
                    size: 18, color: SfColors.gold),
                onPressed: onNextMonth,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Day names
          Row(
            children: _dayNames
                .map((d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SfColors.gold,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final day = index - startWeekday + 1;
              final date = DateTime(
                  focusedMonth.year, focusedMonth.month, day);
              final isSelected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

              return GestureDetector(
                onTap: () => onDateSelected(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? SfColors.gold
                        : isToday
                            ? SfColors.goldMuted
                            : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.black
                            : isToday
                                ? SfColors.gold
                                : textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
