import 'package:kvantum_core/kvantum_core.dart';
import 'package:test/test.dart';

const bp = 'Europe/Budapest';
CalEvent timed(
  String id,
  DateTime s,
  DateTime e, {
  String? rrule,
  List<DateTime> ex = const [],
}) => CalEvent(
  id: id,
  calendarId: 'c',
  title: id,
  start: s,
  end: e,
  tzid: bp,
  rrule: rrule,
  exdates: ex,
);

void main() {
  setUpAll(ensureTimeZones);

  group('DST', () {
    test('spring gap 02:30 on 2026-03-29 moves forward to 03:30 local', () {
      final i = resolveWallClock(bp, floating(2026, 3, 29, 2, 30));
      expect(toWallClock(bp, i), floating(2026, 3, 29, 3, 30));
    });
    test(
      'autumn overlap 02:30 on 2026-10-25 picks the first (summer) occurrence',
      () {
        final i = resolveWallClock(bp, floating(2026, 10, 25, 2, 30));
        expect(i, DateTime.utc(2026, 10, 25, 0, 30)); // CEST = UTC+2
      },
    );
    test('day length is 23 / 25 / 24 hours', () {
      expect(dayLength(bp, floating(2026, 3, 29)), const Duration(hours: 23));
      expect(dayLength(bp, floating(2026, 10, 25)), const Duration(hours: 25));
      expect(dayLength(bp, floating(2026, 6, 1)), const Duration(hours: 24));
    });
    test('weekly Monday 09:00 stays 09:00 local across the switch', () {
      final e = timed(
        'w',
        floating(2026, 3, 23, 9),
        floating(2026, 3, 23, 10),
        rrule: 'FREQ=WEEKLY;BYDAY=MO',
      );
      final occ = expand(
        e,
        DateTime.utc(2026, 3, 20),
        DateTime.utc(2026, 4, 10),
      );
      expect(occ.length, 3);
      for (final o in occ) {
        expect(toWallClock(bp, o.startUtc).hour, 9);
        expect(o.endUtc.difference(o.startUtc), const Duration(hours: 1));
      }
      // 23.03 is UTC+1 (08:00Z), 30.03 is UTC+2 (07:00Z)
      expect(occ[0].startUtc.hour, 8);
      expect(occ[1].startUtc.hour, 7);
    });
  });

  group('recurrence', () {
    test('monthly on the 31st skips short months', () {
      final e = timed(
        'm',
        floating(2026, 1, 31, 8),
        floating(2026, 1, 31, 9),
        rrule: 'FREQ=MONTHLY;BYMONTHDAY=31',
      );
      final occ = expand(e, DateTime.utc(2026, 1, 1), DateTime.utc(2026, 6, 1));
      expect(occ.map((o) => o.originalStart.month), [1, 3, 5]);
    });
    test('yearly Feb 29 only on leap years', () {
      final e = timed(
        'l',
        floating(2024, 2, 29, 8),
        floating(2024, 2, 29, 9),
        rrule: 'FREQ=YEARLY',
      );
      final occ = expand(e, DateTime.utc(2024, 1, 1), DateTime.utc(2033, 1, 1));
      expect(occ.map((o) => o.originalStart.year), [2024, 2028, 2032]);
    });
    test('last Friday of month (BYSETPOS)', () {
      final e = timed(
        'f',
        floating(2026, 1, 30, 8),
        floating(2026, 1, 30, 9),
        rrule: 'FREQ=MONTHLY;BYDAY=FR;BYSETPOS=-1',
      );
      final occ = expand(e, DateTime.utc(2026, 1, 1), DateTime.utc(2026, 4, 1));
      expect(occ.map((o) => o.originalStart.day), [30, 27, 27]);
    });
    test('EXDATE removes an instance', () {
      final e = timed(
        'x',
        floating(2026, 5, 4, 9),
        floating(2026, 5, 4, 10),
        rrule: 'FREQ=DAILY;COUNT=5',
        ex: [floating(2026, 5, 6, 9)],
      );
      final occ = expand(e, DateTime.utc(2026, 5, 1), DateTime.utc(2026, 6, 1));
      expect(occ.length, 4);
    });
    test('override moves one instance, cancelled override removes one', () {
      final m = timed(
        's',
        floating(2026, 5, 4, 9),
        floating(2026, 5, 4, 10),
        rrule: 'FREQ=DAILY;COUNT=4',
      );
      final moved = CalEvent(
        id: 's-o1',
        calendarId: 'c',
        title: 'moved',
        tzid: bp,
        start: floating(2026, 5, 5, 15),
        end: floating(2026, 5, 5, 16),
        recurringEventId: 's',
        originalStart: floating(2026, 5, 5, 9),
      );
      final gone = CalEvent(
        id: 's-o2',
        calendarId: 'c',
        title: 'gone',
        tzid: bp,
        cancelled: true,
        start: floating(2026, 5, 6, 9),
        end: floating(2026, 5, 6, 10),
        recurringEventId: 's',
        originalStart: floating(2026, 5, 6, 9),
      );
      final occ = expand(
        m,
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 6, 1),
        overrides: [moved, gone],
      );
      expect(occ.length, 3);
      expect(occ.where((o) => o.title == 'moved').single.startUtc.hour, 13);
    });
    test(
      'this-and-following: UNTIL series is truncated; COUNT is converted',
      () {
        final m = timed(
          't',
          floating(2026, 5, 4, 9),
          floating(2026, 5, 4, 10),
          rrule: 'FREQ=DAILY;COUNT=10',
        );
        final cut = truncateSeries(m, floating(2026, 5, 8, 9))!;
        final occ = expand(
          cut,
          DateTime.utc(2026, 5, 1),
          DateTime.utc(2026, 7, 1),
        );
        expect(occ.length, 4);
        expect(truncateSeries(m, floating(2026, 5, 4, 9)), isNull);
      },
    );
    test('infinite rule over a window stays bounded', () {
      final e = timed(
        'i',
        floating(2026, 1, 1, 9),
        floating(2026, 1, 1, 10),
        rrule: 'FREQ=DAILY',
      );
      expect(
        expand(e, DateTime.utc(2026, 12, 28), DateTime.utc(2027, 1, 4)).length,
        7,
      );
    });
  });

  group('all-day and year boundary', () {
    test('multi-day all-day event crossing New Year, exclusive end', () {
      final e = CalEvent(
        id: 'a',
        calendarId: 'c',
        title: 'a',
        allDay: true,
        start: floating(2026, 12, 30),
        end: floating(2027, 1, 2),
      );
      final occ = expand(e, DateTime.utc(2027, 1, 1), DateTime.utc(2027, 1, 2));
      expect(occ.length, 1); // still covers Jan 1
      expect(
        expand(e, DateTime.utc(2027, 1, 2), DateTime.utc(2027, 1, 3)),
        isEmpty,
      );
    });
    test('event crossing midnight', () {
      final e = timed('n', floating(2026, 12, 31, 23), floating(2027, 1, 1, 1));
      // Query the LOCAL days (Budapest) on both sides of midnight.
      DateTime day(int y, int m, int d) =>
          resolveWallClock(bp, floating(y, m, d));
      expect(expand(e, day(2026, 12, 31), day(2027, 1, 1)).length, 1);
      expect(expand(e, day(2027, 1, 1), day(2027, 1, 2)).length, 1);
      expect(expand(e, day(2027, 1, 2), day(2027, 1, 3)), isEmpty);
    });
    test('ISO week 53 spans the year change', () {
      expect(isoWeekOf(DateTime.utc(2026, 12, 28)), const IsoWeek(2026, 53));
      expect(isoWeekOf(DateTime.utc(2027, 1, 3)), const IsoWeek(2026, 53));
      expect(isoWeekOf(DateTime.utc(2027, 1, 4)), const IsoWeek(2027, 1));
      expect(isoWeekOf(DateTime.utc(2024, 12, 30)), const IsoWeek(2025, 1));
    });
    test('startOfWeek honours weekStart', () {
      final d = DateTime.utc(2027, 1, 1); // Friday
      expect(startOfWeek(d), DateTime.utc(2026, 12, 28));
      expect(
        startOfWeek(d, weekStart: DateTime.sunday),
        DateTime.utc(2026, 12, 27),
      );
    });
  });

  group('reconcile (no duplicates)', () {
    final local = CalEvent(
      id: 'L1',
      calendarId: 'c',
      title: 't',
      tzid: bp,
      start: floating(2026, 5, 4, 9),
      end: floating(2026, 5, 4, 10),
      googleId: 'g1',
      etag: 'e1',
      iCalUid: 'u1',
    );
    RemoteEvent r({
      String g = 'g1',
      String etag = 'e1',
      String? app,
      String? uid,
      bool c = false,
    }) => RemoteEvent(
      calendarId: 'c',
      googleId: g,
      etag: etag,
      appEventId: app,
      iCalUid: uid,
      cancelled: c,
    );

    test('own write echoing back is ignored', () {
      expect(reconcile(r(), [local]).action, SyncAction.ignoreEcho);
    });
    test('changed etag updates the same local event', () {
      expect(reconcile(r(etag: 'e2'), [local]).localId, 'L1');
    });
    test('first echo of a locally created event links instead of creating', () {
      final fresh = local.copyWith(id: 'L2').copyWith(); // no google ids yet
      final unlinked = CalEvent(
        id: 'L2',
        calendarId: 'c',
        title: 't',
        tzid: bp,
        start: fresh.start,
        end: fresh.end,
      );
      final d = reconcile(r(g: 'gNew', app: 'L2'), [unlinked]);
      expect(d.action, SyncAction.link);
      expect(d.localId, 'L2');
    });
    test('unknown remote creates; unknown remote deletion is a no-op', () {
      expect(reconcile(r(g: 'zz'), [local]).action, SyncAction.create);
      expect(
        reconcile(r(g: 'zz', c: true), [local]).action,
        SyncAction.ignoreEcho,
      );
    });
    test('remote cancel deletes the linked event', () {
      expect(reconcile(r(c: true), [local]).action, SyncAction.delete);
    });
  });

  group('AI proposal rules', () {
    const rules = PlanRules();
    ProposedBlock block(int d, int h, {bool hard = false, int len = 1}) =>
        ProposedBlock(
          title: 'run$d$h',
          startUtc: resolveWallClock(bp, floating(2026, 5, d, h)),
          endUtc: resolveWallClock(bp, floating(2026, 5, d, h + len)),
          isHard: hard,
        );

    test('clean plan passes', () {
      expect(
        validateProposal(
          [block(4, 18), block(7, 18)],
          existing: [],
          rules: rules,
        ),
        isEmpty,
      );
    });
    test('sleep window, conflict+buffer, low energy, rest, weekly cap', () {
      final meeting = Occurrence(
        eventId: 'm',
        title: 'meet',
        allDay: false,
        startUtc: resolveWallClock(bp, floating(2026, 5, 4, 17)),
        endUtc: resolveWallClock(bp, floating(2026, 5, 4, 18)),
        originalStart: floating(2026, 5, 4, 17),
      );
      final v = validateProposal(
        [
          block(4, 22, len: 2),
          block(4, 18, hard: true),
          block(5, 18, hard: true),
          block(6, 18),
          block(7, 18),
          block(8, 18),
          block(9, 18),
        ],
        existing: [meeting],
        rules: rules,
        energyByDate: {floating(2026, 5, 5): 2},
      );
      final codes = v.map((x) => x.code).toSet();
      expect(
        codes,
        containsAll([
          'sleep_window',
          'conflict',
          'low_energy',
          'rest',
          'weekly_cap',
        ]),
      );
    });
    test('all-day events do not block workouts', () {
      final allDay = Occurrence(
        eventId: 'a',
        title: 'holiday',
        allDay: true,
        startUtc: DateTime.utc(2026, 5, 4),
        endUtc: DateTime.utc(2026, 5, 5),
        originalStart: floating(2026, 5, 4),
      );
      expect(
        validateProposal([block(4, 18)], existing: [allDay], rules: rules),
        isEmpty,
      );
    });
  });
}
