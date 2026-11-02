import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// True when this browser has the Notification API at all (an embedded browser may not).
bool get browserNotificationsSupported {
  try {
    web.Notification.permission;
    return true;
  } catch (_) {
    return false;
  }
}

/// One of 'granted', 'denied' or 'default' (not asked yet), or 'unsupported'.
String browserNotificationPermission() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestBrowserNotificationPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart;
  } catch (_) {
    return browserNotificationPermission();
  }
}

/// Shows a notification and returns null on success, or a plain-language reason on failure.
///
/// Phones (Android Chrome) refuse `new Notification()` and only allow notifications that go through
/// the service worker, so that route is tried first and the page route is the fallback.
Future<String?> showBrowserNotification(String title, String body) async {
  if (!browserNotificationsSupported) return 'This browser does not support notifications.';
  if (browserNotificationPermission() != 'granted') return 'Notification permission has not been granted.';

  final options = web.NotificationOptions(body: body, icon: 'icons/Icon-192.png');

  try {
    final registration = await web.window.navigator.serviceWorker.getRegistration().toDart;
    if (registration != null) {
      await registration.showNotification(title, options).toDart;
      return null;
    }
  } catch (_) {
    // Fall through to the page route below.
  }

  try {
    web.Notification(title, options);
    return null;
  } catch (e) {
    return 'The browser refused to show the notification ($e).';
  }
}
