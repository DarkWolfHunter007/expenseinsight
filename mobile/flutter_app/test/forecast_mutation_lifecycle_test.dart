import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/models/cash_expense_model.dart';
import 'package:flutter_app/models/forecast_model.dart';
import 'package:flutter_app/models/transaction_model.dart';
import 'package:flutter_app/providers/cash_expense_provider.dart';
import 'package:flutter_app/providers/forecast_provider.dart';
import 'package:flutter_app/providers/transaction_provider.dart';
import 'package:flutter_app/screens/forecast_screen.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:flutter_app/services/expense_sync_coordinator.dart';

class MockForecastApiService extends Fake implements ApiService {
  ForecastModel currentForecast = ForecastModel(
    status: 'low_history',
    confidenceLevel: 'Low',
    statusMessage: 'Preliminary estimate based on 1 month of data.',
    historicalMonthsCount: 1,
    totalForecast: 500.0,
    lowerBound: 375.0,
    upperBound: 625.0,
    next7DaysForecast: 117.0,
    next30DaysForecast: 500.0,
    categoryForecasts: {
      'Food': CategoryForecastDetail(
        predictedAmount: 500.0,
        lowerBound: 375.0,
        upperBound: 625.0,
        historicalRecentAvg: 500.0,
        lastMonthSpent: 500.0,
        trendPercentage: 0.0,
        historicalMonths: 1,
      ),
    },
    explanation: 'Expected total next month spending: ₹500.',
    explanationBullets: ['Expected next month spending: ₹500.'],
  );

  bool shouldThrowForecastError = false;
  bool shouldFailExpenseCreation = false;
  int getForecastCallCount = 0;

  @override
  Future<ForecastModel> getForecast() async {
    getForecastCallCount++;
    if (shouldThrowForecastError) {
      throw Exception('Network connection timed out');
    }
    return currentForecast;
  }

  @override
  Future<List<CashExpenseModel>> getCashExpenses({
    String? startDate,
    String? endDate,
    String? category,
    String? search,
    String sortBy = 'expense_date',
    String order = 'desc',
  }) async {
    return [];
  }

  @override
  Future<CashExpenseModel?> createCashExpense({
    required double amount,
    required String category,
    required String expenseDate,
    String? description,
    String paymentMethod = 'cash',
  }) async {
    if (shouldFailExpenseCreation) {
      return null;
    }
    // Simulate backend recalculation upon expense creation
    currentForecast = ForecastModel(
      status: 'ready',
      confidenceLevel: 'Medium',
      statusMessage: 'Forecast recalculated with new expense.',
      historicalMonthsCount: 1,
      totalForecast: currentForecast.totalForecast + amount,
      lowerBound: 400.0,
      upperBound: 800.0,
      next7DaysForecast: 180.0,
      next30DaysForecast: currentForecast.totalForecast + amount,
      categoryForecasts: {
        category: CategoryForecastDetail(
          predictedAmount: amount,
          lowerBound: amount * 0.75,
          upperBound: amount * 1.25,
          historicalRecentAvg: amount,
          lastMonthSpent: amount,
          trendPercentage: 0.0,
          historicalMonths: 1,
        ),
      },
      explanation: 'Updated forecast.',
      explanationBullets: ['Updated forecast bullets.'],
    );

    return CashExpenseModel(
      id: 'cash-new',
      userId: 'user-1',
      amount: amount,
      category: category,
      description: description,
      expenseDate: expenseDate,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<bool> deleteCashExpense(String id) async {
    currentForecast = ForecastModel(
      status: 'low_history',
      confidenceLevel: 'Low',
      statusMessage: 'Forecast recalculated after deletion.',
      historicalMonthsCount: 1,
      totalForecast: 200.0,
      lowerBound: 150.0,
      upperBound: 250.0,
      next7DaysForecast: 45.0,
      next30DaysForecast: 200.0,
      categoryForecasts: {},
      explanation: 'Forecast reverted.',
      explanationBullets: [],
    );
    return true;
  }

  @override
  Future<bool> updateTransactionCategory(
    String transactionId,
    String category, {
    bool applyToFuture = true,
  }) async {
    currentForecast = ForecastModel(
      status: 'ready',
      confidenceLevel: 'Medium',
      statusMessage: 'Forecast recalculated after category edit.',
      historicalMonthsCount: 1,
      totalForecast: 1000.0,
      lowerBound: 800.0,
      upperBound: 1200.0,
      next7DaysForecast: 230.0,
      next30DaysForecast: 1000.0,
      categoryForecasts: {
        category: CategoryForecastDetail(
          predictedAmount: 1000.0,
          lowerBound: 800.0,
          upperBound: 1200.0,
          historicalRecentAvg: 1000.0,
          lastMonthSpent: 1000.0,
          trendPercentage: 0.0,
          historicalMonths: 1,
        ),
      },
      explanation: 'Category updated.',
      explanationBullets: [],
    );

    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockForecastApiService mockApi;
  late ExpenseSyncCoordinator coordinator;
  late ForecastProvider forecastProv;
  late CashExpenseProvider cashProv;
  late TransactionProvider txnProv;

  setUp(() {
    mockApi = MockForecastApiService();
    coordinator = ExpenseSyncCoordinator();
    forecastProv = ForecastProvider(apiService: mockApi, coordinator: coordinator);
    cashProv = CashExpenseProvider(apiService: mockApi);
    txnProv = TransactionProvider(apiService: mockApi);
  });

  Widget buildTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ForecastProvider>.value(value: forecastProv),
        ChangeNotifierProvider<CashExpenseProvider>.value(value: cashProv),
        ChangeNotifierProvider<TransactionProvider>.value(value: txnProv),
      ],
      child: const MaterialApp(
        home: ForecastScreen(),
      ),
    );
  }

