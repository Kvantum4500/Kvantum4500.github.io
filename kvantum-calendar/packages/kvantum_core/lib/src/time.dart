import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

export 'package:timezone/timezone.dart' show Location, TZDateTime;

bool _initialized = false;

/// Loads the IANA tz database once. Call before any zone-aware work.
void ensureTimeZones() {
  if (_initialized) return;
  tzdata.initializeTimeZones();
  _initialized = true;
}

tz.Location locationOf(String tzid) {
  ensureTimeZones();
  return tz.getLocation(tzid);
}

/// A wall-clock time ("floating", no zone) is represented as a UTC-flagged
/// [DateTime] whose fields are the wall-clock fields. This is also what the
/// `rrule` package expects, so recurrence math never sees DST.
DateTime floating(int y, int m, int d, [int h = 0, int mi = 0, int s = 0]) =>
    DateTime.utc(y, m, d, h, mi, s);

/// Resolves a floating wall-clock time in [tzid] to a real instant (UTC).
///
/// DST policy (documented, deterministic):
///  * Spring gap (time does not exist, e.g. 02:30 on 2026-03-29 Budapest):
///    shifted forward by the gap length (-> 03:30).
///  * Autumn overlap (time exists twice, e.g. 02:30 on 2026-10-25):
///    the first occurrence (still summer time) is used.
DateTime resolveWallClock(String tzid, DateTime wall) {
  final loc = locationOf(tzid);
  final t = tz.TZDateTime(
    loc,
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );
  final sameWall = _wallEquals(t, wall);
  if (!sameWall) {
    // Gap: the package already normalised it; verify it moved forward.
    return t.toUtc();
  }
  // Overlap check: the instant one hour/offset-diff earlier may show the same
  // wall time. Prefer the earlier instant.
  for (final back in const [Duration(hours: 1), Duration(minutes: 30)]) {
    final earlier = t.subtract(back);
    if (_wallEquals(tz.TZDateTime.from(earlier, loc), wall)) {
      return earlier.toUtc();
    }
  }
  return t.toUtc();
}

bool _wallEquals(DateTime a, DateTime wall) =>
    a.year == wall.year &&
    a.month == wall.month &&
    a.day == wall.day &&
    a.hour == wall.hour &&
    a.minute == wall.minute &&
    a.second == wall.second;

/// Converts an instant to the floating wall-clock in [tzid].
DateTime toWallClock(String tzid, DateTime instant) {
  final t = tz.TZDateTime.from(instant, locationOf(tzid));
  return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

/// Length of the calendar day [date] (floating y/m/d) in [tzid]: 23, 24 or 25 h.
Duration dayLength(String tzid, DateTime date) {
  final start = resolveWallClock(
    tzid,
    floating(date.year, date.month, date.day),
  );
  final next = date.add(const Duration(days: 1));
  final end = resolveWallClock(tzid, floating(next.year, next.month, next.day));
  return end.difference(start);
}
