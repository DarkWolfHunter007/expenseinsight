import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/models/app_notification.dart';
import 'package:flutter_app/providers/notification_provider.dart';
import 'package:flutter_app/screens/activity_centre_screen.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:flutter_app/services/expense_sync_coordinator.dart';
import 'package:flutter_app/utils/notification_actions.dart';
import 'package:flutter_app/utils/relative_time.dart';
import 'package:flutter_app/widgets/notification_bell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

AppNotification _n(
  String id,
  String group, {
  String type = 'system',
  String severity = 'info',
  bool read = false,
  bool dismissed = false,
  bool resolved = false,
  int? liveCount,
  String? action,
}) =>
    AppNotification(
      id: id,
      type: type,
      group: group,
      severity: severity,
      title: 'Title $id',
      body: 'Body $id',
      createdAt: DateTime.now(),
      read: read,
      dismissed: dismissed,
      resolved: resolved,
      liveCount: liveCount,
      action: action,
    );

/// An in-memory stand-in for the backend that mimics its filters and its read/dismiss rules.
class FakeNotificationApi extends Fake implements ApiService {
  final List<AppNotification> store;
  int syncCalls = 0;
  bool failLoad = false;
  Completer<void>? gate;

  FakeNotificationApi(this.store);

  void _set(String id, AppNotification Function(AppNotification) change) {
    final i = store.indexWhere((n) => n.id == id);
    store[i] = change(store[i]);
  }

  @override
  Future<NotificationFeed> getNotifications({String group = 'all', bool includeDismissed = false}) async {
    await gate?.future;
    if (failLoad) throw Exception('offline');
    final visible = store.where((n) => includeDismissed || (!n.dismissed && !n.resolved)).toList();
    final shown = group == 'all' ? visible : visible.where((n) => n.group == group).toList();
    return NotificationFeed(
      items: shown,
      unreadCount: visible.where((n) => !n.read).length,
      counts: {
        'all': visible.length,
        for (final g in ['budget', 'transactions', 'system']) g: visible.where((n) => n.group == g).length,
      },
    );
  }

  @override
  Future<void> syncNotifications() async => syncCalls++;

  @override
  Future<void> markNotificationRead(String id) async => _set(id, (n) => n.copyWith(read: true));

  @override
  Future<void> markNotificationUnread(String id) async => _set(id, (n) => n.copyWith(read: false));

  @override
  Future<void> dismissNotification(String id) async => _set(id, (n) => n.copyWith(dismissed: true));

  @override
  Future<void> restoreNotification(String id) async => _set(id, (n) => n.copyWith(dismissed: false));

  @override
  Future<void> markAllNotificationsRead({String group = 'all'}) async {
    for (var i = 0; i < store.length; i++) {
      if (group == 'all' || store[i].group == group) store[i] = store[i].copyWith(read: true);
    }
  }
}

Widget _app(NotificationProvider provider, Widget home) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: home),
    );

