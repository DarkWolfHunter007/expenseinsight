import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers a close action. The banner stays closed while [dismissedValue] is unchanged and
/// reappears as soon as it changes (a worse status, a new day, a new month).
class DismissibleBanner extends StatefulWidget {
  final String prefsKey;
  final String dismissedValue;
  final Widget Function(BuildContext context, VoidCallback close) builder;
  final double spacing;

  const DismissibleBanner({
    super.key,
    required this.prefsKey,
    required this.dismissedValue,
    required this.builder,
    this.spacing = 16,
  });

  @override
  State<DismissibleBanner> createState() => _DismissibleBannerState();
}

class _DismissibleBannerState extends State<DismissibleBanner> {
  String? _stored;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(widget.prefsKey);
      if (mounted && value != null) setState(() => _stored = value);
    } catch (_) {
      // Closing is a convenience; the banner simply shows if storage is unavailable.
    }
  }

  Future<void> _close() async {
    final value = widget.dismissedValue;
    setState(() => _stored = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(widget.prefsKey, value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_stored == widget.dismissedValue) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: widget.spacing),
      child: widget.builder(context, _close),
    );
  }
}