  group('Forecast Mutation & Screen Lifecycle Tests', () {
    testWidgets('1. Expense creation succeeds and automatically refreshes ForecastProvider', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Initial forecast should be ₹500
      expect(forecastProv.forecast?.totalForecast, 500.0);
      expect(mockApi.getForecastCallCount, 1);

      // Create a new expense of ₹300 Food
      final success = await cashProv.createCashExpense(
        amount: 300.0,
        category: 'Food',
        expenseDate: '2026-10-04',
      );
      expect(success, isTrue);

      await tester.pumpAndSettle();

      // ForecastProvider must immediately reflect the updated prediction (500 + 300 = 800)
      expect(forecastProv.forecast?.totalForecast, 800.0);
      expect(mockApi.getForecastCallCount, 2);
    });

    testWidgets('2. Prediction UI receives and renders updated prediction values', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Hero Card shows ₹500
      expect(find.text('₹500'), findsWidgets);

      // Add expense
      await cashProv.createCashExpense(
        amount: 500.0,
        category: 'Food',
        expenseDate: '2026-10-04',
      );

      await tester.pumpAndSettle();

      // Hero Card must now render ₹1,000 without manual user refresh
      expect(find.text('₹1,000'), findsWidgets);
    });

    testWidgets('3. Returning to Prediction screen after adding expense renders fresh data', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Add expense while on different screen or in background
      await cashProv.createCashExpense(
        amount: 250.0,
        category: 'Food',
        expenseDate: '2026-10-04',
      );

      // Rebuild / navigate back to screen
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(forecastProv.forecast?.totalForecast, 750.0);
      expect(forecastProv.isStale, isFalse);
    });

    testWidgets('4. Failed expense creation does not refresh forecast', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final initialCallCount = mockApi.getForecastCallCount;
      mockApi.shouldFailExpenseCreation = true;

      final success = await cashProv.createCashExpense(
        amount: 100.0,
        category: 'Food',
        expenseDate: '2026-10-04',
      );
      expect(success, isFalse);

      await tester.pumpAndSettle();

      // getForecast must NOT have been called again
      expect(mockApi.getForecastCallCount, initialCallCount);
    });

    testWidgets('5. Forecast error surfaces retry UI in ForecastScreen', (tester) async {
      mockApi.shouldThrowForecastError = true;
      forecastProv = ForecastProvider(apiService: mockApi, coordinator: coordinator);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Must display explicit failure state and Retry button
      expect(find.text('Failed to Load Forecast'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Clicking Retry calls fetchForecast again
      mockApi.shouldThrowForecastError = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Forecast'), findsNothing);
      expect(forecastProv.forecast, isNotNull);
    });

    testWidgets('6. Category update in TransactionProvider recalculates forecast', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Update transaction category
      await txnProv.updateCategory('t-1', 'Shopping');
      await tester.pumpAndSettle();

      expect(forecastProv.forecast?.categoryForecasts.containsKey('Shopping'), isTrue);
      expect(forecastProv.forecast?.totalForecast, 1000.0);
    });

    testWidgets('7. Expense deletion in CashExpenseProvider recalculates forecast', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await cashProv.deleteCashExpense('cash-1');
      await tester.pumpAndSettle();

      expect(forecastProv.forecast?.totalForecast, 200.0);
    });
  });
}
