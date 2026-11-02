import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/analytics_model.dart';
import '../../models/dashboard_range.dart';
import '../../utils/money.dart';
import '../money_flow_card.dart';
import 'dashboard_section.dart';

/// The spending figure for the chosen period, how it splits between bank and cash, and how it compares
/// with all the money that moved through the account.
class SpendingOverviewSection extends StatelessWidget {
  final AnalyticsSummaryModel summary;
  final DashboardRange range;
  final ValueChanged<DashboardRange> onRange;

  const SpendingOverviewSection({
    super.key,
    required this.summary,
    required this.range,
    required this.onRange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthlyAverage = summary.averageDailySpend * 30.4375;

    return DashboardSection(
      number: '02',
      title: 'Spending overview',
      subtitle: summary.statementPeriod,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final option in DashboardRange.values)
                ChoiceChip(
                  label: Text(option.label),
                  selected: range == option,
                  showCheckmark: false,
                  onSelected: (_) => onRange(option),
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: range == option ? FontWeight.w700 : FontWeight.w600,
                    color: range == option ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  side: BorderSide(
                    color: range == option ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            rupees(summary.totalSpending),
            style: GoogleFonts.poppins(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Text(
            summary.transfersOut > 0
                ? 'Purchases, bills and fees. Excludes ${rupees(summary.transfersOut)} sent to people.'
                : 'Purchases, bills and fees.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 40,
            runSpacing: 16,
            children: [
              StatFigure(label: 'Bank', value: rupees(summary.bankSpending), size: 20),
              StatFigure(label: 'Cash', value: rupees(summary.cashSpending), size: 20),
              StatFigure(label: 'Average per month', value: rupees(monthlyAverage), size: 20),
              StatFigure(
                label: 'Net cash flow',
                value: rupees(summary.netCashFlow),
                caption: 'Money in minus money out',
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 24),
          MoneyFlowCard(summary: summary, open: true),
        ],
      ),
    );
  }
}
