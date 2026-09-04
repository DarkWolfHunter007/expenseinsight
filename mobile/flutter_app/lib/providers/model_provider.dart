import 'package:flutter/material.dart';
import '../models/model_metrics_model.dart';
import '../services/api_service.dart';

class ModelProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  ModelMetricsModel? _metrics;
  bool _isLoading = false;
  bool _isRetraining = false;
  String? _errorMessage;

  ModelMetricsModel? get metrics => _metrics;
  bool get isLoading => _isLoading;
  bool get isRetraining => _isRetraining;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMetrics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _metrics = await _api.getModelMetrics();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> retrainModel() async {
    _isRetraining = true;
    notifyListeners();

    try {
      final success = await _api.retrainModel();
      if (success) {
        await fetchMetrics();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isRetraining = false;
      notifyListeners();
    }
  }
}
