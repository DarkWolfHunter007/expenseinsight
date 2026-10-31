import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analytics_model.dart';
import 'browser_notification_stub.dart' if (dart.library.js_interop) 'browser_notification_web.dart' as browser;

class BudgetAlert {
  /// Unique per month, scope (overall or a category) and tier, so each tier fires once.
  final String key;
  final String title;
  final String body;

  const BudgetAlert({required this.key, required this.title, required this.body});
}

/// Decides which budget alerts are due. Pure logic so it can be tested without a browser.
class BudgetAlertPlanner {
  static const _alertStatuses = {'warning', 'critical', 'exceeded'};

  static String _money(double value) => '₹${value.abs().toStringAsFixed(0)}';

  static List<BudgetAlert> plan(AnalyticsSummaryModel summary, Set<String> alreadySent) {
    final alerts = <BudgetAlert>[];
    final month = summary.budgetMonth ?? '';
    if (summary.budgetStatus == 'none' || month.isEmpty) return alerts;

    void add(String scope, String status, String title, String body) {
      final key = '$month|$scope|$status';
      if (_alertStatuses.contains(status) && !alreadySent.contains(key)) {
        alerts.add(BudgetAlert(key: key, title: title, body: body));
      }
    }

    final spent = _money(summary.budgetSpent);
    final limit = _money(summary.monthlyBudget);
    switch (summary.budgetStatus) {
      case 'warning':
        add('all', 'warning', '80% of this month\'s budget used',
            '$spent of $limit spent, ${_money(summary.budgetRemaining)} left.');
      case 'critical':
        add('all', 'critical', '90% of this month\'s budget used',
            'Only ${_money(summary.budgetRemaining)} left for the next ${summary.daysLeftInMonth} days.');
      case 'exceeded':
        add('all', 'exceeded', 'You\'ve exceeded this month\'s budget',
            '$spent spent of $limit, over by ${_money(summary.budgetRemaining)}.');
    }

    for (final cat in summary.categoryBudgets) {
      final pct = cat.usedPct.toStringAsFixed(0);
      switch (cat.status) {
        case 'warning':
        case 'critical':
          add(cat.category, cat.status, '${cat.category} budget at $pct%',
              '${_money(cat.spent)} of ${_money(cat.limit)} spent, ${_money(cat.remaining)} left.');
        case 'exceeded':
          add(cat.category, 'exceeded', '${cat.category} budget exceeded',
              '${_money(cat.spent)} spent of ${_money(cat.limit)}, over by ${_money(cat.remaining)}.');
      }
    }
    return alerts;
  }
}

/// Shows browser notifications when a budget tier is crossed. Off until the user turns it on in
/// Budget & Alerts and grants the browser permission.
class BudgetNotificationService {
  static final BudgetNotificationService instance = BudgetNotificationService._();
  BudgetNotificationService._();

  static const enabledKey = 'budget_notifications_enabled';
  static const sentKey = 'budget_notifications_sent';

  bool get supported => browser.browserNotificationsSupported;
  String get permission => browser.browserNotificationPermission();

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Turns notifications on (asking the browser for permission) or off. Returns the resulting state.
  Future<bool> setEnabled(bool enabled) async {
    var result = enabled;
    if (enabled) {
      var perm = permission;
      if (perm == 'default') perm = await browser.requestBrowserNotificationPermission();
      result = perm == 'granted';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(enabledKey, result);
    } catch (_) {}
    return result;
  }

  void sendTest() {
    browser.showBrowserNotification('ExpenseInsight alerts are on', 'You\'ll be notified at 80%, 90% and when you exceed your budget.');
  }

  /// Fires any alerts that are newly due for [summary]. Never throws.
  Future<void> maybeNotify(AnalyticsSummaryModel summary) async {
    try {
      if (!supported || permission != 'granted' || !await isEnabled()) return;
      final prefs = await SharedPreferences.getInstance();
      final month = summary.budgetMonth ?? '';
      final sent = (prefs.getStringList(sentKey) ?? []).where((k) => k.startsWith('$month|')).toSet();

      final due = BudgetAlertPlanner.plan(summary, sent);
      for (final alert in due) {
        browser.showBrowserNotification(alert.title, alert.body);
        sent.add(alert.key);
      }
      await prefs.setStringList(sentKey, sent.toList());
    } catch (e) {
      debugPrint('[BudgetNotificationService] $e');
    }
  }
}
