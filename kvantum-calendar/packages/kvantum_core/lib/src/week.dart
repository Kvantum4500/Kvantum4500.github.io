/// ISO-8601 week helpers (Monday-based weeks, week 1 contains Jan 4th).
class IsoWeek {
  const IsoWeek(this.year, this.week);
  final int year; // the week-numbering year (can differ from calendar year)
  final int week; // 1..53
  @override
  bool operator ==(Object other) =>
      other is IsoWeek && other.year == year && other.week == week;
  @override
  int get hashCode => Object.hash(year, week);
  @override
  String toString() => '$year-W${week.toString().padLeft(2, '0')}';
}

IsoWeek isoWeekOf(DateTime d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  // Thursday of this week decides the week-year.
  final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
  final jan1 = DateTime.utc(thursday.year, 1, 1);
  final week = (thursday.difference(jan1).inDays ~/ 7) + 1;
  return IsoWeek(thursday.year, week);
}

/// First day of the week containing [d]; [weekStart] uses DateTime.monday..sunday.
DateTime startOfWeek(DateTime d, {int weekStart = DateTime.monday}) {
  final date = DateTime.utc(d.year, d.month, d.day);
  final diff = (date.weekday - weekStart + 7) % 7;
  return date.subtract(Duration(days: diff));
}
