import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/analytics_model.dart';
import '../../utils/money.dart';
import 'dashboard_section.dart';

/// Month by month: money in, money out and spending, with a dashed line for the forecast of next month.
/// The legend entries switch a line on or off. Each month's figures are in the tooltip.
class SpendingTrendSection extends StatefulWidget {
  final List<MonthlySpendingItem> months;

  /// Next month's forecast, or null when there is not enough history for a forecast.
  final double? forecastNext;

  const SpendingTrendSection({super.key, required this.months, this.forecastNext});

  @override
  State<SpendingTrendSection> createState() => _SpendingTrendSectionState();
}

class _SpendingTrendSectionState extends State<SpendingTrendSection> {
  static const _series = [
    ('Money in', Color(0xFF10B981)),
    ('Money out', Color(0xFFEF4444)),
    ('Spending', Color(0xFF3B82F6)),
  ];
  static const _forecastColor = Color(0xFF8B5CF6);
  static const _monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  final Set<String> _visible = {'Money in', 'Money out', 'Spending'};

  double _value(MonthlySpendingItem m, String name) {
    switch (name) {
      case 'Money in':
        return m.moneyIn;
      case 'Money out':
        return m.moneyOut;
      default:
        return m.totalExpense;
    }
  }

  static String _compact(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(v >= 1000000 ? 0 : 1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _monthLabel(String yearMonth, {required bool withYear}) {
    final parts = yearMonth.split('-');
    final month = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    final name = _monthNames[month.clamp(1, 12)];
    return withYear && parts.isNotEmpty ? "$name '${parts[0].length >= 4 ? parts[0].substring(2) : parts[0]}" : name;
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    return DashboardSection(
      number: '03',
      title: 'Spending trends',
      subtitle: 'Month by month, from your statements',
      child: months.isEmpty
          ? Text('No monthly data yet.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_legend(), const SizedBox(height: 14), SizedBox(height: 260, child: _chart(context))],
            ),
    );
  }

  Widget _legend() {
    final hasForecast = widget.forecastNext != null;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (name, color) in _series)
          Semantics(
            button: true,
            toggled: _visible.contains(name),
            label: '$name line, ${_visible.contains(name) ? 'shown' : 'hidden'}',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _visible.contains(name) ? _visible.remove(name) : _visible.add(name)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _visible.contains(name) ? color : Colors.transparent,
                        border: Border.all(color: color, width: 2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _visible.contains(name) ? null : Colors.grey[500],
                        )),
                  ],
                ),
              ),
            ),
          ),
        if (hasForecast)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              SizedBox(
                width: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 3; i++) Container(width: 3, height: 2, color: _forecastColor),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text('Forecast', style: GoogleFonts.inter(fontSize: 12)),
            ],
          ),
      ],
    );
  }

  Widget _chart(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final months = widget.months;
    final forecast = widget.forecastNext;
    final showForecast = forecast != null && _visible.contains('Spending');
    final lastIndex = months.length - 1;
    final withYear = months.map((m) => m.month.split('-').first).toSet().length > 1;

    final bars = <LineChartBarData>[];
    final barNames = <String>[];
    var peak = 0.0;

    for (final (name, color) in _series) {
      if (!_visible.contains(name)) continue;
      final spots = [for (var i = 0; i < months.length; i++) FlSpot(i.toDouble(), _value(months[i], name))];
      for (final s in spots) {
        if (s.y > peak) peak = s.y;
      }
      barNames.add(name);
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: color,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) =>
              FlDotCirclePainter(radius: 3.5, color: color, strokeWidth: 1.5, strokeColor: Colors.white),
        ),
      ));
    }
    if (showForecast) {
      barNames.add('Forecast');
      if (forecast > peak) peak = forecast;
      bars.add(LineChartBarData(
        spots: [FlSpot(lastIndex.toDouble(), months[lastIndex].totalExpense), FlSpot(months.length.toDouble(), forecast)],
        isCurved: false,
        color: _forecastColor,
        barWidth: 2.5,
        dashArray: [6, 5],
        dotData: FlDotData(
          show: true,
          checkToShowDot: (spot, bar) => spot.x == months.length.toDouble(),
          getDotPainter: (spot, percent, bar, index) =>
              FlDotCirclePainter(radius: 4, color: _forecastColor, strokeWidth: 1.5, strokeColor: Colors.white),
        ),
      ));
    }

    final maxY = peak <= 0 ? 1000.0 : peak * 1.18;
    final points = months.length + (showForecast ? 1 : 0);

    return LineChart(
      LineChartData(
        minX: -0.3,
        maxX: points - 1 + 0.3,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Text(
                _compact(value),
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if ((value - index).abs() > 0.01 || index < 0 || index >= points) return const SizedBox.shrink();
                final label = index < months.length ? _monthLabel(months[index].month, withYear: withYear) : 'Next';
                return SideTitleWidget(
                  meta: meta,
                  child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) {
              return touched.map((spot) {
                final name = spot.barIndex < barNames.length ? barNames[spot.barIndex] : '';
                final month = spot.x.round() < months.length ? months[spot.x.round()].monthName : 'Next month (forecast)';
                return LineTooltipItem(
                  '$name  ${rupees(spot.y)}\n',
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: spot.bar.color ?? Colors.white),
                  children: [TextSpan(text: month, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70))],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: bars,
      ),
    );
  }
}
