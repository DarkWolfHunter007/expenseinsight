// Used on platforms without the browser Notification API (tests, mobile, desktop).

bool get browserNotificationsSupported => false;

String browserNotificationPermission() => 'unsupported';

Future<String> requestBrowserNotificationPermission() async => 'unsupported';

Future<String?> showBrowserNotification(String title, String body) async =>
    'Notifications are only available in a web browser.';
