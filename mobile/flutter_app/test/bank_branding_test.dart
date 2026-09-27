import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/config/bank_branding.dart';
import 'package:flutter_app/models/analytics_model.dart';
import 'package:flutter_app/widgets/bank_statement_header.dart';

void main() {
  group('Bank Branding & Heading Tests', () {
    test('Identifies known bank brands correctly', () {
      final hdfc = BankBranding.fromName('HDFC Bank');
      expect(hdfc.name, 'HDFC Bank');
      expect(hdfc.shortCode, 'HDFC');
      expect(hdfc.primaryColor, const Color(0xFF004C8F));

      final sbi = BankBranding.fromName('State Bank of India');
      expect(sbi.name, 'State Bank of India');
      expect(sbi.shortCode, 'SBI');

      final icici = BankBranding.fromName('ICICI Bank');
      expect(icici.name, 'ICICI Bank');
      expect(icici.shortCode, 'ICICI');

      final axis = BankBranding.fromName('Axis Bank');
      expect(axis.name, 'Axis Bank');
      expect(axis.shortCode, 'AXIS');

      final kotak = BankBranding.fromName('Kotak Mahindra Bank');
      expect(kotak.name, 'Kotak Mahindra Bank');
      expect(kotak.shortCode, 'KOTAK');
    });

    test('Falls back to safe default branding for unknown banks', () {
      final fallback = BankBranding.fromName(null);
      expect(fallback.name, 'Bank Statement');
      expect(fallback.shortCode, 'BANK');

      final custom = BankBranding.fromName('Apex Cooperative Bank');
      expect(custom.name, 'Apex Cooperative Bank');
      expect(custom.shortCode, 'BANK');
    });

    test('AnalyticsSummaryModel deserializes bank_name from JSON', () {
      final json = {
        'total_expense': 50000.0,
        'total_income': 100000.0,
        'total_transfers': 0.0,
        'net_savings': 50000.0,
        'this_month_spent': 15000.0,
        'previous_month_spent': 14000.0,
        'month_over_month_change_pct': 7.1,
        'average_daily_spend': 500.0,
        'total_transactions_count': 45,
        'statement_period': '01/01/2026 - 30/06/2026',
        'bank_name': 'State Bank of India',
        'categories_breakdown': [],
        'top_merchants': [],
        'recurring_expenses': [],
      };

      final model = AnalyticsSummaryModel.fromJson(json);
      expect(model.bankName, 'State Bank of India');
      expect(model.totalTransactionsCount, 45);
      expect(model.statementPeriod, '01/01/2026 - 30/06/2026');
    });

    testWidgets('BankStatementHeader renders dynamic bank heading and badges', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BankStatementHeader(
              bankName: 'HDFC Bank',
              statementPeriod: 'Jan 01, 2026 - Jun 30, 2026',
              transactionCount: 128,
            ),
          ),
        ),
      );

      expect(find.text('HDFC Bank Statement'), findsOneWidget);
      expect(find.text('HDFC'), findsOneWidget);
      expect(find.text('We Understand Your World'), findsOneWidget);
      expect(find.text('Jan 01, 2026 - Jun 30, 2026'), findsOneWidget);
      expect(find.text('128 transactions'), findsOneWidget);
      expect(find.text('Analyzed'), findsOneWidget);
    });

    testWidgets('CompactStatementContextCard renders single statement context', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompactStatementContextCard(
              bankName: 'HDFC Bank',
              statementPeriod: 'Jan 01, 2026 - Jun 30, 2026',
              transactionCount: 128,
              statementCount: 1,
            ),
          ),
        ),
      );

      expect(find.text('HDFC Bank'), findsOneWidget);
      expect(find.text('HDFC'), findsOneWidget);
      expect(find.text('Jan 01, 2026 - Jun 30, 2026 · 128 transactions'), findsOneWidget);
    });

    testWidgets('CompactStatementContextCard accurately represents multiple statements', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompactStatementContextCard(
              bankName: 'Multiple Banks (HDFC, SBI)',
              statementPeriod: 'Jan 01, 2026 - Jun 30, 2026',
              transactionCount: 256,
              statementCount: 2,
            ),
          ),
        ),
      );

      expect(find.text('Multiple Bank Statements'), findsOneWidget);
      expect(find.text('MULTI'), findsOneWidget);
      expect(find.text('2 statements · 256 transactions'), findsOneWidget);
    });

    testWidgets('CompactStatementContextCard handles empty state cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompactStatementContextCard(
              bankName: 'Bank Statement',
              statementPeriod: null,
              transactionCount: 0,
              statementCount: 0,
            ),
          ),
        ),
      );

      expect(find.text('No Statements Ingested'), findsOneWidget);
      expect(find.text('Upload a statement to begin'), findsOneWidget);
    });
  });
}
