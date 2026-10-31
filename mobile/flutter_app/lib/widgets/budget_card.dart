import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analytics_model.dart';

/// Monthly budget indicator. Can be closed; stays closed for that month and status,
/// and reappears when the status worsens (e.g. warning -> exceeded) or a new month starts.
class BudgetCard extends StatefulWidget {
  final AnalyticsSummaryModel summary;

  const BudgetCard({super.key, required this.summary});

  @override
  State<BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<BudgetCard> {
  static const _prefsKey = 'budget_card_dismissed';

  String? _dismissedKey;

  String get _currentKey => '${widget.summary.budgetMonth}|${widget.summary.budgetStatus}';

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (mounted && stored != null) setState(() => _dismissedKey = stored);
    } catch (_) {
      // Dismissal is a convenience; the card simply shows if storage is unavailable.
    }
  }

  Future<void> _dismiss() async {
    final key = _currentKey;
    setState(() => _dismissedKey = key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, key);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    if (summary.budgetStatus == 'none' || _dismissedKey == _currentKey) {
      return const SizedBox.shrink();
    }

    final status = summary.budgetStatus;
    final Color accent;
    final Color fill;
    final IconData icon;
    final String title;
    final spent = summary.budgetSpent.toStringAsFixed(0);
    final budget = summary.monthlyBudget.toStringAsFixed(0);
    final String subtitle;

    if (status == 'exceeded') {
      accent = const Color(0xFFEF4444);
      fill = const Color(0xFF7F1D1D);
      icon = Icons.warning_amber_rounded;
      title = "You've exceeded this month's budget";
      subtitle = '₹$spent spent of ₹$budget, over by ₹${(-summary.budgetRemaining).toStringAsFixed(0)}';
    } else if (status == 'warning') {
      accent = const Color(0xFFF59E0B);
      fill = const Color(0xFF78350F);
      icon = Icons.error_outline_rounded;
      title = "Close to this month's budget (${summary.budgetUsedPct.toStringAsFixed(0)}%)";
      subtitle = '₹$spent spent of ₹$budget, ₹${summary.budgetRemaining.toStringAsFixed(0)} left';
    } else {
      accent = const Color(0xFF10B981);
      fill = const Color(0xFF064E3B);
      icon = Icons.check_circle_outline_rounded;
      title = 'On track this month';
      subtitle = '₹$spent spent of ₹$budget, ₹${summary.budgetRemaining.toStringAsFixed(0)} left';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: fill.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: accent),
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 8),
            child: Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (summary.budgetUsedPct / 100).clamp(0.0, 1.0),
                minHeight: 8,
                color: accent,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'Budget = your average monthly spending from the uploaded statement',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
