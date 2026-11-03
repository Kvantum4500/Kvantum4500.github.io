import 'package:rrule/rrule.dart';

import 'event.dart';
import 'time.dart';

const _maxIterations = 20000; // hard stop for runaway/infinite rules

RecurrenceRule parseRule(String rule) {
  final s = rule.trim();
  return RecurrenceRule.fromString(s.startsWith('RRULE:') ? s : 'RRULE:$s');
}

/// Expands [master] (+ its exception instances) into occurrences overlapping
/// [from]..[to] (UTC instants).
///
/// Recurrence is evaluated on FLOATING wall-clock time and converted to
/// instants per occurrence, so "every Monday 09:00" stays 09:00 across DST.
/// Duration of timed events is real elapsed time (1 h stays 1 h over a switch).
List<Occurrence> expand(
  CalEvent master,
  DateTime from,
  DateTime to, {
  List<CalEvent> overrides = const [],
}) {
  if (master.cancelled) return const [];
  assert(from.isUtc && to.isUtc);
  final byOriginal = <DateTime, CalEvent>{
    for (final o in overrides)
      if (o.originalStart != null) o.originalStart!: o,
  };
  final exdates = master.exdates.toSet();
  final out = <Occurrence>[];

  Occurrence build(
    CalEvent e,
    DateTime wallStart,
    DateTime original, {
    required bool isOverride,
  }) {
    if (master.allDay && !isOverride) {
      final days = master.end.difference(master.start);
      return Occurrence(
        eventId: e.id,
        title: e.title,
        startUtc: wallStart,
        endUtc: wallStart.add(days),
        originalStart: original,
        allDay: true,
      );
    }
    if (isOverride) {
      return Occurrence(
        eventId: e.id,
        title: e.title,
        startUtc: e.startUtc,
        endUtc: e.endUtc,
        originalStart: original,
        allDay: e.allDay,
        tzid: e.tzid,
        isOverride: true,
      );
    }
    final s = resolveWallClock(master.tzid!, wallStart);
    final duration = master.endUtc.difference(master.startUtc);
    return Occurrence(
      eventId: e.id,
      title: e.title,
      startUtc: s,
      endUtc: s.add(duration),
      originalStart: original,
      allDay: false,
      tzid: master.tzid,
    );
  }

  if (!master.isRecurring) {
    final o = build(master, master.start, master.start, isOverride: false);
    return o.overlaps(from, to) ? [o] : const [];
  }

  // +-1 day slack covers every zone offset between wall-clock and UTC.
  final limit = to.add(const Duration(days: 2));
  var n = 0;
  for (final wall in parseRule(
    master.rrule!,
  ).getInstances(start: master.start)) {
    if (wall.isAfter(limit) || ++n > _maxIterations) break;
    if (exdates.contains(wall)) continue;
    final override = byOriginal[wall];
    if (override != null) {
      if (override.cancelled) continue;
      final o = build(override, wall, wall, isOverride: true);
      if (o.overlaps(from, to)) out.add(o);
      continue;
    }
    final o = build(master, wall, wall, isOverride: false);
    if (o.overlaps(from, to)) out.add(o);
  }
  // Overrides moved INTO the window from an original date outside the scan.
  for (final o in overrides) {
    if (o.cancelled || o.originalStart == null) continue;
    if (out.any((x) => x.originalStart == o.originalStart)) continue;
    if (o.originalStart!.isAfter(limit)) {
      final occ = build(
        o,
        o.originalStart!,
        o.originalStart!,
        isOverride: true,
      );
      if (occ.overlaps(from, to)) out.add(occ);
    }
  }
  out.sort((a, b) => a.startUtc.compareTo(b.startUtc));
  return out;
}

/// "This and following": ends [master]'s series right before [splitAt]
/// (floating original start of the first changed instance) and returns the
/// truncated master. COUNT rules are converted so totals stay correct.
/// Returns null if [splitAt] is the very first instance (series is replaced).
CalEvent? truncateSeries(CalEvent master, DateTime splitAt) {
  final rule = parseRule(master.rrule!);
  final before = rule
      .getInstances(start: master.start)
      .takeWhile((d) => d.isBefore(splitAt))
      .take(_maxIterations)
      .toList();
  if (before.isEmpty) return null;
  final truncated = RecurrenceRule(
    frequency: rule.frequency,
    interval: rule.interval,
    count: rule.count == null ? null : before.length,
    until: rule.count == null ? before.last : null,
    byWeekDays: rule.byWeekDays,
    byMonthDays: rule.byMonthDays,
    byMonths: rule.byMonths,
    byWeeks: rule.byWeeks,
    byYearDays: rule.byYearDays,
    bySetPositions: rule.bySetPositions,
    byHours: rule.byHours,
    byMinutes: rule.byMinutes,
    bySeconds: rule.bySeconds,
    weekStart: rule.weekStart,
  );
  return master.copyWith(rrule: truncated.toString());
}
