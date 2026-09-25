import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/order_models.dart';
import '../../providers/order_provider.dart';

/// Screen displaying interactive analytics and reports for hotel orders.
class OrderAnalyticsScreen extends StatelessWidget {
  const OrderAnalyticsScreen({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF8F9FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);

    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        final archived = provider.archivedOrders;
        final allOrders = [...provider.activeOrders, ...archived];

        return Scaffold(
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
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Analyses et Rapports',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // 1. Ordres par Priorité (Pie/Donut Chart)
              _AnalyticsCard(
                title: 'Ordres par Priorité',
                child: _PriorityPieChartSection(orders: allOrders, isDark: isDark),
              ),

              const SizedBox(height: 16),

              // 2. Ordres par Chambre (Horizontal Bar Chart)
              _AnalyticsCard(
                title: 'Ordres par Chambre',
                child: _RoomHorizontalBarChart(orders: allOrders, isDark: isDark),
              ),

              const SizedBox(height: 16),

              // 3. Consommation d'actifs (Vertical Bar Chart)
              _AnalyticsCard(
                title: "Consommation d'actifs",
                child: _AssetsVerticalBarChart(orders: allOrders, isDark: isDark),
              ),

              const SizedBox(height: 16),

              // 4. Temps d'exécution Moyen (Line Chart)
              _AnalyticsCard(
                title: "Temps d'exécution Moyen",
                child: _ExecutionTimeLineChart(orders: archived, isDark: isDark),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Card Container ─────────────────────────────────────────────────────────────

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141416) : Colors.white;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── 1. Priority Pie/Donut Chart ────────────────────────────────────────────────

class _PriorityPieChartSection extends StatelessWidget {
  const _PriorityPieChartSection({
    required this.orders,
    required this.isDark,
  });

  final List<OrgOrder> orders;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    // Calculate real proportions or sample defaults if empty
    int critical = orders.where((o) =>
        o.description.toLowerCase().contains('urgent') ||
        o.description.toLowerCase().contains('critique')).length;
    int high = orders.where((o) => (o.categoryName ?? '').toLowerCase().contains('électr')).length;
    int normal = orders.length - (critical + high);

    if (orders.isEmpty) {
      critical = 3;
      high = 5;
      normal = 12;
    } else if (normal <= 0) {
      normal = 1;
    }

    final total = (critical + high + normal).toDouble();
    final pNormal = normal / total;
    final pHigh = high / total;
    final pCritical = critical / total;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut / Pie
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutChartPainter(
              proportions: [pNormal, pHigh, pCritical],
              colors: const [
                Color(0xFFD6A85A), // Priorité (Gold)
                Color(0xFF22C55E), // Haute (Green)
                Color(0xFFEF4444), // Consommers / Critique (Red)
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendItem(const Color(0xFFD6A85A), 'Priorité', textMuted),
              const SizedBox(height: 8),
              _legendItem(const Color(0xFF22C55E), 'Haute', textMuted),
              const SizedBox(height: 8),
              _legendItem(const Color(0xFFEF4444), 'Consommers', textMuted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label, Color textMuted) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.proportions,
    required this.colors,
  });

  final List<double> proportions;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;
    for (int i = 0; i < proportions.length; i++) {
      final sweepAngle = proportions[i] * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

// ── 2. Room Horizontal Bar Chart ───────────────────────────────────────────────

class _RoomHorizontalBarChart extends StatelessWidget {
  const _RoomHorizontalBarChart({
    required this.orders,
    required this.isDark,
  });

  final List<OrgOrder> orders;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    // Group orders by room
    final roomCounts = <String, int>{};
    for (final o in orders) {
      if (o.locationType == OrderLocationType.room && o.roomNumber != null) {
        final key = 'Chambre ${o.roomNumber}';
        roomCounts[key] = (roomCounts[key] ?? 0) + 1;
      }
    }

    if (roomCounts.isEmpty) {
      roomCounts['Chambre 105'] = 160;
      roomCounts['Chambre 106'] = 65;
    }

    final topRooms = roomCounts.entries.take(3).toList();
    const maxVal = 180.0;

    return Column(
      children: [
        ...topRooms.map((entry) {
          final ratio = (entry.value / maxVal).clamp(0.05, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    entry.key,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F3F5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            width: constraints.maxWidth * ratio,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8C27A),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 8),

        // X-Axis scale
        Padding(
          padding: const EdgeInsets.only(left: 88),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final val in ['0', '30', '60', '90', '120', '150', '180'])
                Text(
                  val,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 3. Assets Vertical Bar Chart ───────────────────────────────────────────────

class _AssetsVerticalBarChart extends StatelessWidget {
  const _AssetsVerticalBarChart({
    required this.orders,
    required this.isDark,
  });

  final List<OrgOrder> orders;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    final items = [
      {'label': 'Peinture', 'value': 17},
      {'label': 'Ampoules', 'value': 9},
      {'label': 'Ampoules', 'value': 8},
      {'label': 'Other', 'value': 5},
    ];

    const maxY = 20.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Y-axis labels
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final val in ['20', '15', '10', '5', '0'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.5),
                child: Text(
                  val,
                  style: GoogleFonts.inter(fontSize: 10, color: textMuted),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),

        // Bars Container
        Expanded(
          child: SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((item) {
                final val = (item['value'] as int).toDouble();
                final heightFactor = (val / maxY).clamp(0.05, 1.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 28,
                      height: 90 * heightFactor,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8C27A),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['label'] as String,
                      style: GoogleFonts.inter(fontSize: 10, color: textMuted),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 4. Execution Time Line Chart ───────────────────────────────────────────────

class _ExecutionTimeLineChart extends StatelessWidget {
  const _ExecutionTimeLineChart({
    required this.orders,
    required this.isDark,
  });

  final List<OrgOrder> orders;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Y-axis
        SizedBox(
          width: 24,
          height: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final val in ['120', '80', '60'])
                Text(
                  val,
                  style: GoogleFonts.inter(fontSize: 10, color: textMuted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Line Chart Area
        Expanded(
          child: SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _SplineLineChartPainter(isDark: isDark),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplineLineChartPainter extends CustomPainter {
  final bool isDark;
  _SplineLineChartPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Points matching the wave in the mockup
    final points = [
      Offset(0, size.height * 0.9),
      Offset(size.width * 0.25, size.height * 0.65),
      Offset(size.width * 0.45, size.height * 0.8),
      Offset(size.width * 0.70, size.height * 0.35),
      Offset(size.width * 0.85, size.height * 0.75),
      Offset(size.width, size.height * 0.60),
    ];

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Gradient fill under the line
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFD6A85A).withValues(alpha: 0.35),
          const Color(0xFFD6A85A).withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final strokePaint = Paint()
      ..color = const Color(0xFFE8C27A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SplineLineChartPainter oldDelegate) => false;
}
