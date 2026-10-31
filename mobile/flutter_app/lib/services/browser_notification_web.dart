import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get browserNotificationsSupported => true;

/// One of 'granted', 'denied' or 'default' (not asked yet).
String browserNotificationPermission() => web.Notification.permission;

Future<String> requestBrowserNotificationPermission() async {
  final result = await web.Notification.requestPermission().toDart;
  return result.toDart;
}

void showBrowserNotification(String title, String body) {
  web.Notification(title, web.NotificationOptions(body: body, icon: 'icons/Icon-192.png'));
}
