import 'package:flutter/material.dart';
import '../models/analytics_model.dart';
import '../services/api_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  AnalyticsSummaryModel? _summary;
  List<MonthlySpendingItem> _monthlySpending = [];
  bool _isLoading = false;
  String? _errorMessage;

  AnalyticsSummaryModel? get summary => _summary;
  List<MonthlySpendingItem> get monthlySpending => _monthlySpending;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAnalytics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _api.getAnalyticsSummary();
      _monthlySpending = await _api.getMonthlySpending();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
