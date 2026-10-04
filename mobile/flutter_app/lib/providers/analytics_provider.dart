import 'package:flutter/material.dart';
import '../models/analytics_model.dart';
import '../services/api_service.dart';
import '../services/expense_sync_coordinator.dart';

class AnalyticsProvider extends ChangeNotifier {
  final ApiService _api;
  final ExpenseSyncCoordinator _coordinator;

  AnalyticsProvider({ApiService? apiService, ExpenseSyncCoordinator? coordinator})
      : _api = apiService ?? ApiService(),
        _coordinator = coordinator ?? ExpenseSyncCoordinator() {
    _coordinator.addSessionResetListener(clear);
  }

  AnalyticsSummaryModel? _summary;
  List<MonthlySpendingItem> _monthlySpending = [];
  bool _isLoading = false;
  String? _errorMessage;

  AnalyticsSummaryModel? get summary => _summary;
  List<MonthlySpendingItem> get monthlySpending => _monthlySpending;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Clears in-memory analytics data on logout/account switch (Phase 12).
  void clear() {
    _summary = null;
    _monthlySpending = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchAnalytics({String? startDate, String? endDate}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _api.getAnalyticsSummary(startDate: startDate, endDate: endDate);
      _monthlySpending = await _api.getMonthlySpending(startDate: startDate, endDate: endDate);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _coordinator.removeSessionResetListener(clear);
    super.dispose();
  }
}
