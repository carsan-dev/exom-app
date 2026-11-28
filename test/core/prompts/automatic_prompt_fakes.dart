// Test doubles shared by the automatic prompt tests (C5b, Sunday recap
// reminder). Not a test file: it has no `main` and is only imported.
import 'package:exom_app/core/prompts/automatic_prompt_coordinator.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';

/// In-memory [AutomaticPromptStore] keyed like LocalStorage: lower-cased
/// email, else `uid:<uid>`.
class FakeAutomaticPromptStore implements AutomaticPromptStore {
  final tutorialComplete = <String>{};
  final sundayOff = <String>{};
  final sundayLast = <String, String>{};

  @override
  String? identityFor({required String uid, String? email}) {
    final normalized = email?.trim().toLowerCase();
    if (normalized != null && normalized.isNotEmpty) return normalized;
    final trimmed = uid.trim();
    return trimmed.isEmpty ? null : 'uid:$trimmed';
  }

  @override
  Future<void> setTutorialComplete({required String uid, String? email}) async {
    tutorialComplete.add(identityFor(uid: uid, email: email)!);
  }

  @override
  bool isRecapSundayPromptOff({required String uid, String? email}) =>
      sundayOff.contains(identityFor(uid: uid, email: email));

  @override
  Future<void> setRecapSundayPromptOff({
    required String uid,
    String? email,
  }) async {
    sundayOff.add(identityFor(uid: uid, email: email)!);
  }

  @override
  String? recapSundayPromptLast({required String uid, String? email}) =>
      sundayLast[identityFor(uid: uid, email: email)];

  @override
  Future<void> setRecapSundayPromptLast({
    required String uid,
    String? email,
    required String day,
  }) async {
    sundayLast[identityFor(uid: uid, email: email)!] = day;
  }
}

/// Recap loader whose answer the test controls; counts the calls.
class FakeRecapLoader {
  List<RecapEntity> recaps = const [];
  Object? error;
  int calls = 0;

  Future<List<RecapEntity>> call() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return recaps;
  }
}

/// Sunday 22 Nov 2026 (week Mon 16 .. Sun 22), mid-morning local time.
final sunday = DateTime(2026, 11, 22, 10, 30);
final monday = DateTime(2026, 11, 23, 9);
final nextSunday = DateTime(2026, 11, 29, 11);

RecapEntity recapOfWeek(DateTime monday, String status, {String id = 'r1'}) =>
    RecapEntity(
      id: id,
      weekStartDate: DateTime.utc(monday.year, monday.month, monday.day),
      weekEndDate: DateTime.utc(monday.year, monday.month, monday.day + 6),
      status: status,
      createdAt: DateTime.utc(2026, 11, 20),
    );

final thisWeekMonday = DateTime(2026, 11, 16);
