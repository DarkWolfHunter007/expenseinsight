import 'package:flutter/material.dart';
import '../models/forecast_model.dart';
import '../services/api_service.dart';
import '../services/expense_sync_coordinator.dart';

class ForecastProvider extends ChangeNotifier {
  final ApiService _api;
  final ExpenseSyncCoordinator _coordinator;

  ForecastModel? _forecast;
  bool _isLoading = false;
  bool _isStale = false;
  String? _errorMessage;

  ForecastProvider({
    ApiService? apiService,
    ExpenseSyncCoordinator? coordinator,
  })  : _api = apiService ?? ApiService(),
        _coordinator = coordinator ?? ExpenseSyncCoordinator() {
    _coordinator.addListener(_onExpenseMutated);
  }

  ForecastModel? get forecast => _forecast;
  bool get isLoading => _isLoading;
  bool get isStale => _isStale;
  String? get errorMessage => _errorMessage;

  void _onExpenseMutated() {
    invalidate(autoRefresh: true);
  }

  /// Marks forecast state as stale and triggers background recalculation if autoRefresh is true.
  Future<void> invalidate({bool autoRefresh = true}) async {
    _isStale = true;
    if (autoRefresh) {
      await fetchForecast();
    } else {
      notifyListeners();
    }
  }

  Future<void> fetchForecast() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.getForecast();
      _forecast = res;
      _isStale = false;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _coordinator.removeListener(_onExpenseMutated);
    super.dispose();
  }
}
