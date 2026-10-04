import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_constants.dart';
import '../models/analytics_model.dart';
import '../models/cash_expense_model.dart';
import '../models/forecast_model.dart';
import '../models/model_metrics_model.dart';
import '../models/statement_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import 'mock_data_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;
  String? _userEmail;
  String? _userId;
  bool? _isGuest;
  bool isUsingMockFallback = false;

  String? get token => _token;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  bool get isGuest => _isGuest ?? false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userEmail = prefs.getString('user_email');
    _userId = prefs.getString('user_id');
    _isGuest = prefs.getBool('user_is_guest');
    final savedUrl = prefs.getString('custom_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      ApiConstants.setCustomBaseUrl(savedUrl);
    }
  }

  Future<void> updateBaseUrl(String? newUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (newUrl != null && newUrl.trim().isNotEmpty) {
      ApiConstants.setCustomBaseUrl(newUrl);
      await prefs.setString('custom_base_url', ApiConstants.baseUrl);
    } else {
      ApiConstants.setCustomBaseUrl(null);
      await prefs.remove('custom_base_url');
    }
  }

  Future<void> setToken(String? token, {String? email, String? userId, bool? isGuest}) async {
    _token = token;
    _userEmail = email;
    _userId = userId;
    _isGuest = isGuest;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
    if (email != null) {
      await prefs.setString('user_email', email);
    } else if (token == null) {
      await prefs.remove('user_email');
    }
    if (userId != null) {
      await prefs.setString('user_id', userId);
    } else if (token == null) {
      await prefs.remove('user_id');
    }
    if (isGuest != null) {
      await prefs.setBool('user_is_guest', isGuest);
    } else if (token == null) {
      await prefs.remove('user_is_guest');
    }
  }

  Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Tunnel-Skip-Anti-Abuse-Header': 'true',
      'ngrok-skip-browser-warning': 'true',
    };
    if (_token != null && _token!.isNotEmpty) {
      map['Authorization'] = 'Bearer $_token';
    }
    return map;
  }

  // ----------------- Auth -----------------

  Future<UserModel?> loginGuest() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.guest}');
      final response = await http.post(url, headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'];
        final user = UserModel.fromJson(data['user']);
        await setToken(token, email: user.email, userId: user.id, isGuest: user.isGuest);
        isUsingMockFallback = false;
        return user;
      }
    } catch (e) {
      debugPrint('API Error (loginGuest), falling back to mock: $e');
    }
    isUsingMockFallback = true;
    return MockDataService.mockUser;
  }

  Future<UserModel?> login(String email, String password) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');
      final response = await http
          .post(url, headers: _headers, body: json.encode({'email': email, 'password': password}))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'];
        final user = UserModel.fromJson(data['user']);
        await setToken(token, email: user.email, userId: user.id, isGuest: user.isGuest);
        isUsingMockFallback = false;
        return user;
      }
    } catch (e) {
      debugPrint('API Error (login): $e');
    }
    return null;
  }

  Future<UserModel?> identifyWithEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.identify}');
      final response = await http
          .post(
            url,
            headers: _headers,
            body: json.encode({'email': cleanEmail}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'] as String?;
        final userData = data['user'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);
        await setToken(token, email: user.email, userId: user.id, isGuest: user.isGuest);
        isUsingMockFallback = false;
        return user;
      }
      throw Exception('Failed to identify user (HTTP ${response.statusCode}): ${response.body}');
    } catch (e) {
      debugPrint('API Error (identifyWithEmail): $e');
      rethrow;
    }
  }

  Future<UserModel?> getMe() async {
    if (_token == null || _token!.isEmpty) {
      return null;
    }
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.me}');
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = UserModel.fromJson(data);
        await setToken(_token, email: user.email, userId: user.id, isGuest: user.isGuest);
        isUsingMockFallback = false;
        return user;
      } else if (response.statusCode == 401) {
        // Token has expired or is invalid on backend
        await setToken(null);
        return null;
      }
    } catch (e) {
      debugPrint('API Error (getMe): $e');
      // Rethrow to signal network/offline failure so caller can preserve cached user
      rethrow;
    }
    return null;
  }

  // ----------------- Statements -----------------

  Future<List<StatementModel>> listStatements() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.listStatements}');
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        return list.map((e) => StatementModel.fromJson(e)).toList();
      }
      if (isUsingMockFallback) {
        return MockDataService.mockStatements;
      }
      throw Exception('Failed to list statements (HTTP ${response.statusCode})');
    } catch (e) {
      debugPrint('API Error (listStatements): $e');
      if (isUsingMockFallback) {
        return MockDataService.mockStatements;
      }
      rethrow;
    }
  }

  Future<StatementModel?> seedSampleStatement({String bank = 'HDFC Bank'}) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.seedSampleStatement}?bank=${Uri.encodeComponent(bank)}');
      final response = await http.post(url, headers: _headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return StatementModel.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('API Error (seedSampleStatement): $e');
    }
    return MockDataService.mockStatements.first;
  }

  Future<StatementModel?> uploadStatement(PlatformFile file) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.uploadStatements}');
      final request = http.MultipartRequest('POST', url);
      if (_token != null && _token!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.headers['Accept'] = 'application/json';
      request.headers['X-Tunnel-Skip-Anti-Abuse-Header'] = 'true';
      request.headers['ngrok-skip-browser-warning'] = 'true';

      final Uint8List fileBytes = await file.xFile.readAsBytes();
      if (fileBytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          fileBytes,
          filename: file.name,
        ));
      } else if (file.path != null && !kIsWeb) {
        request.files.add(await http.MultipartFile.fromPath(
          'files',
          file.path!,
          filename: file.name,
        ));
      } else {
        throw Exception("Could not read statement bytes from selected file '${file.name}'.");
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        if (list.isNotEmpty) {
          isUsingMockFallback = false;
          return StatementModel.fromJson(list.first);
        }
      } else {
        String errMsg = 'Upload failed (HTTP ${response.statusCode})';
        try {
          final errBody = json.decode(response.body);
          if (errBody is Map && errBody.containsKey('detail')) {
            errMsg = errBody['detail'].toString();
          }
        } catch (_) {}
        throw Exception(errMsg);
      }
    } catch (e) {
      debugPrint('API Error (uploadStatement): $e');
      rethrow;
    }
    return null;
  }

  Future<bool> deleteStatement(String statementId) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.listStatements}/$statementId');
      final response = await http.delete(url, headers: _headers).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('API Error (deleteStatement): $e');
    }
    if (isUsingMockFallback) {
      return true;
    }
    return false;
  }

  // ----------------- Transactions -----------------

  Future<List<TransactionModel>> getTransactions({
    String? category,
    String? search,
    String? source,
    bool? needsReview,
    String sortBy = 'date',
    String order = 'desc',
  }) async {
    try {
      final queryParams = <String, String>{
        'sort_by': sortBy,
        'order': order,
      };
      if (category != null && category != 'All') queryParams['category'] = category;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (source != null && source.toLowerCase() != 'all') queryParams['source'] = source.toLowerCase();
      if (needsReview != null) queryParams['needs_review'] = needsReview.toString();

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.transactions}').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        return list.map((e) => TransactionModel.fromJson(e)).toList();
      }
      if (isUsingMockFallback) {
        return MockDataService.mockTransactions;
      }
      throw Exception('Failed to load transactions (HTTP ${response.statusCode})');
    } catch (e) {
      debugPrint('API Error (getTransactions): $e');
      if (isUsingMockFallback) {
        return MockDataService.mockTransactions;
      }
      rethrow;
    }
  }

  Future<List<UncertainReviewModel>> getUncertainTransactions() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.uncertainTransactions}');
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        return list.map((e) => UncertainReviewModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('API Error (getUncertainTransactions): $e');
    }
    return MockDataService.mockUncertainTransactions;
  }

  Future<bool> updateTransactionCategory(String transactionId, String newCategory, {bool applyToFuture = true}) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.updateCategory}/$transactionId/category');
      final response = await http
          .patch(
            url,
            headers: _headers,
            body: json.encode({'category': newCategory, 'apply_to_future': applyToFuture}),
          )
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Error (updateTransactionCategory): $e');
      return true; // Optimistic fallback
    }
  }

  // ----------------- Cash Expenses -----------------

  Future<List<CashExpenseModel>> getCashExpenses({
    String? startDate,
    String? endDate,
    String? category,
    String? search,
    String sortBy = 'expense_date',
    String order = 'desc',
  }) async {
    try {
      final queryParams = <String, String>{
        'sort_by': sortBy,
        'order': order,
      };
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;
      if (category != null && category != 'All') queryParams['category'] = category;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.cashExpenses}').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        return list.map((e) => CashExpenseModel.fromJson(e)).toList();
      }
      if (isUsingMockFallback) {
        return MockDataService.mockCashExpenses;
      }
      throw Exception('Failed to load cash expenses (HTTP ${response.statusCode})');
    } catch (e) {
      debugPrint('API Error (getCashExpenses): $e');
      if (isUsingMockFallback) {
        return MockDataService.mockCashExpenses;
      }
      rethrow;
    }
  }

  Future<CashExpenseModel?> createCashExpense({
    required double amount,
    required String category,
    required String expenseDate,
    String? description,
    String paymentMethod = 'cash',
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.cashExpenses}');
      final body = json.encode({
        'amount': amount,
        'category': category,
        'expense_date': expenseDate,
        'payment_method': paymentMethod,
        if (description != null && description.isNotEmpty) 'description': description,
      });
      final response = await http.post(url, headers: _headers, body: body).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CashExpenseModel.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('API Error (createCashExpense): $e');
    }
    return null;
  }

  Future<CashExpenseModel?> updateCashExpense({
    required String id,
    double? amount,
    String? category,
    String? expenseDate,
    String? description,
    String? paymentMethod,
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.cashExpenses}/$id');
      final map = <String, dynamic>{};
      if (amount != null) map['amount'] = amount;
      if (category != null) map['category'] = category;
      if (expenseDate != null) map['expense_date'] = expenseDate;
      if (paymentMethod != null) map['payment_method'] = paymentMethod;
      if (description != null) map['description'] = description;

      final response = await http.put(url, headers: _headers, body: json.encode(map)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return CashExpenseModel.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('API Error (updateCashExpense): $e');
    }
    return null;
  }

  Future<bool> deleteCashExpense(String id) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.cashExpenses}/$id');
      final response = await http.delete(url, headers: _headers).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Error (deleteCashExpense): $e');
      return false;
    }
  }

  // ----------------- Analytics -----------------

  Future<AnalyticsSummaryModel> getAnalyticsSummary({String? startDate, String? endDate}) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.analyticsSummary}')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return AnalyticsSummaryModel.fromJson(json.decode(response.body));
      }
      if (isUsingMockFallback) {
        return MockDataService.mockAnalyticsSummary;
      }
      throw Exception('Failed to load analytics summary (HTTP ${response.statusCode})');
    } catch (e) {
      debugPrint('API Error (getAnalyticsSummary): $e');
      if (isUsingMockFallback) {
        return MockDataService.mockAnalyticsSummary;
      }
      rethrow;
    }
  }

  Future<List<MonthlySpendingItem>> getMonthlySpending({String? startDate, String? endDate}) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.monthlySpending}')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        return list.map((e) => MonthlySpendingItem.fromJson(e)).toList();
      }
      if (isUsingMockFallback) {
        return MockDataService.mockMonthlySpending;
      }
      throw Exception('Failed to load monthly spending (HTTP ${response.statusCode})');
    } catch (e) {
      debugPrint('API Error (getMonthlySpending): $e');
      if (isUsingMockFallback) {
        return MockDataService.mockMonthlySpending;
      }
      rethrow;
    }
  }

  // ----------------- Forecast -----------------

  Future<ForecastModel> getForecast() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.forecast}');
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return ForecastModel.fromJson(json.decode(response.body));
      }
      if (isUsingMockFallback) {
        return MockDataService.mockForecast;
      }
      throw Exception('Failed to load forecast (HTTP ${response.statusCode})');
    } catch (e) {
      debugPrint('API Error (getForecast): $e');
      if (isUsingMockFallback) {
        return MockDataService.mockForecast;
      }
      rethrow;
    }
  }

  // ----------------- Model & Benchmark -----------------

  Future<ModelMetricsModel> getModelMetrics() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.modelMetrics}');
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return ModelMetricsModel.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('API Error (getModelMetrics): $e');
    }
    return MockDataService.mockModelMetrics;
  }

  Future<bool> retrainModel() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.modelRetrain}');
      final response = await http.post(url, headers: _headers).timeout(const Duration(seconds: 60));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Error (retrainModel): $e');
      return false;
    }
  }
}
