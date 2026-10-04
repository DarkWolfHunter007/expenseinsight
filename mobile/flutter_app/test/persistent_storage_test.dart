import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/providers/analytics_provider.dart';
import 'package:flutter_app/providers/auth_provider.dart';
import 'package:flutter_app/providers/cash_expense_provider.dart';
import 'package:flutter_app/providers/forecast_provider.dart';
import 'package:flutter_app/providers/statement_provider.dart';
import 'package:flutter_app/providers/transaction_provider.dart';
import 'package:flutter_app/services/expense_sync_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Persistent User Identity & Storage Lifecycle Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('AuthProvider offline startup restores cached identity without creating new account', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'cached_jwt_offline',
        'user_email': 'offline_user@example.com',
        'user_id': 'offline-uuid-999',
        'user_is_guest': false,
      });

      final auth = AuthProvider();
      await auth.init();

      // Offline initialization should restore cached user identity from SharedPreferences
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user, isNotNull);
      expect(auth.user!.id, equals('offline-uuid-999'));
      expect(auth.user!.email, equals('offline_user@example.com'));
      expect(auth.user!.isGuest, isFalse);
    });

    test('In-memory providers clear method resets all internal state and filters', () {
      final txnProvider = TransactionProvider();
      final cashProvider = CashExpenseProvider();
      final forecastProvider = ForecastProvider();
      final analyticsProvider = AnalyticsProvider();
      final statementProvider = StatementProvider();

      // Populate dummy states to simulate active session
      cashProvider.setSearchQuery('test query');
      expect(cashProvider.searchQuery, equals('test query'));

      // Invoke clear on each provider
      txnProvider.clear();
      cashProvider.clear();
      forecastProvider.clear();
      analyticsProvider.clear();
      statementProvider.clear();

      expect(txnProvider.rawTransactions, isEmpty);
      expect(txnProvider.selectedCategory, equals('All'));
      expect(txnProvider.selectedSource, equals('All'));
      expect(txnProvider.searchQuery, isEmpty);

      expect(cashProvider.cashExpenses, isEmpty);
      expect(cashProvider.searchQuery, isEmpty);
      expect(cashProvider.selectedCategory, isNull);

      expect(forecastProvider.forecast, isNull);
      expect(forecastProvider.isStale, isFalse);

      expect(analyticsProvider.summary, isNull);
      expect(analyticsProvider.monthlySpending, isEmpty);

      expect(statementProvider.statements, isEmpty);
      expect(statementProvider.uploadProgress, equals(0.0));
    });

    test('ExpenseSyncCoordinator notifyUserSessionReset clears all registered providers', () {
      final coordinator = ExpenseSyncCoordinator();
      final txnProvider = TransactionProvider(coordinator: coordinator);
      final cashProvider = CashExpenseProvider(coordinator: coordinator);
      final forecastProvider = ForecastProvider(coordinator: coordinator);
      final analyticsProvider = AnalyticsProvider(coordinator: coordinator);
      final statementProvider = StatementProvider(coordinator: coordinator);

      // Simulate session mutation
      cashProvider.setSearchQuery('search term');
      expect(cashProvider.searchQuery, equals('search term'));

      // Fire session reset
      coordinator.notifyUserSessionReset();

      // All providers should now be cleared
      expect(txnProvider.rawTransactions, isEmpty);
      expect(cashProvider.cashExpenses, isEmpty);
      expect(cashProvider.searchQuery, isEmpty);
      expect(forecastProvider.forecast, isNull);
      expect(analyticsProvider.summary, isNull);
      expect(statementProvider.statements, isEmpty);

      txnProvider.dispose();
      cashProvider.dispose();
      forecastProvider.dispose();
      analyticsProvider.dispose();
      statementProvider.dispose();
    });

    test('AuthProvider logout triggers session reset across providers and clears tokens', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'active_token',
        'user_email': 'active@example.com',
        'user_id': 'active_id',
      });

      final coordinator = ExpenseSyncCoordinator();
      final auth = AuthProvider(coordinator: coordinator);
      final txnProvider = TransactionProvider(coordinator: coordinator);

      await auth.init();
      expect(auth.isAuthenticated, isTrue);

      await auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(txnProvider.rawTransactions, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('user_email'), isNull);
      expect(prefs.getString('user_id'), isNull);

      txnProvider.dispose();
    });

    test('Multi-user isolation: switching accounts notifies session reset and clears prior state', () async {
      final coordinator = ExpenseSyncCoordinator();
      bool sessionResetFired = false;
      coordinator.addSessionResetListener(() {
        sessionResetFired = true;
      });

      final auth = AuthProvider(coordinator: coordinator);

      // Simulate User A logged in
      SharedPreferences.setMockInitialValues({
        'auth_token': 'user_a_token',
        'user_email': 'usera@example.com',
        'user_id': 'uuid-user-a',
      });
      await auth.init();
      expect(auth.user?.email, equals('usera@example.com'));

      // Logout User A
      await auth.logout();
      expect(sessionResetFired, isTrue);

      // Reset flag and login User B
      sessionResetFired = false;
      SharedPreferences.setMockInitialValues({
        'auth_token': 'user_b_token',
        'user_email': 'userb@example.com',
        'user_id': 'uuid-user-b',
      });
      await auth.init();
      expect(auth.user?.email, equals('userb@example.com'));
      expect(auth.user?.id, equals('uuid-user-b'));
    });
  });
}
