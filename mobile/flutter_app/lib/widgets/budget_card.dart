import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/analytics_model.dart';
import '../services/api_service.dart';
import '../utils/money.dart';
import 'dashboard/budget_tier.dart';
import 'dashboard/dashboard_section.dart';
import 'dismissible_banner.dart';

/// The month's budget in one open block: the status (which changes at warning, critical and exceeded),
/// the budget, what is spent and left, the day's safe-to-spend allowance and last month's recap.
///
/// It replaces the three stacked banners. The allowance can be hidden for the day and the recap for the
/// month, but hiding them never touches the budget figures. Dismissals are saved per account, so they
/// cannot carry over to a different session on the same browser.
class BudgetCard extends StatelessWidget {
  final AnalyticsSummaryModel summary;

  /// Scopes the saved dismissals (defaults to the signed-in account).
  final String? userKey;

  /// Overrides today's date (for tests).
  final DateTime? today;

  const BudgetCard({super.key, required this.summary, this.userKey, this.today});

  String get _scope => userKey ?? ApiService().userId ?? 'anonymous';

  static String monthName(String? yearMonth) {
    final parsed = DateTime.tryParse('${yearMonth ?? ''}-01');
    return parsed == null ? (yearMonth ?? '') : DateFormat('MMMM yyyy').format(parsed);
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'exceeded':
        return 'Over budget';
      case 'critical':
        return 'Almost at the limit';
      case 'warning':
        return 'Close to the limit';
      default:
        return 'On track';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s.budgetStatus == 'none') {
      return Text(
        'No budget yet. Upload a statement to get one automatically, or set your own limit in Budget & Alerts.',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
      );
    }

    final tier = BudgetTier.of(s.budgetStatus);
    final over = s.budgetRemaining < 0;
    final day = DateFormat('yyyy-MM-dd').format(today ?? DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(tier.icon, color: tier.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              statusLabel(s.budgetStatus),
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: tier.accent),
            ),
            const SizedBox(width: 10),
            Text(monthName(s.budgetMonth), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 44,
          runSpacing: 20,
          children: [
            StatFigure(
              label: 'Monthly budget',
              value: rupees(s.monthlyBudget),
              caption: s.budgetMode == 'manual' ? 'Set by you' : 'From your statement',
            ),
            StatFigure(
              label: 'Spent this month',
              value: rupees(s.budgetSpent),
              caption: '${s.budgetUsedPct.toStringAsFixed(0)}% of the budget',
            ),
            StatFigure(
              label: over ? 'Over budget by' : 'Remaining',
              value: rupees(s.budgetRemaining.abs()),
              valueColor: over ? tier.accent : null,
              caption: over ? 'Nothing left to spend' : '${(100 - s.budgetUsedPct).clamp(0, 100).toStringAsFixed(0)}% left',
            ),
            DismissibleBanner(
              prefsKey: 'safe_to_spend_dismissed_$_scope',
              dismissedValue: day,
              spacing: 0,
              builder: (context, close) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatFigure(
                    label: 'Safe to spend today',
                    value: rupees(s.safeToSpendToday),
                    caption: over
                        ? 'No room left this month'
                        : '${s.daysLeftInMonth} day${s.daysLeftInMonth == 1 ? '' : 's'} left this month',
                  ),
                  IconButton(
                    onPressed: close,
                    tooltip: "Hide today's allowance",
                    visualDensity: VisualDensity.compact,
                    iconSize: 15,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (s.lastMonthSpent > 0)
              StatFigure(label: 'Last month', value: rupees(s.lastMonthSpent), caption: s.lastMonthLabel),
          ],
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (s.budgetUsedPct / 100).clamp(0.0, 1.0),
              minHeight: 6,
              color: tier.accent,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
        if (s.lastMonthRecap != null) _recap(s.lastMonthRecap!),
        ..._flaggedCategories(),
      ],
    );
  }

  Widget _recap(LastMonthRecap recap) {
    final color = recap.underBudget ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return DismissibleBanner(
      prefsKey: 'month_recap_dismissed_$_scope',
      dismissedValue: recap.month,
      spacing: 0,
      builder: (context, close) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${monthName(recap.month)} closed ${rupees(recap.difference.abs())} '
                '${recap.underBudget ? 'under' : 'over'} budget (${rupees(recap.spent)} of ${rupees(recap.budget)}).',
                style: GoogleFonts.inter(fontSize: 12, color: color),
              ),
            ),
            IconButton(
              onPressed: close,
              tooltip: "Hide last month's summary",
              visualDensity: VisualDensity.compact,
              iconSize: 15,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _flaggedCategories() {
    final flagged = summary.categoryBudgets.where((c) => c.status != 'on_track').take(4).toList();
    if (flagged.isEmpty) return const [];
    return [
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final c in flagged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: BudgetTier.of(c.status).accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BudgetTier.of(c.status).accent.withValues(alpha: 0.5)),
              ),
              child: Text(
                '${c.category} ${c.usedPct.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BudgetTier.of(c.status).accent),
              ),
            ),
        ],
      ),
    ];
  }
}
