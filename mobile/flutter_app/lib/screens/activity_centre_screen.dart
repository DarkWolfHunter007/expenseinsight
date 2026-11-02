import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../utils/notification_actions.dart';
import '../utils/relative_time.dart';

Color severityColor(String severity) {
  switch (severity) {
    case 'critical':
      return const Color(0xFFEF4444); // red: needs action
    case 'warning':
      return const Color(0xFFF59E0B); // amber: be careful
    case 'success':
      return const Color(0xFF10B981); // green: good news
    default:
      return const Color(0xFF3B82F6); // blue: information
  }
}

/// The Financial Activity Centre: every budget, transaction and system notification of the signed-in
/// account. Opening it changes nothing: reading and dismissing are explicit, separate actions.
class ActivityCentreScreen extends StatefulWidget {
  const ActivityCentreScreen({super.key});

  @override
  State<ActivityCentreScreen> createState() => _ActivityCentreScreenState();
}

class _ActivityCentreScreenState extends State<ActivityCentreScreen> {
  static const _groups = [
    ('all', 'All'),
    ('budget', 'Budget'),
    ('transactions', 'Transactions'),
    ('system', 'System'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().sync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          TextButton.icon(
            onPressed: provider.unreadCount == 0 ? null : provider.markAllRead,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Mark all read'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final (key, label) in _groups)
                      ChoiceChip(
                        label: Text('$label ${provider.feed.counts[key] ?? 0}'),
                        selected: provider.group == key,
                        showCheckmark: false,
                        onSelected: (_) => provider.setGroup(key),
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: provider.group == key ? FontWeight.w700 : FontWeight.w600,
                          color: provider.group == key ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        side: BorderSide(
                          color: provider.group == key
                              ? const Color(0xFF10B981)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                  value: provider.showEarlier,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: provider.setShowEarlier,
                  title: Text('Show earlier notifications', style: GoogleFonts.inter(fontSize: 13)),
                  subtitle: Text('Includes dismissed and resolved ones',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _body(context, provider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, NotificationProvider provider) {
    if (!provider.hasLoaded && provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (provider.errorMessage != null && provider.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: provider.sync, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (provider.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 40, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text(
              provider.showEarlier ? 'No notifications yet' : 'You are all caught up',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Budget alerts, review requests and activity will appear here.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: provider.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => NotificationRow(notification: provider.items[index]),
    );
  }
}

/// A compact notification row. Tapping it marks it read and opens its destination; the two icons are
/// the separate read/unread and dismiss/restore actions.
class NotificationRow extends StatelessWidget {
  final AppNotification notification;

  const NotificationRow({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    final n = notification;
    final color = severityColor(n.severity);
    final muted = n.dismissed || n.resolved;
    final scope = [n.scopeCategory, n.scopeDay ?? n.scopeMonth].whereType<String>().join(' · ');

    return Semantics(
      label: '${n.read ? 'Read' : 'Unread'} notification: ${n.title}. ${n.body}',
      button: true,
      child: InkWell(
        onTap: () {
          if (!n.read) provider.setRead(n.id, true);
          openNotificationAction(context, n.action);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: n.read ? color.withValues(alpha: 0.35) : color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: muted ? 0.6 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                      if (n.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(n.body, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400])),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        [
                          relativeTime(n.createdAt),
                          if (scope.isNotEmpty) scope,
                          if (n.resolved) 'Resolved' else if (n.dismissed) 'Dismissed',
                        ].join('  ·  '),
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: n.read ? 'Mark as unread' : 'Mark as read',
                visualDensity: VisualDensity.compact,
                onPressed: () => provider.setRead(n.id, !n.read),
                icon: Icon(n.read ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined, size: 19),
              ),
              if (!n.resolved)
                IconButton(
                  tooltip: n.dismissed ? 'Restore' : 'Dismiss',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => n.dismissed ? provider.restore(n.id) : provider.dismiss(n.id),
                  icon: Icon(n.dismissed ? Icons.restore_rounded : Icons.close_rounded, size: 19),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
