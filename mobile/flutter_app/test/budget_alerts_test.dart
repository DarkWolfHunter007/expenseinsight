import 'package:flutter/material.dart';
import 'package:flutter_app/models/analytics_model.dart';
import 'package:flutter_app/models/budget_settings_model.dart';
import 'package:flutter_app/services/budget_notification_service.dart';
import 'package:flutter_app/widgets/budget_banners.dart';
import 'package:flutter_app/widgets/budget_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnalyticsSummaryModel _summary({
  String status = 'on_track',
  double budget = 2000,
  double spent = 1000,
  double usedPct = 50,
  List<CategoryBudgetItem> categories = const [],
  LastMonthRecap? recap,
  double safe = 40,
  int daysLeft = 25,
}) =>
    AnalyticsSummaryModel(
      totalExpense: 0,
      totalIncome: 0,
      totalTransfers: 0,
      netSavings: 0,
      thisMonthSpent: 0,
      previousMonthSpent: 0,
      monthOverMonthChangePct: 0,
      averageDailySpend: 0,
      totalTransactionsCount: 0,
      categoriesBreakdown: const [],
      topMerchants: const [],
      recurringExpenses: const [],
      monthlyBudget: budget,
      budgetMonth: '2026-10',
      budgetSpent: spent,
      budgetRemaining: budget - spent,
      budgetUsedPct: usedPct,
      budgetStatus: status,
      daysLeftInMonth: daysLeft,
      safeToSpendToday: safe,
      categoryBudgets: categories,
      lastMonthRecap: recap,
    );

CategoryBudgetItem _cat(String name, String status, double pct) => CategoryBudgetItem(
      category: name,
      limit: 500,
      spent: 500 * pct / 100,
      remaining: 500 - 500 * pct / 100,
      usedPct: pct,
      status: status,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('BudgetAlertPlanner', () {
    test('no alert while on track or when there is no budget', () {
      expect(BudgetAlertPlanner.plan(_summary(), {}), isEmpty);
      expect(BudgetAlertPlanner.plan(_summary(status: 'none'), {}), isEmpty);
    });

    test('one alert per tier crossed', () {
      final warning = BudgetAlertPlanner.plan(_summary(status: 'warning', spent: 1600, usedPct: 80), {});
      expect(warning.single.key, '2026-10|all|warning');
      expect(warning.single.title, contains('80%'));

      final critical = BudgetAlertPlanner.plan(_summary(status: 'critical', spent: 1850, usedPct: 92), {});
      expect(critical.single.title, contains('90%'));

      final exceeded = BudgetAlertPlanner.plan(_summary(status: 'exceeded', spent: 2500, usedPct: 125), {});
      expect(exceeded.single.title, contains('exceeded'));
      expect(exceeded.single.body, contains('over by ₹500'));
    });

    test('a tier that was already sent is not repeated', () {
      final s = _summary(status: 'critical', spent: 1850, usedPct: 92);
      expect(BudgetAlertPlanner.plan(s, {'2026-10|all|critical'}), isEmpty);
    });

    test('a new month starts fresh', () {
      final s = _summary(status: 'critical', spent: 1850, usedPct: 92);
      expect(BudgetAlertPlanner.plan(s, {'2026-09|all|critical'}), hasLength(1));
    });

    test('categories alert on their own', () {
      final s = _summary(categories: [_cat('Food', 'critical', 94), _cat('Travel', 'on_track', 20)]);
      final alerts = BudgetAlertPlanner.plan(s, {});
      expect(alerts.single.key, '2026-10|Food|critical');
      expect(alerts.single.title, 'Food budget at 94%');
    });
  });

  group('BudgetCard', () {
    testWidgets('critical shows what is left and flagged categories', (tester) async {
      await tester.pumpWidget(_host(BudgetCard(
        summary: _summary(
          status: 'critical',
          spent: 1850,
          usedPct: 92.5,
          categories: [_cat('Food', 'critical', 94), _cat('Travel', 'on_track', 20)],
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only ₹150 left'), findsOneWidget);
      expect(find.text('Food 94%'), findsOneWidget);
      expect(find.text('Travel 20%'), findsNothing);
    });
  });

  group('SafeToSpendBanner', () {
    testWidgets('shows the daily allowance and closes for the day', (tester) async {
      await tester.pumpWidget(_host(SafeToSpendBanner(summary: _summary(), today: DateTime(2026, 10, 6))));
      await tester.pumpAndSettle();
      expect(find.textContaining('You can spend about ₹40 today'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('You can spend about'), findsNothing);
    });

    testWidgets('comes back the next day', (tester) async {
      SharedPreferences.setMockInitialValues({'safe_to_spend_dismissed': '2026-10-06'});
      await tester.pumpWidget(_host(SafeToSpendBanner(summary: _summary(), today: DateTime(2026, 10, 7))));
      await tester.pumpAndSettle();
      expect(find.textContaining('You can spend about'), findsOneWidget);
    });

    testWidgets('says there is no room once the budget is exceeded', (tester) async {
      await tester.pumpWidget(_host(SafeToSpendBanner(summary: _summary(status: 'exceeded', spent: 2500, usedPct: 125))));
      await tester.pumpAndSettle();
      expect(find.textContaining('No room left'), findsOneWidget);
    });
  });

  group('MonthRecapBanner', () {
    testWidgets('celebrates a month closed under budget', (tester) async {
      final recap = LastMonthRecap(month: '2026-09', spent: 1500, budget: 2000, difference: 500, underBudget: true);
      await tester.pumpWidget(_host(MonthRecapBanner(recap: recap)));
      await tester.pumpAndSettle();
      expect(find.text('September closed ₹500 under budget'), findsOneWidget);
      expect(find.textContaining('spent ₹1500 of ₹2000'), findsOneWidget);
    });

    testWidgets('reports an overspent month and can be closed', (tester) async {
      final recap = LastMonthRecap(month: '2026-09', spent: 2600, budget: 2000, difference: -600, underBudget: false);
      await tester.pumpWidget(_host(MonthRecapBanner(recap: recap)));
      await tester.pumpAndSettle();
      expect(find.text('September closed ₹600 over budget'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('September closed'), findsNothing);
    });

    testWidgets('shows nothing without a recap', (tester) async {
      await tester.pumpWidget(_host(const MonthRecapBanner(recap: null)));
      await tester.pumpAndSettle();
      expect(find.byType(Container), findsNothing);
    });
  });

  test('BudgetSettingsModel round trips through JSON', () {
    const settings = BudgetSettingsModel(autoLimits: false, monthlyLimit: 4000, categoryLimits: {'Food': 1500});
    final copy = BudgetSettingsModel.fromJson(settings.toJson());
    expect(copy.autoLimits, false);
    expect(copy.monthlyLimit, 4000);
    expect(copy.categoryLimits, {'Food': 1500});
  });

  test('summary parses the new budget fields', () {
    final s = AnalyticsSummaryModel.fromJson({
      'budget_status': 'critical',
      'budget_mode': 'manual',
      'days_left_in_month': 5,
      'safe_to_spend_today': 12.5,
      'category_budgets': [
        {'category': 'Food', 'limit': 500, 'spent': 480, 'remaining': 20, 'used_pct': 96.0, 'status': 'critical'}
      ],
      'last_month_recap': {'month': '2026-09', 'spent': 10, 'budget': 20, 'difference': 10, 'under_budget': true},
    });
    expect(s.budgetMode, 'manual');
    expect(s.categoryBudgets.single.usedPct, 96.0);
    expect(s.lastMonthRecap?.underBudget, true);
  });
}
