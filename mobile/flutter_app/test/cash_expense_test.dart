import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/cash_expense_model.dart';
import 'package:flutter_app/models/analytics_model.dart';
import 'package:flutter_app/models/transaction_model.dart';
import 'package:flutter_app/providers/cash_expense_provider.dart';
import 'package:flutter_app/providers/transaction_provider.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:flutter_app/widgets/add_edit_cash_expense_dialog.dart';
import 'package:provider/provider.dart';

class FakeApiService extends Fake implements ApiService {
  List<CashExpenseModel> fakeExpenses = [
    CashExpenseModel(
      id: 'test-1',
      userId: 'user-1',
      amount: 250.0,
      category: 'Food',
      description: 'Lunch',
      expenseDate: '2026-09-27',
      createdAt: DateTime.parse('2026-09-27T10:00:00Z'),
      updatedAt: DateTime.parse('2026-09-27T10:00:00Z'),
    ),
    CashExpenseModel(
      id: 'test-2',
      userId: 'user-1',
      amount: 100.0,
      category: 'Transport',
      description: 'Auto',
      expenseDate: '2026-09-26',
      createdAt: DateTime.parse('2026-09-26T10:00:00Z'),
      updatedAt: DateTime.parse('2026-09-26T10:00:00Z'),
    ),
  ];

  @override
  Future<List<CashExpenseModel>> getCashExpenses({
    String? startDate,
    String? endDate,
    String? category,
    String? search,
    String sortBy = 'expense_date',
    String order = 'desc',
  }) async {
    return List.from(fakeExpenses);
  }

