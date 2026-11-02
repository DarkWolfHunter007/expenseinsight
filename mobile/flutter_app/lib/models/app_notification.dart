/// One entry of the Financial Activity Centre, as stored by the backend for the signed-in user.
class AppNotification {
  final String id;
  final String type;
  final String group; // budget | transactions | system
  final String severity; // info | success | warning | critical
  final String title;
  final String body;
  final String? action;
  final String? scopeMonth;
  final String? scopeDay;
  final String? scopeCategory;
  final int? liveCount;
  final bool read;
  final bool dismissed;
  final bool resolved;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.group,
    required this.severity,
    required this.title,
    required this.body,
    required this.createdAt,
    this.action,
    this.scopeMonth,
    this.scopeDay,
    this.scopeCategory,
    this.liveCount,
    this.read = false,
    this.dismissed = false,
    this.resolved = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? 'system',
      group: json['group'] ?? 'system',
      severity: json['severity'] ?? 'info',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      action: json['action'],
      scopeMonth: json['scope_month'],
      scopeDay: json['scope_day'],
      scopeCategory: json['scope_category'],
      liveCount: json['live_count'],
      read: json['read'] ?? false,
      dismissed: json['dismissed'] ?? false,
      resolved: json['resolved'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  AppNotification copyWith({bool? read, bool? dismissed}) => AppNotification(
        id: id,
        type: type,
        group: group,
        severity: severity,
        title: title,
        body: body,
        createdAt: createdAt,
        action: action,
        scopeMonth: scopeMonth,
        scopeDay: scopeDay,
        scopeCategory: scopeCategory,
        liveCount: liveCount,
        read: read ?? this.read,
        dismissed: dismissed ?? this.dismissed,
        resolved: resolved,
      );
}

/// The list of notifications plus the numbers the bell and the filters show (always for the whole account,
/// whichever filter is selected).
class NotificationFeed {
  final List<AppNotification> items;
  final int unreadCount;
  final Map<String, int> counts;

  const NotificationFeed({this.items = const [], this.unreadCount = 0, this.counts = const {}});

  static const empty = NotificationFeed();

  factory NotificationFeed.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    (json['counts'] as Map<String, dynamic>?)?.forEach((key, value) => counts[key] = (value as num).toInt());
    return NotificationFeed(
      items: (json['items'] as List<dynamic>? ?? []).map((e) => AppNotification.fromJson(e)).toList(),
      unreadCount: json['unread_count'] ?? 0,
      counts: counts,
    );
  }
}
