import 'time.dart';

/// Calendar event, stored the way Google does: wall-clock + IANA zone for
/// timed events, plain dates for all-day events (end is EXCLUSIVE).
class CalEvent {
  CalEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    this.tzid,
    this.allDay = false,
    this.notes = '',
    this.location = '',
    this.rrule,
    List<DateTime> exdates = const [],
    this.recurringEventId,
    this.originalStart,
    this.cancelled = false,
    this.version = 1,
    this.googleId,
    this.etag,
    this.iCalUid,
  }) : exdates = List.unmodifiable(exdates),
       assert(allDay || tzid != null, 'timed events need an IANA zone'),
       assert(start.isUtc && end.isUtc, 'start/end are floating (UTC-flagged)'),
       assert(!end.isBefore(start), 'end before start');

  final String id;
  final String calendarId;
  final String title;
  final String notes;
  final String location;

  /// Floating wall-clock start/end. For all-day events only y/m/d matter and
  /// [end] is the exclusive end date.
  final DateTime start;
  final DateTime end;
  final String? tzid;
  final bool allDay;

  /// RFC 5545 RRULE line (with or without the "RRULE:" prefix).
  final String? rrule;
  final List<DateTime> exdates; // floating
  /// Set on an exception instance: id of the series master + original start.
  final String? recurringEventId;
  final DateTime? originalStart; // floating
  final bool cancelled;

  /// Optimistic-concurrency counter; bump on every local change.
  final int version;

  // Google linkage (kept so sync never creates duplicates).
  final String? googleId;
  final String? etag;
  final String? iCalUid;

  bool get isRecurring => rrule != null && rrule!.isNotEmpty;
  bool get isException => recurringEventId != null;

  /// Real instants (UTC). All-day events are anchored at UTC midnight so they
  /// sort consistently; they never shift with the viewer's zone.
  DateTime get startUtc => allDay ? start : resolveWallClock(tzid!, start);
  DateTime get endUtc => allDay ? end : resolveWallClock(tzid!, end);

  CalEvent copyWith({
    String? title,
    String? notes,
    String? location,
    DateTime? start,
    DateTime? end,
    String? tzid,
    bool? allDay,
    String? rrule,
    bool clearRrule = false,
    List<DateTime>? exdates,
    bool? cancelled,
    String? googleId,
    String? etag,
    String? iCalUid,
    String? id,
    String? recurringEventId,
    DateTime? originalStart,
    bool bumpVersion = true,
  }) => CalEvent(
    id: id ?? this.id,
    calendarId: calendarId,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    location: location ?? this.location,
    start: start ?? this.start,
    end: end ?? this.end,
    tzid: tzid ?? this.tzid,
    allDay: allDay ?? this.allDay,
    rrule: clearRrule ? null : (rrule ?? this.rrule),
    exdates: exdates ?? this.exdates,
    recurringEventId: recurringEventId ?? this.recurringEventId,
    originalStart: originalStart ?? this.originalStart,
    cancelled: cancelled ?? this.cancelled,
    version: bumpVersion ? version + 1 : version,
    googleId: googleId ?? this.googleId,
    etag: etag ?? this.etag,
    iCalUid: iCalUid ?? this.iCalUid,
  );
}

/// One concrete occurrence of an event inside a time window.
class Occurrence {
  const Occurrence({
    required this.eventId,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    required this.originalStart,
    required this.allDay,
    this.tzid,
    this.isOverride = false,
  });
  final String eventId;
  final String title;
  final DateTime startUtc;
  final DateTime endUtc;
  final DateTime originalStart; // floating, identifies the instance in a series
  final bool allDay;
  final String? tzid;
  final bool isOverride;

  bool overlaps(DateTime from, DateTime to) =>
      endUtc.isAfter(from) && startUtc.isBefore(to);
}
