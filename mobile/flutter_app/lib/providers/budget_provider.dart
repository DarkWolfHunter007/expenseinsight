import 'package:flutter/foundation.dart';

import '../models/budget_settings_model.dart';
import '../services/api_service.dart';
import '../services/expense_sync_coordinator.dart';

class BudgetProvider extends ChangeNotifier {
  final ApiService _api;
  final ExpenseSyncCoordinator _coordinator;

  BudgetProvider({ApiService? apiService, ExpenseSyncCoordinator? coordinator})
      : _api = apiService ?? ApiService(),
        _coordinator = coordinator ?? ExpenseSyncCoordinator() {
    _coordinator.addSessionResetListener(clear);
  }

  BudgetSettingsModel _settings = const BudgetSettingsModel();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  BudgetSettingsModel get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  void clear() {
    _settings = const BudgetSettingsModel();
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _settings = await _api.getBudgetSettings();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves the settings and returns true on success. Callers refresh analytics afterwards.
  Future<bool> save(BudgetSettingsModel settings) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _settings = await _api.saveBudgetSettings(settings);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _coordinator.removeSessionResetListener(clear);
    super.dispose();
  }
}
