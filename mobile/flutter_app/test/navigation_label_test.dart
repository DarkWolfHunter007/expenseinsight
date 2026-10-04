import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/providers/transaction_provider.dart';
import 'package:flutter_app/providers/cash_expense_provider.dart';
import 'package:flutter_app/providers/analytics_provider.dart';
import 'package:flutter_app/providers/forecast_provider.dart';
import 'package:flutter_app/providers/model_provider.dart';
import 'package:flutter_app/providers/statement_provider.dart';
import 'package:flutter_app/providers/auth_provider.dart';
import 'package:flutter_app/screens/main_navigation_screen.dart';

Widget createNavigationApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => StatementProvider()),
      ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ChangeNotifierProvider(create: (_) => CashExpenseProvider()),
      ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
      ChangeNotifierProvider(create: (_) => ForecastProvider()),
      ChangeNotifierProvider(create: (_) => ModelProvider()),
    ],
    child: const MaterialApp(
      home: MainNavigationScreen(),
    ),
  );
}

void main() {
  group('Responsive Navigation Tests', () {
    const mobileWidths = [320.0, 375.0, 390.0, 430.0, 600.0];
    const desktopWidths = [801.0, 1024.0, 1280.0, 1440.0];

    for (final width in mobileWidths) {
      testWidgets('Mobile at ${width}px is icon-only and hides all labels', (WidgetTester tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createNavigationApp());
        await tester.pump();

        final navBar = find.byType(NavigationBar);
        expect(navBar, findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);

        // Mobile labels must NOT be in NavigationBar
        expect(find.descendant(of: navBar, matching: find.text('Overview')), findsNothing);
        expect(find.descendant(of: navBar, matching: find.text('Transactions')), findsNothing);
        expect(find.descendant(of: navBar, matching: find.text('Add')), findsNothing);
        expect(find.descendant(of: navBar, matching: find.text('Forecast')), findsNothing);
        expect(find.descendant(of: navBar, matching: find.text('More')), findsNothing);

        // Icons are visible and rendered inside NavigationBar
        expect(find.descendant(of: navBar, matching: find.byIcon(Icons.home_rounded)), findsOneWidget); // Selected
        expect(find.descendant(of: navBar, matching: find.byIcon(Icons.receipt_long_outlined)), findsOneWidget);
        expect(find.descendant(of: navBar, matching: find.byIcon(Icons.add_circle_outline_rounded)), findsOneWidget);
        expect(find.descendant(of: navBar, matching: find.byIcon(Icons.auto_awesome_outlined)), findsOneWidget);
        expect(find.descendant(of: navBar, matching: find.byIcon(Icons.more_horiz_outlined)), findsOneWidget);

        // Navigation bar height is valid and fits all destinations without overflow
        final navBarBox = tester.renderObject(navBar) as RenderBox;
        expect(navBarBox.size.width, width);
        expect(navBarBox.size.height, greaterThan(0));

        // Destinations are tappable
        await tester.tap(find.descendant(of: navBar, matching: find.byIcon(Icons.auto_awesome_outlined)));
        await tester.pump();
        expect(find.descendant(of: navBar, matching: find.byIcon(Icons.auto_awesome_rounded)), findsOneWidget); // Now selected
      });
    }

    for (final width in desktopWidths) {
      testWidgets('Desktop at ${width}px keeps NavigationRail with labels', (WidgetTester tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createNavigationApp());
        await tester.pump();

        final navRail = find.byType(NavigationRail);
        expect(navRail, findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);

        // Desktop labels are visible inside NavigationRail
        expect(find.descendant(of: navRail, matching: find.text('Dashboard')), findsOneWidget);
        expect(find.descendant(of: navRail, matching: find.text('Cash Expenses')), findsOneWidget);
        expect(find.descendant(of: navRail, matching: find.text('Ingest PDF')), findsOneWidget);
        expect(find.descendant(of: navRail, matching: find.text('Transactions')), findsOneWidget);
        expect(find.descendant(of: navRail, matching: find.text('Forecast')), findsOneWidget);
        expect(find.descendant(of: navRail, matching: find.text('AI Benchmark')), findsOneWidget);

        // Icons are visible inside NavigationRail
        expect(find.descendant(of: navRail, matching: find.byIcon(Icons.dashboard_rounded)), findsOneWidget);
        expect(find.descendant(of: navRail, matching: find.byIcon(Icons.payments_outlined)), findsOneWidget);
      });
    }

    testWidgets('Full 13-step mobile navigation sequence: Forecast and Transactions preserve single NavigationBar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createNavigationApp());
      await tester.pump();

      // Step 1 & 2: Open Home, confirm single bottom NavigationBar exists
      final navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);
      expect(find.text('AI FORECAST'), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.byIcon(Icons.home_rounded)), findsOneWidget);

      // Step 3 & 4: Tap AI Forecast card -> Forecast screen opens
      await tester.tap(find.text('View'));
      await tester.pump();
      expect(find.text('Expense Forecasting'), findsOneWidget);

      // Step 5 & 6: Bottom NavigationBar remains visible (single instance), Forecast tab selected
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.byIcon(Icons.auto_awesome_rounded)), findsOneWidget);

      // Step 7 & 8: Tap Transactions from bottom nav -> Transactions opens
      await tester.tap(find.descendant(of: navBar, matching: find.byIcon(Icons.receipt_long_outlined)));
      await tester.pump();
      expect(find.widgetWithText(AppBar, 'Transactions'), findsOneWidget);

      // Step 9: Bottom NavigationBar remains visible, Transactions selected
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.byIcon(Icons.receipt_long_rounded)), findsOneWidget);

      // Step 10 & 11: Tap Home -> Home opens
      await tester.tap(find.descendant(of: navBar, matching: find.byIcon(Icons.home_outlined)));
      await tester.pump();
      expect(find.text('AI FORECAST'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.byIcon(Icons.home_rounded)), findsOneWidget);

      // Step 12 & 13: Tap Forecast from bottom navigation -> Forecast opens with bottom nav
      await tester.tap(find.descendant(of: navBar, matching: find.byIcon(Icons.auto_awesome_outlined)));
      await tester.pump();
      expect(find.text('Expense Forecasting'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.byIcon(Icons.auto_awesome_rounded)), findsOneWidget);

      // Return to Home and test "View All" on Recent Transactions
      await tester.tap(find.descendant(of: navBar, matching: find.byIcon(Icons.home_outlined)));
      await tester.pump();
      expect(find.text('AI FORECAST'), findsOneWidget);

      // Drag up to scroll down to Recent Transactions
      await tester.drag(find.text('AI FORECAST'), const Offset(0, -500));
      await tester.pump();

      expect(find.text('RECENT TRANSACTIONS'), findsOneWidget);

      // Tap "View All" button
      await tester.tap(find.text('View All'));
      await tester.pump();

      // Transactions opens with parent NavigationBar preserved
      expect(find.widgetWithText(AppBar, 'Transactions'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.byIcon(Icons.receipt_long_rounded)), findsOneWidget);
    });
  });
}
