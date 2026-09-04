import 'package:flutter/material.dart';
import '../models/forecast_model.dart';
import '../services/api_service.dart';

class ForecastProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  ForecastModel? _forecast;
  bool _isLoading = false;
  String? _errorMessage;

  ForecastModel? get forecast => _forecast;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchForecast() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _forecast = await _api.getForecast();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
