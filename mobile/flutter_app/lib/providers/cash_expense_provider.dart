import 'package:flutter/foundation.dart';

import '../models/cash_expense_model.dart';
import '../services/api_service.dart';
import '../services/expense_sync_coordinator.dart';

class CashExpenseProvider extends ChangeNotifier {
  final ApiService _apiService;

  CashExpenseProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<CashExpenseModel> _cashExpenses = [];
  bool _isLoading = false;
  String? _errorMessage;

  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'expense_date';
  String _sortOrder = 'desc';
  String? _startDate;
  String? _endDate;

  List<CashExpenseModel> get cashExpenses => _cashExpenses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  String get sortOrder => _sortOrder;
  String? get startDate => _startDate;
  String? get endDate => _endDate;

  double get totalCashSpending {
    return _cashExpenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> fetchCashExpenses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _apiService.getCashExpenses(
        startDate: _startDate,
        endDate: _endDate,
        category: _selectedCategory,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: _sortBy,
        order: _sortOrder,
      );
      _cashExpenses = results;
    } catch (e) {
      _errorMessage = 'Failed to load cash expenses: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCashExpense({
    required double amount,
    required String category,
    required String expenseDate,
    String? description,
    String paymentMethod = 'cash',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newExpense = await _apiService.createCashExpense(
        amount: amount,
        category: category,
        expenseDate: expenseDate,
        description: description,
        paymentMethod: paymentMethod,
      );

      if (newExpense != null) {
        await fetchCashExpenses();
        ExpenseSyncCoordinator().notifyExpenseMutated();
        return true;
      } else {
        _errorMessage = 'Failed to create cash expense.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateCashExpense({
    required String id,
    double? amount,
    String? category,
    String? expenseDate,
    String? description,
    String? paymentMethod,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _apiService.updateCashExpense(
        id: id,
        amount: amount,
        category: category,
        expenseDate: expenseDate,
        description: description,
        paymentMethod: paymentMethod,
      );

      if (updated != null) {
        await fetchCashExpenses();
        ExpenseSyncCoordinator().notifyExpenseMutated();
        return true;
      } else {
        _errorMessage = 'Failed to update cash expense.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCashExpense(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _apiService.deleteCashExpense(id);
      if (success) {
        _cashExpenses.removeWhere((item) => item.id == id);
        notifyListeners();
        ExpenseSyncCoordinator().notifyExpenseMutated();
        return true;
      } else {
        _errorMessage = 'Failed to delete cash expense.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCategoryFilter(String? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    fetchCashExpenses();
  }

  void setDateRangeFilter(String? start, String? end) {
    _startDate = start;
    _endDate = end;
    fetchCashExpenses();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchCashExpenses();
  }

  void setSorting(String sortBy, String order) {
    _sortBy = sortBy;
    _sortOrder = order;
    fetchCashExpenses();
  }
}
