import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/statement_model.dart';
import '../services/api_service.dart';
import '../services/expense_sync_coordinator.dart';

class StatementProvider extends ChangeNotifier {
  final ApiService _api;
  final ExpenseSyncCoordinator _coordinator;

  StatementProvider({ApiService? apiService, ExpenseSyncCoordinator? coordinator})
      : _api = apiService ?? ApiService(),
        _coordinator = coordinator ?? ExpenseSyncCoordinator() {
    _coordinator.addSessionResetListener(clear);
  }
  List<StatementModel> _statements = [];
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _currentStep = 'Ready';
  String? _errorMessage;

  List<StatementModel> get statements => _statements;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String get currentStep => _currentStep;
  String? get errorMessage => _errorMessage;

  Future<void> fetchStatements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _statements = await _api.listStatements();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> seedSampleStatement({String bank = 'HDFC Bank'}) async {
    _isUploading = true;
    _uploadProgress = 0.15;
    _currentStep = 'Reading Statement PDF';
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate live processing step progress
      await Future.delayed(const Duration(milliseconds: 300));
      _uploadProgress = 0.35;
      _currentStep = 'Extracting transactions';
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 300));
      _uploadProgress = 0.65;
      _currentStep = 'Normalizing merchants & AI Categorization';
      notifyListeners();

      final stmt = await _api.seedSampleStatement(bank: bank);

      _uploadProgress = 0.85;
      _currentStep = 'Building spending analytics';
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 200));
      _uploadProgress = 1.0;
      _currentStep = 'Completed';
      notifyListeners();

      if (stmt != null) {
        _statements.insert(0, stmt);
        ExpenseSyncCoordinator().notifyExpenseMutated();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadStatementFile(PlatformFile file) async {
    _isUploading = true;
    _uploadProgress = 0.2;
    _currentStep = 'Uploading statement PDF';
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      _uploadProgress = 0.45;
      _currentStep = 'Extracting document text & tables';
      notifyListeners();

      final stmt = await _api.uploadStatement(file);
      if (stmt != null) {
        _uploadProgress = 0.85;
        _currentStep = 'Normalizing merchants & AI Categorization';
        notifyListeners();

        await Future.delayed(const Duration(milliseconds: 200));
        _uploadProgress = 1.0;
        _currentStep = 'Completed';
        _statements.removeWhere((s) => s.id == stmt.id);
        _statements.insert(0, stmt);
        notifyListeners();
        ExpenseSyncCoordinator().notifyExpenseMutated();
        return true;
      } else {
        _errorMessage = "Server did not return statement metadata.";
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteStatement(String statementId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _api.deleteStatement(statementId);
      if (success) {
        _statements.removeWhere((s) => s.id == statementId);
        ExpenseSyncCoordinator().notifyExpenseMutated();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears in-memory statements on logout/account switch (Phase 12).
  void clear() {
    _statements = [];
    _isLoading = false;
    _isUploading = false;
    _uploadProgress = 0.0;
    _currentStep = 'Ready';
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _coordinator.removeSessionResetListener(clear);
    super.dispose();
  }
}
