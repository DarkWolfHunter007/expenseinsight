import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'providers/analytics_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/cash_expense_provider.dart';
import 'providers/forecast_provider.dart';
import 'providers/model_provider.dart';
import 'providers/statement_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.init();

  final statementProvider = StatementProvider();
  final transactionProvider = TransactionProvider();
  final cashExpenseProvider = CashExpenseProvider();
  final analyticsProvider = AnalyticsProvider();
  final forecastProvider = ForecastProvider();
  final modelProvider = ModelProvider();

  // Onboarding loads this data after sign-in, so a restored session must load it here.
  if (authProvider.isAuthenticated && !authProvider.user!.isGuest) {
    statementProvider.fetchStatements();
    transactionProvider.fetchTransactions();
    cashExpenseProvider.fetchCashExpenses();
    analyticsProvider.fetchAnalytics();
    forecastProvider.fetchForecast();
    modelProvider.fetchMetrics();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: statementProvider),
        ChangeNotifierProvider.value(value: transactionProvider),
        ChangeNotifierProvider.value(value: cashExpenseProvider),
        ChangeNotifierProvider.value(value: analyticsProvider),
        ChangeNotifierProvider.value(value: forecastProvider),
        ChangeNotifierProvider.value(value: modelProvider),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
      ],
      child: const ExpenseInsightApp(),
    ),
  );
}

class ExpenseInsightApp extends StatelessWidget {
  const ExpenseInsightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final bool isUserRestored = auth.isAuthenticated && !auth.user!.isGuest;

        return MaterialApp(
          title: 'ExpenseInsight',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: isUserRestored ? const MainNavigationScreen() : const OnboardingScreen(),
        );
      },
    );
  }
}
