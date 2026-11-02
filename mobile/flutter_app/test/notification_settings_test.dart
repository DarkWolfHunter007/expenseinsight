import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app/models/analytics_model.dart';
import 'package:flutter_app/services/budget_notification_service.dart';
import 'package:flutter_app/widgets/notification_settings_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnalyticsSummaryModel _summary(String status, {double budget = 2000, double spent = 100, double pct = 5}) =>
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
      daysLeftInMonth: 20,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NotificationSettingsCard', () {
    testWidgets('the on/off choice is saved and still on after the screen is rebuilt', (tester) async {
      await tester.pumpWidget(_host(const NotificationSettingsCard()));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect((await SharedPreferences.getInstance()).getBool(BudgetNotificationService.enabledKey), isTrue);

      // A brand-new card (as after a reload) reads the saved choice back
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(_host(const NotificationSettingsCard()));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('says plainly why notifications are not working when the browser cannot show them', (tester) async {
      SharedPreferences.setMockInitialValues({BudgetNotificationService.enabledKey: true});
      await tester.pumpWidget(_host(const NotificationSettingsCard()));
      await tester.pumpAndSettle();
      expect(find.textContaining('does not support notifications'), findsOneWidget);
      expect(find.textContaining('Not working: this browser cannot show notifications'), findsOneWidget);
      // The toggle still shows the saved choice instead of jumping back to off
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('lists recent alerts, including ones that could not be shown', (tester) async {
      SharedPreferences.setMockInitialValues({
        BudgetNotificationService.logKey: [
          json.encode(NotificationLogEntry(
                  time: DateTime(2026, 11, 2, 10, 30), title: '90% of this month\'s budget used', delivered: true)
              .toJson()),
          json.encode(NotificationLogEntry(
                  time: DateTime(2026, 11, 1, 9, 0),
                  title: 'Test notification',
                  delivered: false,
                  problem: 'Notification permission has not been granted.')
              .toJson()),
        ],
      });
      await tester.pumpWidget(_host(const NotificationSettingsCard()));
      await tester.pumpAndSettle();
      expect(find.textContaining('90% of this month\'s budget used'), findsOneWidget);
      expect(find.textContaining('not shown: Notification permission has not been granted.'), findsOneWidget);
    });

    testWidgets('shows what happens next for the current budget level', (tester) async {
      await tester.pumpWidget(_host(NotificationSettingsCard(summary: _summary('on_track'))));
      await tester.pumpAndSettle();
      expect(find.textContaining('no alert is due yet'), findsOneWidget);
      expect(find.textContaining('80% (₹1600)'), findsOneWidget);
    });
  });

  group('BudgetAlertPlanner.describeNext', () {
    test('explains each level', () {
      expect(BudgetAlertPlanner.describeNext(_summary('none', budget: 0)), contains('nothing to alert on'));
      expect(BudgetAlertPlanner.describeNext(_summary('warning', spent: 1700, pct: 85)), contains('Next alerts: 90%'));
      expect(BudgetAlertPlanner.describeNext(_summary('critical', spent: 1900, pct: 95)), contains('Next alert: when you pass'));
      expect(BudgetAlertPlanner.describeNext(_summary('exceeded', spent: 2500, pct: 125)), contains('Over budget'));
    });
  });

  test('a failed alert is not marked as sent, so it is retried', () async {
    SharedPreferences.setMockInitialValues({BudgetNotificationService.enabledKey: true});
    // In a test (no browser) nothing can be shown, so maybeNotify must do nothing and remember nothing
    await BudgetNotificationService.instance.maybeNotify(_summary('critical', spent: 1900, pct: 95));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(BudgetNotificationService.sentKey) ?? [], isEmpty);
  });
}
