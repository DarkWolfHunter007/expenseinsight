import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/category_colors.dart';
import '../models/analytics_model.dart';

class CategoryDonutChart extends StatefulWidget {
  final List<CategorySpendingItem> categories;
  final double totalExpense;

  const CategoryDonutChart({
    super.key,
    required this.categories,
    required this.totalExpense,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.categories.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Text(
          'No category data available',
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black45),
        ),
      );
    }

    final displayCategories = widget.categories.take(6).toList();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 65,
                  sections: List.generate(displayCategories.length, (i) {
                    final item = displayCategories[i];
                    final isTouched = i == touchedIndex;
                    final radius = isTouched ? 28.0 : 20.0;
                    final meta = CategoryColors.getMeta(item.category);

                    return PieChartSectionData(
                      color: meta.color,
                      value: item.amount,
                      title: isTouched ? '${item.percentage.toStringAsFixed(0)}%' : '',
                      radius: radius,
                      titleStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    touchedIndex != -1 && touchedIndex < displayCategories.length
                        ? displayCategories[touchedIndex].category
                        : 'Total Spent',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    touchedIndex != -1 && touchedIndex < displayCategories.length
                        ? currencyFormat.format(displayCategories[touchedIndex].amount)
                        : currencyFormat.format(widget.totalExpense),
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Legend Chips
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: displayCategories.map((item) {
            final meta = CategoryColors.getMeta(item.category);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: meta.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.category} (${item.percentage.toStringAsFixed(0)}%)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
