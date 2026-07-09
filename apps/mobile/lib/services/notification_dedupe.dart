/// Prevents the same lifecycle event from producing two banners.
///
/// A challenge status change (e.g. a challenge going to REJECTED) can be
/// observed through two independent paths that race each other: the OneSignal
/// foreground push listener (instant) and the polling services'
/// ([InboxService]/[SentChallengesService]) periodic diffing (up to their
/// poll interval later, as a fallback for missed pushes). Both paths check
/// in here before showing a banner — whichever fires first "wins" and the
/// other is suppressed.
class NotificationDedupe {
  NotificationDedupe._();
  static final NotificationDedupe instance = NotificationDedupe._();

  static const _window = Duration(seconds: 20);

  final Map<String, DateTime> _recent = {};

  /// Returns true (and records [key]) if it was NOT recently marked — i.e.
  /// the caller should proceed and show its banner. Returns false if another
  /// path already handled this event within the dedupe window.
  bool tryMark(String key) {
    final now = DateTime.now();
    _recent.removeWhere((_, ts) => now.difference(ts) > _window);
    if (_recent.containsKey(key)) return false;
    _recent[key] = now;
    return true;
  }
}
