import 'event.dart';

/// What the sync engine does with a remote (Google) event.
enum SyncAction { create, update, link, ignoreEcho, delete }

class SyncDecision {
  const SyncDecision(this.action, [this.localId]);
  final SyncAction action;
  final String? localId;
  @override
  String toString() => '$action($localId)';
}

class RemoteEvent {
  const RemoteEvent({
    required this.calendarId,
    required this.googleId,
    required this.etag,
    this.appEventId,
    this.iCalUid,
    this.cancelled = false,
  });
  final String calendarId;
  final String googleId;
  final String etag;
  final String? appEventId; // extendedProperties.private.appEventId
  final String? iCalUid;
  final bool cancelled;
}

/// Decides how to apply a remote event without ever creating a duplicate.
/// Match order: stored link -> appEventId (our own write coming back) ->
/// iCalUID -> otherwise it is genuinely new.
SyncDecision reconcile(RemoteEvent r, Iterable<CalEvent> locals) {
  CalEvent? byLink, byApp, byUid;
  for (final l in locals) {
    if (l.calendarId == r.calendarId && l.googleId == r.googleId) byLink = l;
    if (r.appEventId != null && l.id == r.appEventId) byApp = l;
    if (r.iCalUid != null &&
        l.iCalUid == r.iCalUid &&
        l.calendarId == r.calendarId) {
      byUid = l;
    }
  }
  final match = byLink ?? byApp ?? byUid;
  if (match == null) {
    return r.cancelled
        ? const SyncDecision(
            SyncAction.ignoreEcho,
          ) // deleted something we never had
        : const SyncDecision(SyncAction.create);
  }
  if (r.cancelled) return SyncDecision(SyncAction.delete, match.id);
  if (match.googleId == null) return SyncDecision(SyncAction.link, match.id);
  if (match.etag == r.etag) {
    return SyncDecision(SyncAction.ignoreEcho, match.id);
  }
  return SyncDecision(SyncAction.update, match.id);
}
