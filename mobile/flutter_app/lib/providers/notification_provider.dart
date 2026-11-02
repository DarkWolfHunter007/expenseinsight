import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../services/expense_sync_coordinator.dart';

/// State of the Financial Activity Centre. Everything lives in the backend, tied to the signed-in account,
/// so nothing is kept here that could leak from one session to the next: signing out clears it.
class NotificationProvider extends ChangeNotifier {
  final ApiService _api;
  final ExpenseSyncCoordinator _coordinator;

  NotificationProvider({ApiService? apiService, ExpenseSyncCoordinator? coordinator})
      : _api = apiService ?? ApiService(),
        _coordinator = coordinator ?? ExpenseSyncCoordinator() {
    _coordinator.addListener(_onDataChanged);
    _coordinator.addSessionResetListener(clear);
  }

  NotificationFeed _feed = NotificationFeed.empty;
  String _group = 'all';
  bool _showEarlier = false;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  NotificationFeed get feed => _feed;
  List<AppNotification> get items => _feed.items;
  int get unreadCount => _feed.unreadCount;
  String get group => _group;
  bool get showEarlier => _showEarlier;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  /// How many outstanding transactions still need review, as reported by the live review notification.
  int get uncertainCount {
    for (final n in _feed.items) {
      if (n.type == 'uncertain_transaction' && !n.dismissed && !n.resolved) return n.liveCount ?? 0;
    }
    return 0;
  }

  void _onDataChanged() {
    // An expense, a statement or a category change can create or resolve notifications
    sync();
  }

  void clear() {
    _feed = NotificationFeed.empty;
    _group = 'all';
    _showEarlier = false;
    _isLoading = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _feed = await _api.getNotifications(group: _group, includeDismissed: _showEarlier);
      _hasLoaded = true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Asks the backend to record whatever is newly due (budget levels, the day's allowance, the review
  /// queue). The backend ignores anything it already recorded, so calling this often is safe.
  Future<void> sync() async {
    try {
      await _api.syncNotifications();
      await load();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> setGroup(String group) async {
    if (_group == group) return;
    _group = group;
    await load();
  }

  Future<void> setShowEarlier(bool value) async {
    if (_showEarlier == value) return;
    _showEarlier = value;
    await load();
  }

  AppNotification? _byId(String id) {
    for (final n in _feed.items) {
      if (n.id == id) return n;
    }
    return null;
  }

  void _replace(AppNotification updated, {int unreadDelta = 0}) {
    _feed = NotificationFeed(
      items: [for (final n in _feed.items) n.id == updated.id ? updated : n],
      unreadCount: (_feed.unreadCount + unreadDelta).clamp(0, 1 << 30),
      counts: _feed.counts,
    );
    notifyListeners();
  }

  /// Reading is separate from dismissing: a read notification stays in the list.
  Future<void> setRead(String id, bool read) async {
    final current = _byId(id);
    if (current == null || current.read == read) return;
    _replace(current.copyWith(read: read), unreadDelta: read ? -1 : 1);
    try {
      read ? await _api.markNotificationRead(id) : await _api.markNotificationUnread(id);
    } catch (_) {
      await load();
    }
  }

  Future<void> dismiss(String id) async {
    final current = _byId(id);
    if (current == null) return;
    try {
      await _api.dismissNotification(id);
    } finally {
      await load();
    }
  }

  Future<void> restore(String id) async {
    try {
      await _api.restoreNotification(id);
    } finally {
      await load();
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllNotificationsRead(group: _group);
    } finally {
      await load();
    }
  }

  @override
  void dispose() {
    _coordinator.removeListener(_onDataChanged);
    _coordinator.removeSessionResetListener(clear);
    super.dispose();
  }
}
