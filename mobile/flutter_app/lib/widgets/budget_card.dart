import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/analytics_model.dart';
import '../screens/budget_settings_screen.dart';
import 'dismissible_banner.dart';

/// Colors and wording for each budget tier.
class BudgetTier {
  final Color accent;
  final Color fill;
  final IconData icon;

  const BudgetTier(this.accent, this.fill, this.icon);

  static BudgetTier of(String status) {
    switch (status) {
      case 'exceeded':
        return const BudgetTier(Color(0xFFEF4444), Color(0xFF7F1D1D), Icons.warning_amber_rounded);
      case 'critical':
        return const BudgetTier(Color(0xFFF97316), Color(0xFF7C2D12), Icons.priority_high_rounded);
      case 'warning':
        return const BudgetTier(Color(0xFFF59E0B), Color(0xFF78350F), Icons.error_outline_rounded);
      default:
        return const BudgetTier(Color(0xFF10B981), Color(0xFF064E3B), Icons.check_circle_outline_rounded);
    }
  }
}

/// Monthly budget indicator. Can be closed; stays closed for that month and status, and reappears
/// when the status worsens (e.g. warning -> critical -> exceeded) or a new month starts.
class BudgetCard extends StatelessWidget {
  final AnalyticsSummaryModel summary;

  const BudgetCard({super.key, required this.summary});

  static String _money(double value) => '₹${value.abs().toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    if (summary.budgetStatus == 'none') return const SizedBox.shrink();

    return DismissibleBanner(
      prefsKey: 'budget_card_dismissed',
      dismissedValue: '${summary.budgetMonth}|${summary.budgetStatus}',
      builder: (context, close) => _content(context, close),
    );
  }

  Widget _content(BuildContext context, VoidCallback close) {
    final status = summary.budgetStatus;
    final tier = BudgetTier.of(status);
    final spent = _money(summary.budgetSpent);
    final budget = _money(summary.monthlyBudget);
    final left = _money(summary.budgetRemaining);
    final pct = summary.budgetUsedPct.toStringAsFixed(0);

    final String title;
    final String subtitle;
    switch (status) {
      case 'exceeded':
        title = "You've exceeded this month's budget";
        subtitle = '$spent spent of $budget, over by $left';
      case 'critical':
        title = "Only $left left this month ($pct% used)";
        subtitle = '$spent spent of $budget, ${summary.daysLeftInMonth} days to go';
      case 'warning':
        title = "Close to this month's budget ($pct%)";
        subtitle = '$spent spent of $budget, $left left';
      default:
        title = 'On track this month';
        subtitle = '$spent spent of $budget, $left left';
    }

    final flagged = summary.categoryBudgets.where((c) => c.status != 'on_track').take(4).toList();
    final basis = summary.budgetMode == 'manual'
        ? 'Budget = the limits you set in Budget & Alerts'
        : 'Budget = your average monthly spending from the uploaded statement';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: tier.fill.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tier.accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tier.icon, color: tier.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: tier.accent),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetSettingsScreen()),
                ),
                tooltip: 'Budget & Alerts',
                icon: const Icon(Icons.tune_rounded, size: 20, color: Colors.white70),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: close,
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 8),
            child: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (summary.budgetUsedPct / 100).clamp(0.0, 1.0),
                minHeight: 8,
                color: tier.accent,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
          if (flagged.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final c in flagged) _categoryChip(c)],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(basis, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(CategoryBudgetItem item) {
    final tier = BudgetTier.of(item.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tier.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tier.accent.withValues(alpha: 0.5)),
      ),
      child: Text(
        '${item.category} ${item.usedPct.toStringAsFixed(0)}%',
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: tier.accent),
      ),
    );
  }
}
