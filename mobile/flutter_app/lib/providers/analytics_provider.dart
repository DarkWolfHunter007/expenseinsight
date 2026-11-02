import 'package:flutter/material.dart';
import '../models/analytics_model.dart';
import '../models/dashboard_range.dart';
import '../services/api_service.dart';
import '../services/budget_notification_service.dart';
import '../services/expense_sync_coordinator.dart';

class AnalyticsProvider extends ChangeNotifier {
  final ApiService _api;
  final ExpenseSyncCoordinator _coordinator;

  AnalyticsProvider({ApiService? apiService, ExpenseSyncCoordinator? coordinator})
      : _api = apiService ?? ApiService(),
        _coordinator = coordinator ?? ExpenseSyncCoordinator() {
    _coordinator.addSessionResetListener(clear);
  }

  /// Called after a summary has loaded (the notification provider uses it to record anything newly due).
  VoidCallback? onSummaryLoaded;

  AnalyticsSummaryModel? _summary;
  List<MonthlySpendingItem> _monthlySpending = [];
  List<MonthlySpendingItem> _allMonthlySpending = [];
  DashboardRange _range = DashboardRange.statement;
  String? _activeStart;
  String? _activeEnd;
  bool _isLoading = false;
  String? _errorMessage;

  AnalyticsSummaryModel? get summary => _summary;
  List<MonthlySpendingItem> get monthlySpending => _monthlySpending;

  /// Every month with data, whatever range the spending figures are narrowed to (for the trend chart).
  List<MonthlySpendingItem> get allMonthlySpending => _allMonthlySpending.isNotEmpty ? _allMonthlySpending : _monthlySpending;
  DashboardRange get range => _range;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Clears in-memory analytics data on logout/account switch (Phase 12).
  void clear() {
    _summary = null;
    _monthlySpending = [];
    _allMonthlySpending = [];
    _range = DashboardRange.statement;
    _activeStart = null;
    _activeEnd = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchAnalytics({String? startDate, String? endDate}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // An explicit period replaces the active one; a plain refresh keeps the period the user picked
    if (startDate != null || endDate != null) {
      _activeStart = startDate;
      _activeEnd = endDate;
    }
    final start = _activeStart;
    final end = _activeEnd;

    try {
      _summary = await _api.getAnalyticsSummary(startDate: start, endDate: end);
      _monthlySpending = await _api.getMonthlySpending(startDate: start, endDate: end);
      if (start == null && end == null) _allMonthlySpending = _monthlySpending;
      // Budget alerts do not depend on the period the spending figures are narrowed to
      if (_summary != null) {
        BudgetNotificationService.instance.maybeNotify(_summary!);
        onSummaryLoaded?.call();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Narrows the spending figures to a period anchored to the newest month that has data.
  Future<void> setRange(DashboardRange range) async {
    _range = range;
    final months = allMonthlySpending;
    final dates = months.isEmpty ? null : range.datesFor(months.last.month);
    _activeStart = dates?.$1;
    _activeEnd = dates?.$2;
    await fetchAnalytics();
  }

  @override
  void dispose() {
    _coordinator.removeSessionResetListener(clear);
    super.dispose();
  }
}
