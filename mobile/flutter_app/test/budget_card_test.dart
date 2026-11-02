import 'package:flutter/material.dart';
import 'package:flutter_app/models/analytics_model.dart';
import 'package:flutter_app/widgets/budget_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnalyticsSummaryModel _summary(
  String status, {
  double budget = 2000,
  double spent = 1000,
  double pct = 50,
  double safe = 40,
  int daysLeft = 25,
  LastMonthRecap? recap,
  List<CategoryBudgetItem> categories = const [],
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
      budgetMonth: '2026-11',
      budgetSpent: spent,
      budgetRemaining: budget - spent,
      budgetUsedPct: pct,
      budgetStatus: status,
      daysLeftInMonth: daysLeft,
      safeToSpendToday: safe,
      lastMonthRecap: recap,
      categoryBudgets: categories,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Widget _card(AnalyticsSummaryModel s, {String user = 'alice', DateTime? today}) =>
    _host(BudgetCard(summary: s, userKey: user, today: today ?? DateTime(2026, 11, 3)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('status moves through the budget levels inside the one card', () {
    testWidgets('on track, close, almost at the limit, over budget', (tester) async {
      final cases = {
        'on_track': ('On track', 50.0, 1000.0),
        'warning': ('Close to the limit', 85.0, 1700.0),
        'critical': ('Almost at the limit', 94.0, 1880.0),
        'exceeded': ('Over budget', 125.0, 2500.0),
      };
      for (final entry in cases.entries) {
        final (label, pct, spent) = entry.value;
        await tester.pumpWidget(_card(_summary(entry.key, pct: pct, spent: spent)));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget, reason: entry.key);
      }
    });

    testWidgets('exceeded shows how far over, and not a stack of separate banners', (tester) async {
      await tester.pumpWidget(_card(_summary('exceeded', spent: 2500, pct: 125, safe: 0)));
      await tester.pumpAndSettle();
      expect(find.text('Over budget by'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('flags the categories that are close to their limit', (tester) async {
      final categories = [
        CategoryBudgetItem(category: 'Food', limit: 500, spent: 470, remaining: 30, usedPct: 94, status: 'critical'),
        CategoryBudgetItem(category: 'Travel', limit: 500, spent: 100, remaining: 400, usedPct: 20, status: 'on_track'),
      ];
      await tester.pumpWidget(_card(_summary('critical', pct: 94, spent: 1880, categories: categories)));
      await tester.pumpAndSettle();
      expect(find.text('Food 94%'), findsOneWidget);
      expect(find.text('Travel 20%'), findsNothing);
    });

    testWidgets('with no budget it says so instead of showing zeros', (tester) async {
      await tester.pumpWidget(_card(_summary('none', budget: 0)));
      await tester.pumpAndSettle();
      expect(find.textContaining('No budget yet'), findsOneWidget);
    });
  });

  group('safe to spend today (daily dismissal)', () {
    testWidgets('shows the allowance and the days left', (tester) async {
      await tester.pumpWidget(_card(_summary('on_track', safe: 85, daysLeft: 28)));
      await tester.pumpAndSettle();
      expect(find.text('Safe to spend today'), findsOneWidget);
      expect(find.text('₹85'), findsOneWidget);
      expect(find.text('28 days left this month'), findsOneWidget);
    });

    testWidgets('hiding it keeps the budget figures and is remembered for the day', (tester) async {
      await tester.pumpWidget(_card(_summary('on_track')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("Hide today's allowance"));
      await tester.pumpAndSettle();

      expect(find.text('Safe to spend today'), findsNothing);
      // the underlying budget calculation is untouched
      expect(find.text('Monthly budget'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('safe_to_spend_dismissed_alice'), '2026-11-03');

      // the same day, after a rebuild: still hidden
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(_card(_summary('on_track')));
      await tester.pumpAndSettle();
      expect(find.text('Safe to spend today'), findsNothing);
    });

    testWidgets('comes back the next day', (tester) async {
      SharedPreferences.setMockInitialValues({'safe_to_spend_dismissed_alice': '2026-11-03'});
      await tester.pumpWidget(_card(_summary('on_track'), today: DateTime(2026, 11, 4)));
      await tester.pumpAndSettle();
      expect(find.text('Safe to spend today'), findsOneWidget);
    });

    testWidgets('a dismissal by one account does not hide it for another on the same browser', (tester) async {
      SharedPreferences.setMockInitialValues({'safe_to_spend_dismissed_alice': '2026-11-03'});
      await tester.pumpWidget(_card(_summary('on_track'), user: 'bob'));
      await tester.pumpAndSettle();
      expect(find.text('Safe to spend today'), findsOneWidget);
    });

    testWidgets('says there is no room left once the budget is exceeded', (tester) async {
      await tester.pumpWidget(_card(_summary('exceeded', spent: 2500, pct: 125, safe: 0)));
      await tester.pumpAndSettle();
      expect(find.text('No room left this month'), findsOneWidget);
    });
  });

  group('last month recap (monthly dismissal)', () {
    final recap = LastMonthRecap(month: '2026-10', spent: 1500, budget: 2000, difference: 500, underBudget: true);

    testWidgets('shows a compact summary of the month', (tester) async {
      await tester.pumpWidget(_card(_summary('on_track', recap: recap)));
      await tester.pumpAndSettle();
      expect(find.textContaining('October 2026 closed ₹500 under budget'), findsOneWidget);
    });

    testWidgets('can be hidden for that month and stays hidden', (tester) async {
      await tester.pumpWidget(_card(_summary('on_track', recap: recap)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("Hide last month's summary"));
      await tester.pumpAndSettle();
      expect(find.textContaining('closed'), findsNothing);
      expect((await SharedPreferences.getInstance()).getString('month_recap_dismissed_alice'), '2026-10');

      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(_card(_summary('on_track', recap: recap)));
      await tester.pumpAndSettle();
      expect(find.textContaining('closed'), findsNothing);
    });

    testWidgets('a different month shows again', (tester) async {
      SharedPreferences.setMockInitialValues({'month_recap_dismissed_alice': '2026-10'});
      final next = LastMonthRecap(month: '2026-11', spent: 2600, budget: 2000, difference: -600, underBudget: false);
      await tester.pumpWidget(_card(_summary('on_track', recap: next)));
      await tester.pumpAndSettle();
      expect(find.textContaining('November 2026 closed ₹600 over budget'), findsOneWidget);
    });

    testWidgets('reports an overspent month', (tester) async {
      final over = LastMonthRecap(month: '2026-10', spent: 2600, budget: 2000, difference: -600, underBudget: false);
      await tester.pumpWidget(_card(_summary('on_track', recap: over)));
      await tester.pumpAndSettle();
      expect(find.textContaining('over budget'), findsOneWidget);
    });
  });
}
