import 'package:flutter/foundation.dart';

/// Centralized coordinator for notifying providers and screens when an expense,
/// transaction, or category mutation occurs anywhere in the app.
class ExpenseSyncCoordinator {
  static final ExpenseSyncCoordinator _instance = ExpenseSyncCoordinator._internal();
  factory ExpenseSyncCoordinator() => _instance;
  ExpenseSyncCoordinator._internal();

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Called after any successful expense/transaction mutation (create, update, delete, category change).
  void notifyExpenseMutated() {
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('[ExpenseSyncCoordinator] Error in listener: $e');
      }
    }
  }
}
