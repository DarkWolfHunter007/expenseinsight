import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analytics_model.dart';
import 'api_service.dart';
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

  /// What the user can expect next, in plain words, for the settings screen.
  static String describeNext(AnalyticsSummaryModel summary) {
    if (summary.budgetStatus == 'none' || summary.monthlyBudget <= 0) {
      return 'No budget is set yet, so there is nothing to alert on.';
    }
    final limit = summary.monthlyBudget;
    switch (summary.budgetStatus) {
      case 'on_track':
        return 'You are on track (${summary.budgetUsedPct.toStringAsFixed(0)}% used), so no alert is due yet. '
            'You will be notified at 80% (${_money(limit * 0.8)}), 90% (${_money(limit * 0.9)}) '
            'and when you pass ${_money(limit)}.';
      case 'warning':
        return 'Past 80% (${_money(summary.budgetSpent)} of ${_money(limit)}). Next alerts: 90% (${_money(limit * 0.9)}) '
            'and when you pass ${_money(limit)}.';
      case 'critical':
        return 'Past 90% (${_money(summary.budgetSpent)} of ${_money(limit)}). Next alert: when you pass ${_money(limit)}.';
      default:
        return 'Over budget (${_money(summary.budgetSpent)} of ${_money(limit)}). All of this month\'s alerts have fired.';
    }
  }
}

/// One line of the alert log: what was sent (or why it was not) and when.
class NotificationLogEntry {
  final DateTime time;
  final String title;
  final bool delivered;
  final String? problem;

  const NotificationLogEntry({required this.time, required this.title, required this.delivered, this.problem});

  Map<String, dynamic> toJson() =>
      {'t': time.toIso8601String(), 'title': title, 'ok': delivered, if (problem != null) 'problem': problem};

  factory NotificationLogEntry.fromJson(Map<String, dynamic> json) => NotificationLogEntry(
        time: DateTime.tryParse(json['t'] ?? '') ?? DateTime.now(),
        title: json['title'] ?? '',
        delivered: json['ok'] ?? false,
        problem: json['problem'],
      );
}

/// Browser state the settings screen shows, read in one go.
class NotificationStatus {
  final bool supported;
  final String permission; // granted | denied | default | unsupported
  final bool enabled; // the saved on/off choice, independent of the browser permission
  final List<NotificationLogEntry> log;

  const NotificationStatus({
    required this.supported,
    required this.permission,
    required this.enabled,
    required this.log,
  });

  /// True only when an alert would really be shown: wanted, supported and allowed.
  bool get working => enabled && supported && permission == 'granted';
}

/// Shows browser notifications when a budget tier is crossed. The on/off choice is saved on this
/// browser and survives reloads; the browser's own permission is separate and shown next to it.
class BudgetNotificationService {
  static final BudgetNotificationService instance = BudgetNotificationService._();
  BudgetNotificationService._();

  static const enabledKey = 'budget_notifications_enabled';
  static const sentKey = 'budget_notifications_sent';
  static const logKey = 'budget_notifications_log';
  static const _maxLog = 8;

  /// The saved choice, the per-month "already sent" list and the alert log belong to the signed-in account, so
  /// a different session on the same browser neither inherits them nor is silenced by them.
  static String scopedKey(String base, [String? userId]) => '$base:${userId ?? ApiService().userId ?? 'anonymous'}';

  bool get supported => browser.browserNotificationsSupported;
  String get permission => browser.browserNotificationPermission();

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(scopedKey(enabledKey)) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<NotificationLogEntry>> readLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(scopedKey(logKey)) ?? [];
      return raw.map((e) => NotificationLogEntry.fromJson(json.decode(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<NotificationStatus> status() async => NotificationStatus(
        supported: supported,
        permission: permission,
        enabled: await isEnabled(),
        log: await readLog(),
      );

  Future<void> _record(NotificationLogEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(scopedKey(logKey)) ?? [];
      raw.insert(0, json.encode(entry.toJson()));
      await prefs.setStringList(scopedKey(logKey), raw.take(_maxLog).toList());
    } catch (_) {}
  }

  /// Saves the on/off choice. It is saved even when the browser permission is missing, so the toggle
  /// never jumps back; turning it on also asks the browser for permission if that has not been asked.
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(scopedKey(enabledKey), enabled);
    } catch (_) {}
    if (enabled && supported && permission == 'default') {
      await browser.requestBrowserNotificationPermission();
    }
  }

  /// Asks the browser for permission (it may show a prompt). Returns the resulting permission.
  Future<String> requestPermission() => browser.requestBrowserNotificationPermission();

  /// Sends a test notification. Returns null on success, or what went wrong.
  Future<String?> sendTest() async {
    final problem = await browser.showBrowserNotification(
      'ExpenseInsight test notification',
      'If you can read this, budget alerts will reach you at 80%, 90% and when you pass your limit.',
    );
    await _record(NotificationLogEntry(
      time: DateTime.now(),
      title: 'Test notification',
      delivered: problem == null,
      problem: problem,
    ));
    return problem;
  }

  /// Fires any alerts that are newly due for [summary]. Never throws. An alert that could not be shown
  /// is not marked as sent, so it is tried again the next time the dashboard refreshes.
  Future<void> maybeNotify(AnalyticsSummaryModel summary) async {
    try {
      if (!supported || permission != 'granted' || !await isEnabled()) return;
      final prefs = await SharedPreferences.getInstance();
      final month = summary.budgetMonth ?? '';
      final sent = (prefs.getStringList(scopedKey(sentKey)) ?? []).where((k) => k.startsWith('$month|')).toSet();

      for (final alert in BudgetAlertPlanner.plan(summary, sent)) {
        final problem = await browser.showBrowserNotification(alert.title, alert.body);
        await _record(NotificationLogEntry(
          time: DateTime.now(),
          title: alert.title,
          delivered: problem == null,
          problem: problem,
        ));
        if (problem == null) sent.add(alert.key);
      }
      await prefs.setStringList(scopedKey(sentKey), sent.toList());
    } catch (e) {
      debugPrint('[BudgetNotificationService] $e');
    }
  }
}
