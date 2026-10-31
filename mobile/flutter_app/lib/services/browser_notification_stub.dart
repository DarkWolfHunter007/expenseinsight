// Used on platforms without the browser Notification API (tests, mobile, desktop).

bool get browserNotificationsSupported => false;

String browserNotificationPermission() => 'unsupported';

Future<String> requestBrowserNotificationPermission() async => 'unsupported';

void showBrowserNotification(String title, String body) {}
