import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/expense_sync_coordinator.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final ExpenseSyncCoordinator _coordinator;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({ApiService? apiService, ExpenseSyncCoordinator? coordinator})
      : _api = apiService ?? ApiService(),
        _coordinator = coordinator ?? ExpenseSyncCoordinator();

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<void> init() async {
    await _api.init();
    if (_api.token != null && _api.token!.isNotEmpty) {
      _isLoading = true;
      notifyListeners();
      try {
        final restoredUser = await _api.getMe();
        if (restoredUser != null) {
          _user = restoredUser;
          _isLoading = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('Failed to restore session online: $e');
      }

      // If token is still valid (not revoked via 401) and online user was not restored,
      // safely restore offline cached identity to prevent duplicate account creation
      if (_user == null && _api.token != null && _api.userId != null && _api.userEmail != null) {
        _user = UserModel(
          id: _api.userId!,
          email: _api.userEmail!,
          isGuest: _api.isGuest,
          createdAt: DateTime.now(),
        );
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> identifyWithEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      _errorMessage = 'Please enter a valid email address.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _api.identifyWithEmail(cleanEmail);
      if (_user != null && user != null && _user!.id != user.id) {
        // Purge in-memory state of previous user so no stale data leaks
        _coordinator.notifyUserSessionReset();
      }
      _user = user;
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _api.loginGuest();
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _api.login(email, password);
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.setToken(null);
    _user = null;
    _errorMessage = null;
    _coordinator.notifyUserSessionReset();
    notifyListeners();
  }
}
