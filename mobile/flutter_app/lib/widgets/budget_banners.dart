import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/analytics_model.dart';
import 'dismissible_banner.dart';

String _money(double value) => '₹${value.abs().toStringAsFixed(0)}';

Widget _bannerShell({
  required Color accent,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback close,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.45)),
    ),
    child: Row(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
        IconButton(
          onPressed: close,
          tooltip: 'Dismiss',
          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white60),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );
}

/// "You can spend about X today": a daily allowance banner, not a notification. Closing hides it for today.
class SafeToSpendBanner extends StatelessWidget {
  final AnalyticsSummaryModel summary;
  final DateTime? today;

  const SafeToSpendBanner({super.key, required this.summary, this.today});

  @override
  Widget build(BuildContext context) {
    if (summary.budgetStatus == 'none') return const SizedBox.shrink();
    final day = DateFormat('yyyy-MM-dd').format(today ?? DateTime.now());
    final exceeded = summary.budgetStatus == 'exceeded';

    return DismissibleBanner(
      prefsKey: 'safe_to_spend_dismissed',
      dismissedValue: day,
      builder: (context, close) => _bannerShell(
        accent: exceeded ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
        icon: exceeded ? Icons.block_rounded : Icons.today_rounded,
        title: exceeded
            ? 'No room left in this month\'s budget'
            : 'You can spend about ${_money(summary.safeToSpendToday)} today',
        subtitle: exceeded
            ? 'Anything you spend now adds to the overspend.'
            : 'To stay within budget, with ${summary.daysLeftInMonth} day${summary.daysLeftInMonth == 1 ? '' : 's'} left this month.',
        close: close,
      ),
    );
  }
}

/// Month-end wrap-up shown in the first days of a new month. Closing hides it for that month.
class MonthRecapBanner extends StatelessWidget {
  final LastMonthRecap? recap;

  const MonthRecapBanner({super.key, required this.recap});

  @override
  Widget build(BuildContext context) {
    final r = recap;
    if (r == null) return const SizedBox.shrink();

    final parsed = DateTime.tryParse('${r.month}-01');
    final monthName = parsed != null ? DateFormat('MMMM').format(parsed) : r.month;
    final under = r.underBudget;

    return DismissibleBanner(
      prefsKey: 'month_recap_dismissed',
      dismissedValue: r.month,
      builder: (context, close) => _bannerShell(
        accent: under ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        icon: under ? Icons.celebration_rounded : Icons.trending_up_rounded,
        title: under
            ? '$monthName closed ${_money(r.difference)} under budget'
            : '$monthName closed ${_money(r.difference)} over budget',
        subtitle: 'You spent ${_money(r.spent)} of ${_money(r.budget)}. A fresh budget starts this month.',
        close: close,
      ),
    );
  }
}
