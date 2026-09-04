import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/providers/analytics_provider.dart';
import 'package:flutter_app/providers/auth_provider.dart';
import 'package:flutter_app/providers/forecast_provider.dart';
import 'package:flutter_app/providers/model_provider.dart';
import 'package:flutter_app/providers/statement_provider.dart';
import 'package:flutter_app/providers/transaction_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('ExpenseInsight App smoke test', (WidgetTester tester) async {
    final authProvider = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => StatementProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
          ChangeNotifierProvider(create: (_) => ForecastProvider()),
          ChangeNotifierProvider(create: (_) => ModelProvider()),
        ],
        child: const ExpenseInsightApp(),
      ),
    );

    expect(find.text('ExpenseInsight'), findsOneWidget);
    expect(find.text('Automated PDF Parsing'), findsOneWidget);
  });
}
