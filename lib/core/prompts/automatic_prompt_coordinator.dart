import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';

/// Automatic prompts the shell may open on its own over /home.
enum AutomaticPrompt { none, tutorial, recapSunday }

typedef RecapListLoader = Future<List<RecapEntity>> Function();

/// What the prompts persist, per user identity. Only the tutorial flag and
/// the two Sunday reminder keys; nothing else.
abstract interface class AutomaticPromptStore {
  /// `null` when no identity can be resolved: no prompt is decided then.
  String? identityFor({required String uid, String? email});

  Future<void> setTutorialComplete({required String uid, String? email});

  bool isRecapSundayPromptOff({required String uid, String? email});

  Future<void> setRecapSundayPromptOff({required String uid, String? email});

  String? recapSundayPromptLast({required String uid, String? email});

  Future<void> setRecapSundayPromptLast({
    required String uid,
    String? email,
    required String day,
  });
}

/// [AutomaticPromptStore] over the Hive settings box of [LocalStorage].
class LocalStorageAutomaticPromptStore implements AutomaticPromptStore {
  const LocalStorageAutomaticPromptStore(this._storage);

  final LocalStorage _storage;

  @override
  String? identityFor({required String uid, String? email}) =>
      _storage.resolveOnboardingIdentity(uid: uid, email: email);

  @override
  Future<void> setTutorialComplete({required String uid, String? email}) =>
      _storage.setTutorialCompleteFor(uid: uid, email: email);

  @override
  bool isRecapSundayPromptOff({required String uid, String? email}) =>
      _storage.isRecapSundayPromptOffFor(uid: uid, email: email);

  @override
  Future<void> setRecapSundayPromptOff({required String uid, String? email}) =>
      _storage.setRecapSundayPromptOffFor(uid: uid, email: email);

  @override
  String? recapSundayPromptLast({required String uid, String? email}) =>
      _storage.recapSundayPromptLastFor(uid: uid, email: email);

  @override
  Future<void> setRecapSundayPromptLast({
    required String uid,
    String? email,
    required String day,
  }) => _storage.setRecapSundayPromptLastFor(uid: uid, email: email, day: day);
}

/// What the shell knows about the signed-in user when it may prompt.
class AutomaticPromptSession {
  const AutomaticPromptSession({
    required this.uid,
    required this.email,
    required this.tutorialDue,
  });

  final String uid;
  final String? email;

  /// The quick-tour prompt is due (onboarding settled, tour not complete).
  final bool tutorialDue;
}

const _sentRecapStatuses = {'SUBMITTED', 'REVIEWED'};

/// Whether [recaps] hold a sent (SUBMITTED or REVIEWED) recap for the
/// Monday..Sunday week containing [day] (local calendar date), matched like the
/// recap page does: same start and end dates.
bool isRecapSentForWeekOf(List<RecapEntity> recaps, DateTime day) {
  final weekStart = DateTime(day.year, day.month, day.day - (day.weekday - 1));
  final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  bool sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  return recaps.any(
    (recap) =>
        _sentRecapStatuses.contains(recap.status) &&
        sameDate(recap.weekStartDate, weekStart) &&
        sameDate(recap.weekEndDate, weekEnd),
  );
}

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Decides which automatic prompt (if any) the shell opens, for one app
/// launch. One instance lives for the process: its in-memory state is the
/// "session" (at most one prompt per identity, and a tutorial skipped without
/// «No volver a mostrar» is not offered again until the next launch).
class AutomaticPromptCoordinator {
  AutomaticPromptCoordinator({
    required AutomaticPromptStore store,
    required RecapListLoader loadRecaps,
    required DateTime Function() clock,
    this.recapFetchTimeout = const Duration(seconds: 8),
  }) : _store = store,
       _loadRecaps = loadRecaps,
       _clock = clock;

  final AutomaticPromptStore _store;
  final RecapListLoader _loadRecaps;
  final DateTime Function() _clock;

  /// A recap fetch slower than this counts as failed, so a due quick tour is
  /// not held back by a slow network.
  final Duration recapFetchTimeout;

  /// Identities that already got an automatic prompt in this session.
  final Set<String> _prompted = {};
  final Set<String> _inFlight = {};

  /// The prompt to show now for the user, at most one per session.
  ///
  /// On a local Sunday, when the reminder is not switched off and was not
  /// shown yet that day, this week's recap status is fetched first: not sent
  /// → the Sunday reminder (it wins over a due quick tour, which waits for the
  /// next launch) and the day is recorded. Sent, fetch error or timeout →
  /// nothing recorded, and the quick tour if it is due. Other days → the quick
  /// tour if due. [isStillCurrent] is re-checked after the fetch: when it
  /// returns false (identity switched, shell left /home) nothing is shown or
  /// recorded, so the caller may check again later.
  Future<AutomaticPrompt> nextPrompt({
    required String uid,
    String? email,
    required bool tutorialDue,
    bool Function()? isStillCurrent,
  }) async {
    final identity = _store.identityFor(uid: uid, email: email);
    if (identity == null ||
        _prompted.contains(identity) ||
        _inFlight.contains(identity)) {
      return AutomaticPrompt.none;
    }

    final now = _clock();
    final today = _dayKey(now);
    final sundayCandidate =
        now.weekday == DateTime.sunday &&
        !_store.isRecapSundayPromptOff(uid: uid, email: email) &&
        _store.recapSundayPromptLast(uid: uid, email: email) != today;
    if (!sundayCandidate) {
      if (!tutorialDue) return AutomaticPrompt.none;
      _prompted.add(identity);
      return AutomaticPrompt.tutorial;
    }

    _inFlight.add(identity);
    try {
      bool? sent;
      try {
        final recaps = await _loadRecaps().timeout(recapFetchTimeout);
        sent = isRecapSentForWeekOf(recaps, now);
      } catch (_) {
        // Offline, server error or timeout: no reminder this time (retried
        // on the next open), the tour may still be offered.
        sent = null;
      }
      if (isStillCurrent != null && !isStillCurrent()) {
        return AutomaticPrompt.none;
      }
      if (sent == false) {
        _prompted.add(identity);
        await _store.setRecapSundayPromptLast(
          uid: uid,
          email: email,
          day: today,
        );
        return AutomaticPrompt.recapSunday;
      }
      if (!tutorialDue) return AutomaticPrompt.none;
      _prompted.add(identity);
      return AutomaticPrompt.tutorial;
    } finally {
      _inFlight.remove(identity);
    }
  }

  /// «Omitir» on the quick-tour prompt: only with «No volver a mostrar» is it
  /// persisted (as `tutorial_complete`); otherwise it returns next launch.
  Future<void> resolveTutorialSkip({
    required String uid,
    String? email,
    required bool dontShowAgain,
  }) async {
    if (dontShowAgain) {
      await _store.setTutorialComplete(uid: uid, email: email);
    }
  }

  /// «Omitir» or «Rellenar recap» on the Sunday reminder: with «No volver a
  /// mostrar» it never shows again for that user.
  Future<void> resolveRecapSundayPrompt({
    required String uid,
    String? email,
    required bool dontShowAgain,
  }) async {
    if (dontShowAgain) {
      await _store.setRecapSundayPromptOff(uid: uid, email: email);
    }
  }
}
