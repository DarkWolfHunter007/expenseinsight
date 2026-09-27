import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

class TransactionProvider extends ChangeNotifier {
  final ApiService _api;
  TransactionProvider({ApiService? apiService}) : _api = apiService ?? ApiService();
  List<TransactionModel> _transactions = [];
  List<UncertainReviewModel> _uncertainTransactions = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedSource = 'All';
  String _searchQuery = '';
  bool _needsReviewOnly = false;
  String _sortBy = 'date';
  String _order = 'desc';

  List<TransactionModel> get transactions => _filteredTransactions();
  List<TransactionModel> get rawTransactions => _transactions;
  List<UncertainReviewModel> get uncertainTransactions => _uncertainTransactions;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get selectedSource => _selectedSource;
  String get searchQuery => _searchQuery;
  bool get needsReviewOnly => _needsReviewOnly;
  String get sortBy => _sortBy;
  String get order => _order;

  List<TransactionModel> _filteredTransactions() {
    return _transactions.where((t) {
      // Source filter (All, Bank, UPI, Cash)
      final src = _selectedSource.toLowerCase();
      if (src == 'bank' && !t.isBank) {
        return false;
      }
      if (src == 'upi' && !t.isUpi) {
        return false;
      }
      if (src == 'cash' && !t.isCash) {
        return false;
      }
      // Category filter
      if (_selectedCategory != 'All' &&
          t.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      // Needs review filter
      if (_needsReviewOnly && !t.needsReview) {
        return false;
      }
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchMerchant = t.merchant.toLowerCase().contains(q);
        final matchDesc = t.rawDescription.toLowerCase().contains(q);
        final matchCat = t.category.toLowerCase().contains(q);
        if (!matchMerchant && !matchDesc && !matchCat) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSourceFilter(String source) {
    _selectedSource = source;
    notifyListeners();
    fetchTransactions();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setNeedsReviewOnly(bool value) {
    _needsReviewOnly = value;
    notifyListeners();
  }

  void setSorting(String sortBy, String order) {
    _sortBy = sortBy;
    _order = order;
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _api.getTransactions(
        category: _selectedCategory != 'All' ? _selectedCategory : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        source: _selectedSource.toLowerCase() != 'all' ? _selectedSource.toLowerCase() : null,
        needsReview: _needsReviewOnly ? true : null,
        sortBy: _sortBy,
        order: _order,
      );
      _uncertainTransactions = await _api.getUncertainTransactions();
    } catch (e) {
      debugPrint('Error in fetchTransactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCategory(String transactionId, String newCategory, {bool applyToFuture = true}) async {
    // Optimistic UI update
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index != -1) {
      final old = _transactions[index];
      _transactions[index] = TransactionModel(
        id: old.id,
        userId: old.userId,
        statementId: old.statementId,
        date: old.date,
        rawDescription: old.rawDescription,
        cleanDescription: old.cleanDescription,
        merchant: old.merchant,
        normalizedMerchant: old.normalizedMerchant,
        amount: old.amount,
        currency: old.currency,
        transactionType: old.transactionType,
        crDr: old.crDr,
        balance: old.balance,
        referenceNumber: old.referenceNumber,
        category: newCategory,
        categoryConfidence: 1.0,
        categorySource: 'manual_user',
        needsReview: false,
        isDuplicate: old.isDuplicate,
        createdAt: old.createdAt,
      );
      // Remove from uncertain deck if present
      _uncertainTransactions.removeWhere((u) => u.transactionId == transactionId);
      notifyListeners();
    }

    await _api.updateTransactionCategory(transactionId, newCategory, applyToFuture: applyToFuture);
  }
}
