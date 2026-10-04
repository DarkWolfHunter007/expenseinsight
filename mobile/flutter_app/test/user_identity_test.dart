import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/models/user_model.dart';
import 'package:flutter_app/providers/analytics_provider.dart';
import 'package:flutter_app/providers/auth_provider.dart';
import 'package:flutter_app/providers/cash_expense_provider.dart';
import 'package:flutter_app/providers/forecast_provider.dart';
import 'package:flutter_app/providers/model_provider.dart';
import 'package:flutter_app/providers/statement_provider.dart';
import 'package:flutter_app/providers/transaction_provider.dart';
import 'package:flutter_app/screens/onboarding_screen.dart';
import 'package:flutter_app/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Identity & Session Persistence Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('AuthProvider validation rejects malformed email strings', () async {
      final auth = AuthProvider();

      final emptyResult = await auth.identifyWithEmail('   ');
      expect(emptyResult, isFalse);
      expect(auth.errorMessage, contains('valid email'));

      final noDomainResult = await auth.identifyWithEmail('user@nodomain');
      expect(noDomainResult, isFalse);
      expect(auth.errorMessage, contains('valid email'));

      final noAtResult = await auth.identifyWithEmail('plainstring.com');
      expect(noAtResult, isFalse);
      expect(auth.errorMessage, contains('valid email'));
    });

    test('ApiService stores and restores auth_token, user_email, and user_id in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'saved_jwt_token_123',
        'user_email': 'alice@example.com',
        'user_id': 'user-uuid-alice',
      });

      final api = ApiService();
      await api.init();

      expect(api.token, equals('saved_jwt_token_123'));
      expect(api.userEmail, equals('alice@example.com'));
      expect(api.userId, equals('user-uuid-alice'));

      // Updating token updates SharedPreferences
      await api.setToken('new_jwt_456', email: 'bob@example.com', userId: 'user-uuid-bob');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), equals('new_jwt_456'));
      expect(prefs.getString('user_email'), equals('bob@example.com'));
      expect(prefs.getString('user_id'), equals('user-uuid-bob'));

      // Clearing token clears SharedPreferences
      await api.setToken(null);
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('user_email'), isNull);
      expect(prefs.getString('user_id'), isNull);
    });

    test('Logout clears session, token, and user state completely', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'active_token',
        'user_email': 'active@example.com',
        'user_id': 'active_id',
      });

      final auth = AuthProvider();
      await auth.init();

      await auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(auth.errorMessage, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
    });
  });

  group('OnboardingScreen Email Identity Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget createTestApp(AuthProvider authProvider) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<StatementProvider>(create: (_) => StatementProvider()),
          ChangeNotifierProvider<TransactionProvider>(create: (_) => TransactionProvider()),
          ChangeNotifierProvider<CashExpenseProvider>(create: (_) => CashExpenseProvider()),
          ChangeNotifierProvider<AnalyticsProvider>(create: (_) => AnalyticsProvider()),
          ChangeNotifierProvider<ForecastProvider>(create: (_) => ForecastProvider()),
          ChangeNotifierProvider<ModelProvider>(create: (_) => ModelProvider()),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
    }

    testWidgets('Renders email identity input, continue button, and demo button', (tester) async {
      final auth = AuthProvider();
      await tester.pumpWidget(createTestApp(auth));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email to continue'), findsOneWidget);
      expect(find.byKey(const Key('email_identity_input')), findsOneWidget);
      expect(find.byKey(const Key('continue_with_email_button')), findsOneWidget);
      expect(find.byKey(const Key('guest_demo_button')), findsOneWidget);
    });

    testWidgets('Entering invalid email displays validation error message', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = AuthProvider();
      await tester.pumpWidget(createTestApp(auth));
      await tester.pumpAndSettle();

      // Enter invalid email
      final inputFinder = find.byKey(const Key('email_identity_input'));
      final buttonFinder = find.byKey(const Key('continue_with_email_button'));

      await tester.ensureVisible(inputFinder);
      await tester.enterText(inputFinder, 'invalid-email');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('When already identified, OnboardingScreen displays active session message and prefills email', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = AuthProvider();
      // Simulate identified user
      SharedPreferences.setMockInitialValues({
        'auth_token': 'restored_token_789',
        'user_email': 'alice@example.com',
        'user_id': 'alice-uuid',
      });
      await auth.init();

      await tester.pumpWidget(createTestApp(auth));
      await tester.pumpAndSettle();

      expect(find.text('Active Session Identified'), findsOneWidget);
      expect(find.textContaining('Identified as alice@example.com'), findsOneWidget);
    });
  });

  group('UserModel Serialization & Identification Models Tests', () {
    test('UserModel cleanly parses identity response json', () {
      final jsonMap = {
        'id': 'uuid-1234',
        'email': 'user@example.com',
        'is_guest': false,
        'created_at': '2026-10-04T12:00:00.000Z',
      };

      final user = UserModel.fromJson(jsonMap);
      expect(user.id, equals('uuid-1234'));
      expect(user.email, equals('user@example.com'));
      expect(user.isGuest, isFalse);
      expect(user.toJson()['email'], equals('user@example.com'));
    });
  });
}
