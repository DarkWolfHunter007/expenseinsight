import 'package:flutter/material.dart';
import 'package:flutter_app/models/analytics_model.dart';
import 'package:flutter_app/widgets/money_flow_card.dart';
import 'package:flutter_test/flutter_test.dart';

AnalyticsSummaryModel _summary({
  double out = 0,
  double inn = 0,
  double spending = 0,
  double transfersOut = 0,
  double transfersIn = 0,
  double other = 0,
}) =>
    AnalyticsSummaryModel(
      totalExpense: spending,
      totalIncome: 0,
      totalTransfers: transfersOut + transfersIn,
      netSavings: 0,
      thisMonthSpent: 0,
      previousMonthSpent: 0,
      monthOverMonthChangePct: 0,
      averageDailySpend: 0,
      totalTransactionsCount: 0,
      categoriesBreakdown: const [],
      topMerchants: const [],
      recurringExpenses: const [],
      bankSpending: spending,
      bankMoneyOut: out,
      bankMoneyIn: inn,
      transfersOut: transfersOut,
      transfersIn: transfersIn,
      otherMoneyOut: other,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('shows money out and in split into spending and transfers (the Canara statement)', (tester) async {
    await tester.pumpWidget(_host(MoneyFlowCard(
      summary: _summary(
        out: 16343.82,
        inn: 14666.00,
        spending: 2586.0,
        transfersOut: 13757.82,
        transfersIn: 12966.0,
      ),
    )));
    expect(find.text('₹16,344'), findsOneWidget); // all withdrawals in the PDF
    expect(find.text('₹14,666'), findsOneWidget); // all deposits in the PDF
    expect(find.text('₹2,586'), findsOneWidget); // purchases and bills
    expect(find.text('₹13,758'), findsOneWidget); // transfers to people
    expect(find.text('₹12,966'), findsOneWidget); // transfers from people
    expect(find.text('₹1,700'), findsOneWidget); // salary, refunds and other credits
    expect(find.textContaining('Transfers to people'), findsOneWidget);
  });

  testWidgets('leaves out empty rows', (tester) async {
    await tester.pumpWidget(_host(MoneyFlowCard(summary: _summary(out: 500, inn: 0, spending: 500))));
    expect(find.text('₹500'), findsNWidgets(2)); // the total and the single part
    expect(find.textContaining('Transfers to people'), findsNothing);
    expect(find.textContaining('Other (cash withdrawals'), findsNothing);
  });

  testWidgets('is hidden when there is no bank data', (tester) async {
    await tester.pumpWidget(_host(MoneyFlowCard(summary: _summary())));
    expect(find.textContaining('MONEY IN AND OUT'), findsNothing);
  });

  test('summary parses the new fields and defaults to zero for an older server', () {
    final fresh = AnalyticsSummaryModel.fromJson({
      'bank_money_out': 16343.82,
      'bank_money_in': 14666,
      'transfers_out': 13757.82,
      'transfers_in': 12966,
      'other_money_out': 0,
    });
    expect(fresh.bankMoneyOut, 16343.82);
    expect(fresh.transfersIn, 12966);
    expect(AnalyticsSummaryModel.fromJson({}).bankMoneyOut, 0.0);
  });

  test('summary parses net cash flow and the latest month label', () {
    final s = AnalyticsSummaryModel.fromJson({'net_cash_flow': -1677.82, 'this_month_label': 'Sep 2026'});
    expect(s.netCashFlow, -1677.82);
    expect(s.thisMonthLabel, 'Sep 2026');
    final old = AnalyticsSummaryModel.fromJson({});
    expect(old.netCashFlow, 0.0);
    expect(old.thisMonthLabel, '');
  });
}
