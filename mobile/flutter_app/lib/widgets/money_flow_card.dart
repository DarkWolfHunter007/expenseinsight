import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/analytics_model.dart';

/// Everything the bank statement shows leaving and entering the account, split into what counts as
/// spending and what does not. The totals match the PDF's own "total withdrawals" and "total
/// deposits", so they can be checked against the statement.
class MoneyFlowCard extends StatelessWidget {
  final AnalyticsSummaryModel summary;

  const MoneyFlowCard({super.key, required this.summary});

  static final _money = NumberFormat.decimalPattern('en_IN');

  static String format(double value) => '₹${_money.format(value.round())}';

  @override
  Widget build(BuildContext context) {
    if (summary.bankMoneyOut <= 0 && summary.bankMoneyIn <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherIn = (summary.bankMoneyIn - summary.transfersIn).clamp(0.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MONEY IN AND OUT (BANK)',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.9, color: Colors.grey[500]),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 28,
              runSpacing: 14,
              children: [
                _side(
                  label: 'Money out',
                  total: summary.bankMoneyOut,
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                  parts: [
                    ('Purchases and bills', summary.bankSpending),
                    ('Transfers to people', summary.transfersOut),
                    ('Other (cash withdrawals etc.)', summary.otherMoneyOut),
                  ],
                ),
                _side(
                  label: 'Money in',
                  total: summary.bankMoneyIn,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  parts: [
                    ('Transfers from people', summary.transfersIn),
                    ('Salary, refunds and other', otherIn),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'These add up to the withdrawals and deposits in your statement. Payments to and from people are '
              'shown as transfers and are not counted as spending.',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _side({
    required String label,
    required double total,
    required Color color,
    required bool isDark,
    required List<(String, double)> parts,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400])),
          const SizedBox(height: 2),
          Text(
            format(total),
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          for (final (name, amount) in parts)
            if (amount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 12))),
                    Text(format(amount), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
