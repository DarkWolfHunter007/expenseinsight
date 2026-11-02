import 'package:intl/intl.dart';

/// "Just now", "5 min ago", "3 h ago", "Yesterday", then a short date.
String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = time.toLocal();
  final diff = current.difference(local);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && local.day == current.day) return '${diff.inHours} h ago';
  final yesterday = DateTime(current.year, current.month, current.day).subtract(const Duration(days: 1));
  if (DateTime(local.year, local.month, local.day) == yesterday) return 'Yesterday';
  return DateFormat(local.year == current.year ? 'd MMM' : 'd MMM yyyy').format(local);
}
