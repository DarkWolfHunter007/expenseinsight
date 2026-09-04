import 'package:flutter/foundation.dart';

class ApiConstants {
  // Default base URL for local development (handles Web/Windows and Android emulator)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String guest = '/auth/guest';
  static const String me = '/auth/me';

  // Statement endpoints
  static const String uploadStatements = '/statements/upload';
  static const String listStatements = '/statements';
  static const String statementStatus = '/statements';
  static const String seedSampleStatement = '/statements/seed-sample';

  // Transactions endpoints
  static const String transactions = '/transactions';
  static const String uncertainTransactions = '/transactions/uncertain';
  static const String updateCategory = '/transactions';

  // Analytics endpoints
  static const String analyticsSummary = '/analytics/summary';
  static const String monthlySpending = '/analytics/monthly';
  static const String categorySpending = '/analytics/categories';
  static const String merchantSpending = '/analytics/merchants';
  static const String recurringExpenses = '/analytics/recurring';

  // Forecast endpoints
  static const String forecast = '/forecast';

  // Model endpoints
  static const String modelStatus = '/model/status';
  static const String modelMetrics = '/model/metrics';
  static const String modelCompare = '/model/compare';
  static const String modelRetrain = '/model/retrain';
}
