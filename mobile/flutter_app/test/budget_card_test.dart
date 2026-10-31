import 'package:flutter/material.dart';
import 'package:flutter_app/models/analytics_model.dart';
import 'package:flutter_app/widgets/budget_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnalyticsSummaryModel _summary(String status) => AnalyticsSummaryModel(
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
      monthlyBudget: 2000,
      budgetMonth: '2026-10',
      budgetSpent: status == 'exceeded' ? 2500 : 1700,
      budgetRemaining: status == 'exceeded' ? -500 : 300,
      budgetUsedPct: status == 'exceeded' ? 125 : 85,
      budgetStatus: status,
    );

Widget _host(AnalyticsSummaryModel s) => MaterialApp(home: Scaffold(body: BudgetCard(summary: s)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('close button dismisses the card', (tester) async {
    await tester.pumpWidget(_host(_summary('exceeded')));
    await tester.pumpAndSettle();
    expect(find.textContaining('exceeded this month'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('exceeded this month'), findsNothing);
  });

  testWidgets('dismissal is remembered but a worse status shows again', (tester) async {
    SharedPreferences.setMockInitialValues({'budget_card_dismissed': '2026-10|warning'});

    await tester.pumpWidget(_host(_summary('warning')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Close to this month'), findsNothing);

    await tester.pumpWidget(_host(_summary('exceeded')));
    await tester.pumpAndSettle();
    expect(find.textContaining('exceeded this month'), findsOneWidget);
  });
}