  @override
  Future<CashExpenseModel?> createCashExpense({
    required double amount,
    required String category,
    required String expenseDate,
    String? description,
    String paymentMethod = 'cash',
  }) async {
    final newExp = CashExpenseModel(
      id: 'test-new',
      userId: 'user-1',
      amount: amount,
      category: category,
      description: description,
      expenseDate: expenseDate,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    fakeExpenses.add(newExp);
    return newExp;
  }

  @override
  Future<CashExpenseModel?> updateCashExpense({
    required String id,
    double? amount,
    String? category,
    String? expenseDate,
    String? description,
    String? paymentMethod,
  }) async {
    final idx = fakeExpenses.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final existing = fakeExpenses[idx];
      final updated = CashExpenseModel(
        id: existing.id,
        userId: existing.userId,
        amount: amount ?? existing.amount,
        category: category ?? existing.category,
        description: description ?? existing.description,
        expenseDate: expenseDate ?? existing.expenseDate,
        paymentMethod: paymentMethod ?? existing.paymentMethod,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      fakeExpenses[idx] = updated;
      return updated;
    }
    return null;
  }

  @override
  Future<bool> deleteCashExpense(String id) async {
    fakeExpenses.removeWhere((e) => e.id == id);
    return true;
  }

  List<TransactionModel> fakeTransactions = [];

  @override
  Future<List<TransactionModel>> getTransactions({
    String? category,
    String? search,
    String? source,
    bool? needsReview,
    String? sortBy,
    String? order,
    int? limit,
    int? offset,
  }) async {
    return fakeTransactions.where((t) {
      if (source != null && source.isNotEmpty && source != 'all') {
        if (source == 'bank' && !t.isBank) return false;
        if (source == 'upi' && !t.isUpi) return false;
        if (source == 'cash' && !t.isCash) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<List<UncertainReviewModel>> getUncertainTransactions() async {
    return [];
  }

  @override
  Future<bool> updateTransactionCategory(String transactionId, String newCategory, {bool applyToFuture = true}) async {
    return true;
  }
}

void main() {
  group('CashExpenseModel & Analytics Serialization Tests', () {
    test('CashExpenseModel serializes and deserializes cleanly', () {
      final json = {
        'id': 'uuid-1234',
        'user_id': 'user-5678',
        'amount': 450.50,
        'category': 'Entertainment',
        'description': 'Movie ticket',
        'expense_date': '2026-09-27',
        'created_at': '2026-09-27T12:00:00Z',
        'updated_at': '2026-09-27T12:00:00Z',
      };

      final model = CashExpenseModel.fromJson(json);
      expect(model.id, 'uuid-1234');
      expect(model.userId, 'user-5678');
      expect(model.amount, 450.50);
      expect(model.category, 'Entertainment');
      expect(model.description, 'Movie ticket');
      expect(model.expenseDate, '2026-09-27');

      final serialized = model.toJson();
      expect(serialized['amount'], 450.50);
      expect(serialized['category'], 'Entertainment');
      expect(serialized['expense_date'], '2026-09-27');
    });

    test('AnalyticsSummaryModel correctly reads bank, cash, and total spending', () {
      final json = {
        'total_expense': 138500.0,
        'total_income': 200000.0,
        'total_transfers': 0.0,
        'net_savings': 61500.0,
        'this_month_spent': 22700.0,
        'previous_month_spent': 20000.0,
        'month_over_month_change_pct': 13.5,
        'average_daily_spend': 756.6,
        'total_transactions_count': 42,
        'bank_spending': 120000.0,
        'cash_spending': 18500.0,
        'total_spending': 138500.0,
        'categories_breakdown': [
          {
            'category': 'Food',
            'amount': 3300.0,
            'percentage': 2.38,
            'bank_amount': 2500.0,
            'cash_amount': 800.0,
            'transaction_count': 8,
          }
        ],
        'top_merchants': [],
        'recurring_expenses': [],
      };

      final summary = AnalyticsSummaryModel.fromJson(json);
      expect(summary.bankSpending, 120000.0);
      expect(summary.cashSpending, 18500.0);
      expect(summary.totalSpending, 138500.0);

      expect(summary.categoriesBreakdown.first.bankAmount, 2500.0);
      expect(summary.categoriesBreakdown.first.cashAmount, 800.0);
      expect(summary.categoriesBreakdown.first.amount, 3300.0);
    });

    test('MonthlySpendingItem deserializes bank and cash expenses', () {
      final json = {
        'month': '2026-06',
        'month_name': 'June 2026',
        'total_expense': 23500.0,
        'total_income': 30000.0,
        'net_savings': 6500.0,
        'transaction_count': 12,
        'bank_expense': 20000.0,
        'cash_expense': 3500.0,
      };

      final monthly = MonthlySpendingItem.fromJson(json);
      expect(monthly.bankExpense, 20000.0);
      expect(monthly.cashExpense, 3500.0);
      expect(monthly.totalExpense, 23500.0);
    });
  });

  group('CashExpenseProvider State Management Tests', () {
    test('Loads expenses, calculates totals, and handles CRUD operations', () async {
      final fakeApi = FakeApiService();
      final provider = CashExpenseProvider(apiService: fakeApi);

      expect(provider.cashExpenses, isEmpty);
      expect(provider.totalCashSpending, 0.0);

      // 1. Fetch expenses
      await provider.fetchCashExpenses();
      expect(provider.cashExpenses.length, 2);
      expect(provider.totalCashSpending, 350.0); // 250 + 100

      // 2. Add expense
      final added = await provider.createCashExpense(
        amount: 500.0,
        category: 'Shopping',
        expenseDate: '2026-09-25',
        description: 'Clothes',
      );
      expect(added, isTrue);
      expect(provider.cashExpenses.length, 3);
      expect(provider.totalCashSpending, 850.0);

      // 3. Edit expense
      final edited = await provider.updateCashExpense(
        id: 'test-1',
        amount: 300.0,
        category: 'Food',
        expenseDate: '2026-09-27',
      );
      expect(edited, isTrue);
      final updatedItem = provider.cashExpenses.firstWhere((e) => e.id == 'test-1');
      expect(updatedItem.amount, 300.0);
      expect(provider.totalCashSpending, 900.0); // 300 + 100 + 500

      // 4. Delete expense
      final deleted = await provider.deleteCashExpense('test-2');
      expect(deleted, isTrue);
      expect(provider.cashExpenses.length, 2);
      expect(provider.cashExpenses.any((e) => e.id == 'test-2'), isFalse);
      expect(provider.totalCashSpending, 800.0);
    });
  });

  group('AddEditCashExpenseDialog Widget Tests', () {
    testWidgets('Renders form fields and validates positive amount', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeApi = FakeApiService();
      final provider = CashExpenseProvider(apiService: fakeApi);

      await tester.pumpWidget(
        ChangeNotifierProvider<CashExpenseProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => AddEditCashExpenseDialog.show(context),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check dialog elements
      expect(find.text('Add Expense'), findsWidgets);
      expect(find.text('Payment Source *'), findsOneWidget);
      expect(find.text('Amount *'), findsOneWidget);
      expect(find.text('Category *'), findsOneWidget);
      expect(find.text('Date *'), findsOneWidget);

      // Submit empty form -> should show error
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Expense'));
      await tester.pumpAndSettle();
      expect(find.text('Amount is required.'), findsOneWidget);

      // Enter invalid zero amount -> should show error
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Expense'));
      await tester.pumpAndSettle();
      expect(find.text('Amount must be greater than zero.'), findsOneWidget);

      // Enter valid amount
      await tester.enterText(find.byType(TextFormField).first, '150');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Expense'));
      await tester.pumpAndSettle();

      // Dialog should close and item should be added
      expect(find.text('Payment Source *'), findsNothing);
      expect(provider.cashExpenses.any((e) => e.amount == 150.0), isTrue);
    });
  });

  group('Structured Payment Methods & Transaction Filter Tests', () {
    test('CashExpenseModel cleanly parses payment_method and legacy prefixes', () {
      // 1. Structured payment_method
      final bankJson = {
        'id': 'b-1',
        'user_id': 'u-1',
        'amount': 500.0,
        'category': 'Rent',
        'expense_date': '2026-09-20',
        'description': 'Office bill',
        'payment_method': 'bank',
        'created_at': '2026-09-20T10:00:00Z',
      };
      final bankModel = CashExpenseModel.fromJson(bankJson);
      expect(bankModel.paymentMethod, 'bank');
      expect(bankModel.description, 'Office bill');
      expect(bankModel.toJson()['payment_method'], 'bank');

      // 2. Legacy [UPI] prefix backward compatibility
      final upiLegacy = {
        'id': 'u-1',
        'user_id': 'u-1',
        'amount': 300.0,
        'category': 'Food',
        'expense_date': '2026-09-21',
        'description': '[UPI] Chai snacks',
        'created_at': '2026-09-21T10:00:00Z',
      };
      final upiModel = CashExpenseModel.fromJson(upiLegacy);
      expect(upiModel.paymentMethod, 'upi');
      expect(upiModel.description, 'Chai snacks');

      // 3. Cash default
      final cashJson = {
        'id': 'c-1',
        'user_id': 'u-1',
        'amount': 200.0,
        'category': 'Transit',
        'expense_date': '2026-09-22',
        'description': 'Auto',
        'created_at': '2026-09-22T10:00:00Z',
      };
      final cashModel = CashExpenseModel.fromJson(cashJson);
      expect(cashModel.paymentMethod, 'cash');
      expect(cashModel.description, 'Auto');
    });

    test('TransactionModel correctly determines source classification and flags', () {
      final bankTx = TransactionModel(
        id: 't-bank',
        userId: 'u-1',
        date: '2026-09-20',
        rawDescription: 'Office bill',
        merchant: 'Bank Transfer',
        normalizedMerchant: 'manual_bank',
        amount: 500.0,
        currency: 'INR',
        transactionType: 'bank_expense',
        crDr: 'DR',
        category: 'Rent',
        categoryConfidence: 1.0,
        categorySource: 'bank_manual',
        needsReview: false,
        isDuplicate: false,
        createdAt: DateTime.now(),
        sourceType: 'bank',
        paymentMethod: 'bank',
      );
      expect(bankTx.isBank, isTrue);
      expect(bankTx.isUpi, isFalse);
      expect(bankTx.isCash, isFalse);
      expect(bankTx.isManual, isTrue);

      final upiTx = TransactionModel(
        id: 't-upi',
        userId: 'u-1',
        date: '2026-09-21',
        rawDescription: 'Chai snacks',
        merchant: 'UPI Payment',
        normalizedMerchant: 'manual_upi',
        amount: 300.0,
        currency: 'INR',
        transactionType: 'upi_expense',
        crDr: 'DR',
        category: 'Food',
        categoryConfidence: 1.0,
        categorySource: 'upi_manual',
        needsReview: false,
        isDuplicate: false,
        createdAt: DateTime.now(),
        sourceType: 'upi',
        paymentMethod: 'upi',
      );
      expect(upiTx.isUpi, isTrue);
      expect(upiTx.isBank, isFalse);
      expect(upiTx.isCash, isFalse);
      expect(upiTx.isManual, isTrue);

      final cashTx = TransactionModel(
        id: 't-cash',
        userId: 'u-1',
        date: '2026-09-22',
        rawDescription: 'Auto fare',
        merchant: 'Cash Payment',
        normalizedMerchant: 'cash_payment',
        amount: 200.0,
        currency: 'INR',
        transactionType: 'cash_expense',
        crDr: 'DR',
        category: 'Transit',
        categoryConfidence: 1.0,
        categorySource: 'cash_manual',
        needsReview: false,
        isDuplicate: false,
        createdAt: DateTime.now(),
        sourceType: 'cash',
        paymentMethod: 'cash',
      );
      expect(cashTx.isCash, isTrue);
      expect(cashTx.isUpi, isFalse);
      expect(cashTx.isBank, isFalse);
      expect(cashTx.isManual, isTrue);
    });

    test('TransactionProvider correctly filters by source (All, Bank, UPI, Cash)', () async {
      final fakeApi = FakeApiService();
      final bankTx = TransactionModel(
        id: 't-bank',
        userId: 'u-1',
        date: '2026-09-20',
        rawDescription: 'Office bill',
        merchant: 'Bank Transfer',
        normalizedMerchant: 'manual_bank',
        amount: 500.0,
        currency: 'INR',
        transactionType: 'bank_expense',
        crDr: 'DR',
        category: 'Rent',
        categoryConfidence: 1.0,
        categorySource: 'bank_manual',
        needsReview: false,
        isDuplicate: false,
        createdAt: DateTime.now(),
        sourceType: 'bank',
        paymentMethod: 'bank',
      );
      final upiTx = TransactionModel(
        id: 't-upi',
        userId: 'u-1',
        date: '2026-09-21',
        rawDescription: 'Chai snacks',
        merchant: 'UPI Payment',
        normalizedMerchant: 'manual_upi',
        amount: 300.0,
        currency: 'INR',
        transactionType: 'upi_expense',
        crDr: 'DR',
        category: 'Food',
        categoryConfidence: 1.0,
        categorySource: 'upi_manual',
        needsReview: false,
        isDuplicate: false,
        createdAt: DateTime.now(),
        sourceType: 'upi',
        paymentMethod: 'upi',
      );
      final cashTx = TransactionModel(
        id: 't-cash',
        userId: 'u-1',
        date: '2026-09-22',
        rawDescription: 'Auto fare',
        merchant: 'Cash Payment',
        normalizedMerchant: 'cash_payment',
        amount: 200.0,
        currency: 'INR',
        transactionType: 'cash_expense',
        crDr: 'DR',
        category: 'Transit',
        categoryConfidence: 1.0,
        categorySource: 'cash_manual',
        needsReview: false,
        isDuplicate: false,
        createdAt: DateTime.now(),
        sourceType: 'cash',
        paymentMethod: 'cash',
      );
      fakeApi.fakeTransactions = [bankTx, upiTx, cashTx];

      final provider = TransactionProvider(apiService: fakeApi);
      await provider.fetchTransactions();

      expect(provider.transactions.length, 3);

      provider.setSourceFilter('Bank');
      await Future.delayed(Duration.zero);
      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.id, 't-bank');

      provider.setSourceFilter('UPI');
      await Future.delayed(Duration.zero);
      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.id, 't-upi');

      provider.setSourceFilter('Cash');
      await Future.delayed(Duration.zero);
      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.id, 't-cash');

      provider.setSourceFilter('All');
      await Future.delayed(Duration.zero);
      expect(provider.transactions.length, 3);
    });

    test('TransactionProvider updateCategory preserves canonical sourceType and paymentMethod', () async {
      final fakeApi = FakeApiService();
      final upiTx = TransactionModel(
        id: 't-upi-statement',
        userId: 'u-1',
        statementId: 'stmt-1',
        date: '2026-09-21',
        rawDescription: 'UPI/DR/123/SWIGGY',
        merchant: 'Swiggy',
        normalizedMerchant: 'swiggy',
        amount: 350.0,
        currency: 'INR',
        transactionType: 'expense',
        crDr: 'DR',
        category: 'Other',
        categoryConfidence: 0.6,
        categorySource: 'ml',
        needsReview: true,
        isDuplicate: false,
        createdAt: DateTime.now(),
        sourceType: 'upi',
        paymentMethod: 'upi',
      );
      fakeApi.fakeTransactions = [upiTx];
      final provider = TransactionProvider(apiService: fakeApi);
      await provider.fetchTransactions();

      expect(provider.transactions.first.sourceType, 'upi');
      expect(provider.transactions.first.isUpi, isTrue);

      await provider.updateCategory('t-upi-statement', 'Food');

      final updated = provider.rawTransactions.firstWhere((t) => t.id == 't-upi-statement');
      expect(updated.category, 'Food');
      expect(updated.sourceType, 'upi', reason: 'CRITICAL: Category update must preserve sourceType!');
      expect(updated.paymentMethod, 'upi');
      expect(updated.isUpi, isTrue);
      expect(updated.isBank, isFalse);
    });
  });
}
