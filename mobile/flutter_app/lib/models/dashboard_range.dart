/// The period the dashboard's spending figures cover. Ranges are anchored to the latest month that has
/// data, not to today's date, so a statement that ended in September still has a "latest month".
enum DashboardRange { statement, latestMonth, previousMonth, last3Months }

extension DashboardRangeLabel on DashboardRange {
  String get label {
    switch (this) {
      case DashboardRange.statement:
        return 'Whole statement';
      case DashboardRange.latestMonth:
        return 'Latest month';
      case DashboardRange.previousMonth:
        return 'Month before';
      case DashboardRange.last3Months:
        return 'Last 3 months';
    }
  }

  /// (start, end) as yyyy-MM-dd for the API, or null for the whole statement.
  /// [latestMonth] is the newest month with data, formatted yyyy-MM.
  (String, String)? datesFor(String latestMonth) {
    if (this == DashboardRange.statement || latestMonth.length < 7) return null;
    final year = int.tryParse(latestMonth.substring(0, 4));
    final month = int.tryParse(latestMonth.substring(5, 7));
    if (year == null || month == null) return null;

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    DateTime lastDayOf(int y, int m) => DateTime(y, m + 1, 0);

    switch (this) {
      case DashboardRange.latestMonth:
        return (fmt(DateTime(year, month, 1)), fmt(lastDayOf(year, month)));
      case DashboardRange.previousMonth:
        final prev = DateTime(year, month - 1, 1);
        return (fmt(prev), fmt(lastDayOf(prev.year, prev.month)));
      case DashboardRange.last3Months:
        final first = DateTime(year, month - 2, 1);
        return (fmt(first), fmt(lastDayOf(year, month)));
      case DashboardRange.statement:
        return null;
    }
  }
}