void main() {
  late FakeNotificationApi api;
  late NotificationProvider provider;

  setUp(() {
    api = FakeNotificationApi([
      _n('b1', 'budget', type: 'budget_warning', severity: 'warning', action: 'budget_settings'),
      _n('t1', 'transactions', type: 'uncertain_transaction', severity: 'warning', liveCount: 4, action: 'review_uncertain'),
      _n('s1', 'system', read: true),
    ]);
    provider = NotificationProvider(apiService: api);
  });

  tearDown(() => provider.dispose());

  group('NotificationProvider', () {
    test('loads the feed and counts what is unread', () async {
      await provider.load();
      expect(provider.items, hasLength(3));
      expect(provider.unreadCount, 2);
      expect(provider.hasLoaded, isTrue);
    });

    test('the live review count comes from the notification, never a constant', () async {
      await provider.load();
      expect(provider.uncertainCount, 4);

      api.store[1] = api.store[1].copyWith(dismissed: true);
      await provider.load();
      expect(provider.uncertainCount, 0);
    });

    test('reading and unreading change only the read state', () async {
      await provider.load();
      await provider.setRead('b1', true);
      expect(provider.unreadCount, 1);
      expect(provider.items.firstWhere((n) => n.id == 'b1').dismissed, isFalse);

      await provider.setRead('b1', false);
      expect(provider.unreadCount, 2);
    });

    test('dismiss removes it from the list, restore brings it back', () async {
      await provider.load();
      await provider.dismiss('b1');
      expect(provider.items.map((n) => n.id), isNot(contains('b1')));

      await provider.setShowEarlier(true);
      final dismissed = provider.items.firstWhere((n) => n.id == 'b1');
      expect(dismissed.dismissed, isTrue);

      await provider.restore('b1');
      await provider.setShowEarlier(false);
      expect(provider.items.map((n) => n.id), contains('b1'));
    });

    test('a resolved notification is hidden by default and listed under earlier', () async {
      api.store.add(_n('r1', 'transactions', type: 'uncertain_transaction', resolved: true));
      await provider.load();
      expect(provider.items.map((n) => n.id), isNot(contains('r1')));
      await provider.setShowEarlier(true);
      expect(provider.items.map((n) => n.id), contains('r1'));
    });

    test('filters by group', () async {
      await provider.setGroup('budget');
      expect(provider.items.single.id, 'b1');
      // the filter chips still show the whole account
      expect(provider.feed.counts['transactions'], 1);
    });

    test('mark all read respects the selected group', () async {
      await provider.setGroup('budget');
      await provider.markAllRead();
      expect(api.store.firstWhere((n) => n.id == 'b1').read, isTrue);
      expect(api.store.firstWhere((n) => n.id == 't1').read, isFalse);
    });

    test('sync asks the backend to record what is due and then reloads', () async {
      await provider.sync();
      expect(api.syncCalls, 1);
      expect(provider.items, hasLength(3));
    });

    test('a failed load is reported without losing the state', () async {
      await provider.load();
      api.failLoad = true;
      await provider.load();
      expect(provider.errorMessage, contains('offline'));
      expect(provider.items, hasLength(3));
    });

    test('a session reset clears everything so the next user sees nothing of the last', () async {
      await provider.setGroup('budget');
      await provider.load();
      ExpenseSyncCoordinator().notifyUserSessionReset();
      expect(provider.items, isEmpty);
      expect(provider.unreadCount, 0);
      expect(provider.group, 'all');
      expect(provider.hasLoaded, isFalse);
    });
  });

  group('destinations', () {
    test('every stored action maps to a screen', () {
      expect(destinationFor('budget_settings'), NotificationDestination.budgetSettings);
      expect(destinationFor('review_uncertain'), NotificationDestination.reviewUncertain);
      expect(destinationFor('transactions'), NotificationDestination.transactions);
      expect(destinationFor('upload'), NotificationDestination.upload);
      expect(destinationFor('dashboard'), NotificationDestination.dashboard);
    });

    test('anything else leads nowhere', () {
      expect(destinationFor(null), NotificationDestination.none);
      expect(destinationFor('something_new'), NotificationDestination.none);
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 11, 3, 15, 0);
    test('recent, minutes, hours, yesterday, older', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(relativeTime(now.subtract(const Duration(hours: 2)), now: now), '2 h ago');
      expect(relativeTime(DateTime(2026, 11, 2, 9), now: now), 'Yesterday');
      expect(relativeTime(DateTime(2026, 10, 20), now: now), '20 Oct');
      expect(relativeTime(DateTime(2025, 10, 20), now: now), '20 Oct 2025');
    });
  });

  group('NotificationBell', () {
    testWidgets('shows the real unread number and says it to screen readers', (tester) async {
      await provider.load();
      await tester.pumpWidget(_app(provider, const Scaffold(body: NotificationBell())));
      expect(find.text('2'), findsOneWidget);
      expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);
    });

    testWidgets('has no badge when everything is read', (tester) async {
      await provider.load();
      await provider.markAllRead();
      await tester.pumpWidget(_app(provider, const Scaffold(body: NotificationBell())));
      expect(find.text('0'), findsNothing);
      expect(find.bySemanticsLabel('Notifications, none unread'), findsOneWidget);
    });

    testWidgets('opens the Activity Centre', (tester) async {
      await provider.load();
      await tester.pumpWidget(_app(provider, const Scaffold(body: NotificationBell())));
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityCentreScreen), findsOneWidget);
    });
  });

  group('ActivityCentreScreen', () {
    testWidgets('lists notifications, filter counts and the review count', (tester) async {
      await tester.pumpWidget(_app(provider, const ActivityCentreScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Title b1'), findsOneWidget);
      expect(find.text('Title t1'), findsOneWidget);
      expect(find.text('All 3'), findsOneWidget);
      expect(find.text('Budget 1'), findsOneWidget);
      expect(api.syncCalls, 1);
    });

    testWidgets('opening it does not mark anything read', (tester) async {
      await tester.pumpWidget(_app(provider, const ActivityCentreScreen()));
      await tester.pumpAndSettle();
      expect(provider.unreadCount, 2);
    });

    testWidgets('a filter chip narrows the list', (tester) async {
      await tester.pumpWidget(_app(provider, const ActivityCentreScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budget 1'));
      await tester.pumpAndSettle();
      expect(find.text('Title b1'), findsOneWidget);
      expect(find.text('Title t1'), findsNothing);
    });

    testWidgets('dismiss removes the row; mark all read clears the unread count', (tester) async {
      await tester.pumpWidget(_app(provider, const ActivityCentreScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dismiss').first);
      await tester.pumpAndSettle();
      expect(find.text('Title b1'), findsNothing);

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();
      expect(provider.unreadCount, 0);
    });

    testWidgets('empty state when there is nothing', (tester) async {
      api.store.clear();
      await tester.pumpWidget(_app(provider, const ActivityCentreScreen()));
      await tester.pumpAndSettle();
      expect(find.text('You are all caught up'), findsOneWidget);
    });

    testWidgets('shows a loading indicator before the first response', (tester) async {
      api.gate = Completer<void>();
      await tester.pumpWidget(_app(provider, const ActivityCentreScreen()));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      api.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows an error with a retry when the first load fails', (tester) async {
      api.failLoad = true;
      await tester.pumpWidget(_app(provider, const ActivityCentreScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('fits a narrow phone without overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(provider, const ActivityCentreScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
