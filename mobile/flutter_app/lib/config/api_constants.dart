import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _envBaseUrl = String.fromEnvironment('API_URL', defaultValue: '');
  static String? _customBaseUrl;

  /// Sets or clears a runtime custom API base URL (e.g. VS Code devtunnels / ngrok)
  static void setCustomBaseUrl(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      String clean = url.trim();
      if (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      _customBaseUrl = clean;
    } else {
      _customBaseUrl = null;
    }
  }

  // Default base URL for local development (handles Web/Windows, Android emulator, VS Code tunnels)
  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl.endsWith('/') ? _envBaseUrl.substring(0, _envBaseUrl.length - 1) : _envBaseUrl;
    }
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') {
        return origin;
      }
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

  // Cash Expenses endpoints
  static const String cashExpenses = '/cash-expenses';

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
