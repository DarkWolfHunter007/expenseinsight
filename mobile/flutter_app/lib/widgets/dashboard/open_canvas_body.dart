import 'package:flutter/material.dart';

import '../../models/analytics_model.dart';
import '../../models/dashboard_range.dart';
import '../../models/forecast_model.dart';
import '../../models/transaction_model.dart';
import 'category_ranking_section.dart';
import 'dashboard_section.dart';
import 'financial_health_section.dart';
import 'intelligence_section.dart';
import 'review_section.dart';
import 'spending_overview_section.dart';
import 'spending_trend_section.dart';

/// The open-canvas dashboard: numbered sections separated by whitespace and thin rules instead of a stack of
/// bordered cards. Two columns on wide screens, one on narrow ones.
class OpenCanvasBody extends StatelessWidget {
  final AnalyticsSummaryModel summary;
  final DashboardRange range;
  final ValueChanged<DashboardRange> onRange;
  final List<MonthlySpendingItem> months;
  final ForecastModel? forecast;
  final List<UncertainReviewModel> uncertain;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenForecast;
  final VoidCallback onReview;
  final Widget recentTransactions;
  final Widget? merchants;
  final Widget? recurring;

  const OpenCanvasBody({
    super.key,
    required this.summary,
    required this.range,
    required this.onRange,
    required this.months,
    required this.forecast,
    required this.uncertain,
    required this.onOpenSettings,
    required this.onOpenForecast,
    required this.onReview,
    required this.recentTransactions,
    this.merchants,
    this.recurring,
  });

  static const double wideBreakpoint = 980;

  @override
  Widget build(BuildContext context) {
    final health = FinancialHealthSection(summary: summary, onOpenSettings: onOpenSettings);
    final overview = SpendingOverviewSection(summary: summary, range: range, onRange: onRange);
    final trend = SpendingTrendSection(
      months: months,
      forecastNext: IntelligenceSection.hasForecast(forecast) ? forecast!.totalForecast : null,
    );
    final categories = CategoryRankingSection(categories: summary.categoriesBreakdown);
    final intelligence = IntelligenceSection(forecast: forecast, onOpenForecast: onOpenForecast);
    final review = ReviewSection(items: uncertain, onReview: onReview);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        final rule = Divider(height: 56, thickness: 1, color: Colors.white.withValues(alpha: 0.07));

        final children = wide
            ? <Widget>[
                _pair(health, overview, 5, 6),
                rule,
                _pair(trend, categories, 7, 5),
                rule,
                _pair(intelligence, review, 6, 5),
                rule,
                recentTransactions,
                if (merchants != null || recurring != null) ...[
                  rule,
                  _pair(
                    merchants == null ? const SizedBox.shrink() : DashboardSection(number: '08', title: 'Top merchants', child: merchants!),
                    recurring == null ? const SizedBox.shrink() : DashboardSection(number: '09', title: 'Recurring bills', child: recurring!),
                    1,
                    1,
                  ),
                ],
              ]
            : <Widget>[
                health,
                rule,
                overview,
                rule,
                trend,
                rule,
                categories,
                rule,
                intelligence,
                rule,
                review,
                rule,
                recentTransactions,
                if (merchants != null) ...[rule, DashboardSection(number: '08', title: 'Top merchants', child: merchants!)],
                if (recurring != null) ...[rule, DashboardSection(number: '09', title: 'Recurring bills', child: recurring!)],
              ];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        );
      },
    );
  }

  Widget _pair(Widget left, Widget right, int leftFlex, int rightFlex) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        const SizedBox(width: 56),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}
