import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/analytics_model.dart';
import '../services/budget_notification_service.dart';

/// Notification settings with everything visible: whether this browser can show notifications, whether
/// it has allowed them, the saved on/off choice, what will trigger the next alert, a test button that
/// reports the result, and a log of recent alerts.
class NotificationSettingsCard extends StatefulWidget {
  final AnalyticsSummaryModel? summary;
  final BudgetNotificationService? service;

  const NotificationSettingsCard({super.key, this.summary, this.service});

  @override
  State<NotificationSettingsCard> createState() => _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard> {
  late final BudgetNotificationService _service = widget.service ?? BudgetNotificationService.instance;
  NotificationStatus? _status;
  String? _testMessage;
  bool _testOk = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await _service.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    await _service.setEnabled(value);
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    await _service.requestPermission();
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _testMessage = null;
    });
    final problem = await _service.sendTest();
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _testOk = problem == null;
      _testMessage = problem ??
          'Sent. It should appear now. If you cannot see it, check that your device is not in Do Not Disturb / Focus mode.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final permissionRow = _permissionRow(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusRow(
          status.supported ? Icons.check_circle_rounded : Icons.cancel_rounded,
          status.supported ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          'This browser: ${status.supported ? 'supports notifications' : 'does not support notifications'}',
        ),
        permissionRow,
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: status.enabled,
          activeThumbColor: const Color(0xFF10B981),
          onChanged: _busy ? null : _toggle,
          title: Text('Notify me about budget alerts',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(
            'Your choice is saved on this device and stays after a reload. Other devices have their own setting.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
        ),
        _verdict(status),
        if (widget.summary != null) ...[
          const SizedBox(height: 10),
          Text(
            BudgetAlertPlanner.describeNext(widget.summary!),
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: (_busy || !status.supported) ? null : _test,
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Send test notification'),
            ),
            IconButton(
              onPressed: _busy ? null : _refresh,
              tooltip: 'Refresh status',
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        if (_testMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _testMessage!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _testOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ),
        if (status.log.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('RECENT ALERTS',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.grey)),
          const SizedBox(height: 6),
          for (final entry in status.log.take(5)) _logRow(entry),
        ],
      ],
    );
  }

  Widget _permissionRow(NotificationStatus status) {
    switch (status.permission) {
      case 'granted':
        return _statusRow(Icons.check_circle_rounded, const Color(0xFF10B981), 'Permission: allowed');
      case 'denied':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusRow(Icons.block_rounded, const Color(0xFFEF4444), 'Permission: blocked in this browser'),
            Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Text(
                'Allow notifications for this site: click the lock or settings icon next to the address bar, '
                'open Site settings, and set Notifications to Allow. Then press the refresh button below.',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        );
      case 'default':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusRow(Icons.help_outline_rounded, const Color(0xFFF59E0B), 'Permission: not asked yet'),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: TextButton(onPressed: _busy ? null : _allow, child: const Text('Allow notifications')),
            ),
          ],
        );
      default:
        return _statusRow(Icons.cancel_rounded, const Color(0xFFEF4444), 'Permission: not available here');
    }
  }

  Widget _verdict(NotificationStatus status) {
    final String text;
    final Color color;
    if (status.working) {
      text = 'Notifications are on and will be shown.';
      color = const Color(0xFF10B981);
    } else if (!status.supported) {
      text = 'Not working: this browser cannot show notifications. Open the app in Chrome, Edge or Safari '
          '(on iPhone, add it to the Home Screen first).';
      color = const Color(0xFFEF4444);
    } else if (status.permission == 'denied') {
      text = 'Not working: the browser has blocked notifications for this site.';
      color = const Color(0xFFEF4444);
    } else if (status.permission == 'default') {
      text = 'Not working yet: allow notifications above.';
      color = const Color(0xFFF59E0B);
    } else {
      text = 'Off: turn the switch on to receive budget alerts. The banners on the dashboard always work.';
      color = Colors.grey;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _statusRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12.5))),
        ],
      ),
    );
  }

  Widget _logRow(NotificationLogEntry entry) {
    final when = DateFormat('d MMM, h:mm a').format(entry.time);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.delivered ? Icons.check_rounded : Icons.close_rounded,
            size: 15,
            color: entry.delivered ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$when  ${entry.title}${entry.delivered ? '' : '  (not shown: ${entry.problem ?? 'unknown'})'}',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
