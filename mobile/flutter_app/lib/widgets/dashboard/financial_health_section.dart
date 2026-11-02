import 'package:flutter/material.dart';

import '../../models/analytics_model.dart';
import '../budget_card.dart';
import 'dashboard_section.dart';

/// Section 01: the budget status for the month, in the open canvas layout. The content is [BudgetCard].
class FinancialHealthSection extends StatelessWidget {
  final AnalyticsSummaryModel summary;
  final VoidCallback onOpenSettings;

  const FinancialHealthSection({super.key, required this.summary, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      number: '01',
      title: 'Financial health',
      trailing: IconButton(
        onPressed: onOpenSettings,
        tooltip: 'Budget & Alerts',
        icon: const Icon(Icons.tune_rounded, size: 20),
      ),
      child: BudgetCard(summary: summary),
    );
  }
}
