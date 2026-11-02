import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../screens/activity_centre_screen.dart';

/// The bell in the dashboard's navigation. The badge is the real number of unread notifications.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationProvider, int>((p) => p.unreadCount);
    final label = unread == 0 ? 'Notifications, none unread' : 'Notifications, $unread unread';

    return Semantics(
      label: label,
      button: true,
      child: IconButton(
        tooltip: 'Notifications',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ActivityCentreScreen()),
        ),
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 99 ? '99+' : '$unread'),
          backgroundColor: const Color(0xFFEF4444),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ),
    );
  }
}
