// P-E3b-1: the last set of the active exercise, saved but still waiting for
// its video, survives Android destroying the activity (or the process) while
// the camera or the gallery is open. Bounded restoration: only that set (and
// the video the picker recovers with `retrieveLostData`) is restored, never the
// router; the page applies it when the same account reopens the same exercise
// of the same execution, and the video is queued once.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/pending_last_set_restoration.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'active_exercise_redesign_test.dart'
    show
        ActiveExerciseHandle,
        activeExerciseDraftKey,
        activeExerciseTrainingId,
        pumpActiveExercise;
import 'last_set_video_test_support.dart';

const _videoSheet = Key('last-set-video-sheet');
const _record = Key('last-set-video-record');
const _gallery = Key('last-set-video-gallery');
const _cancel = Key('last-set-video-cancel');
const _use = Key('last-set-video-use');
const _setSave = Key('set-sheet-save');
const _footer = ValueKey('footer-executing');

/// Set 3 of 3 executing, sets 1 and 2 saved (8 × 62,5 kg, RIR 2).
ActiveWorkoutHiveModel _seedLastSet() => ActiveWorkoutHiveModel(
  trainingId: activeExerciseTrainingId,
  exerciseId: activeExerciseDraftKey,
  currentSet: 3,
  completedSets: 2,
  lastWeightKg: 62.5,
  completedSetData: [
    for (var set = 1; set < 3; set++)
      {'set_number': set, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
  ],
);

Future<void> _frames(WidgetTester tester, [int count = 4]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ActiveExercisePage)));

/// The lost-data fake: what `retrieveLostData` answers and how often it ran.
class _LostData {
  Future<LostDataResponse> Function() answer = () async =>
      LostDataResponse.empty();
  int calls = 0;

  Future<LostDataResponse> call() {
    calls++;
    return answer();
  }
}

class _Restorable {
  _Restorable(this.h, this.queue, this.lost);
  final ActiveExerciseHandle h;
  final RecordingVideoQueue queue;
  final _LostData lost;
}

Future<_Restorable> _pump(WidgetTester tester) async {
  final queue = RecordingVideoQueue();
  final lost = _LostData();
  // On a device the user only reaches the page with the app in the
  // foreground; flutter_test starts with no lifecycle state at all (which is
  // what a recreated activity still covered by the picker reports, r3).
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final h = await pumpActiveExercise(
    tester,
    initialWeightKg: 62.5,
    seed: _seedLastSet(),
    requiresLastSetVideo: true,
    lastSetVideoReminder: true,
    registerExtra: () =>
        sl.registerSingleton<FeedbackUploadQueueService>(queue),
    wrapApp: (app) => RootRestorationScope(
      restorationId: 'exom',
      child: PendingLastSetRestoration(retrieveLostData: lost.call, child: app),
    ),
  );
  await _frames(tester);
  return _Restorable(h, queue, lost);
}

/// «Registrar serie» → 9 reps × 82,5 kg (RIR as prefilled, 2) → «Guardar
/// serie»: the video sheet opens and the set is not dispatched yet.
Future<void> _saveLastSetTyped(WidgetTester tester) async {
  await tester.tap(find.byKey(_footer));
  await _frames(tester, 3);
  await tester.enterText(find.byKey(const Key('set-sheet-count-field')), '9');
  await tester.enterText(
    find.byKey(const Key('set-sheet-weight-field')),
    '82,5',
  );
  await tester.pump();
  await tester.tap(find.byKey(_setSave));
  await _frames(tester, 6);
  expect(find.byKey(_videoSheet), findsOneWidget);
}

/// A picker that never answers: the camera is open when Android destroys
/// the activity.
List<int> _cameraStaysOpen(WidgetTester tester) =>
    mockVideoPicker(tester, (_) => Completer<String?>().future);

/// Android destroys and recreates the activity; the Dart state (except the
/// saved instance state) is gone, Hive (the fake store) is kept.
Future<void> _recreate(WidgetTester tester) async {
  await tester.restartAndRestore();
  await _frames(tester, 6);
}

Map<String, Object?> _lastSaved(ActiveExerciseHandle h) =>
    Map<String, Object?>.from(h.draft!.completedSetData.last);

File _tempVideo(String name) {
  final dir = Directory.systemTemp.createTempSync('p_e3b_1_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return File('${dir.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(const [0, 0, 0, 24, 102, 116, 121, 112]);
}

PendingLastSetStore _store(WidgetTester tester) =>
    _storeAt(tester, find.byType(ActiveExercisePage));

PendingLastSetStore _storeAt(WidgetTester tester, Finder finder) =>
    PendingLastSetRestoration.maybeOf(tester.element(finder))!;

/// The owner's last set (9 × 82,5) with the camera open; Android destroys the
/// activity (with [recreateAs] signed in when it comes back) and the picker
/// recovers [video].
Future<void> _recoverWithVideo(
  WidgetTester tester,
  _Restorable r,
  File video, {
  String? recreateAs,
}) async {
  _cameraStaysOpen(tester);
  await _saveLastSetTyped(tester);
  await tester.tap(find.byKey(_record));
  await _frames(tester);
  r.lost.answer = () async =>
      LostDataResponse(file: XFile(video.path), type: RetrieveType.video);
  if (recreateAs != null) r.h.sessionStamp = recreateAs;
  await _recreate(tester);
  expect(r.lost.calls, 1);
}

/// Leaves the exercise for home without destroying the activity.
Future<void> _leave(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(ActiveExercisePage))).go('/');
  await _frames(tester, 6);
  expect(find.byType(ActiveExercisePage), findsNothing);
  expect(find.text('home'), findsOneWidget);
}

Future<void> _reopen(WidgetTester tester) async {
  GoRouter.of(tester.element(find.text('home'))).go('/ex');
  await _frames(tester, 6);
  expect(find.byType(ActiveExercisePage), findsOneWidget);
}

void main() {
  group('P-E3b-1 bounded restoration', () {
    testWidgets('the typed last set survives the recreation: «Registrar '
        'serie» opens the video sheet, not the set sheet, and the set keeps '
        '9 × 82,5 kg', (tester) async {
      final r = await _pump(tester);
      mockVideoPicker(tester, (_) async => '/tmp/serie.mp4');
      await _saveLastSetTyped(tester);
      // Backgrounded with the video sheet open (no picker running).
      await tester.tap(find.byKey(_cancel));
      await _frames(tester, 6);

      await _recreate(tester);
      expect(r.h.draft!.completedSets, 2);
      // Only the set is restored, not the route stack or the sheet.
      expect(find.byKey(_videoSheet), findsNothing);
      expect(r.lost.calls, 0);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(find.byKey(_videoSheet), findsOneWidget);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls, hasLength(1));
      expect(r.h.draft!.completedSets, 3);
      expect(_lastSaved(r.h)['reps'], 9);
      expect(_lastSaved(r.h)['weight_kg'], 82.5);
      expect(_lastSaved(r.h)['rir'], 2);
      expect(r.h.draft!.lastSetFeedbackClientUploadId, 'fb-1');
    });

    testWidgets('a recovered video resumes «Vídeo preparado» and is queued '
        'once with the same fields; a later recreation queues nothing more', (
      tester,
    ) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_0001.mp4');
      final sources = _cameraStaysOpen(tester);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);
      expect(sources, [0]);

      r.lost.answer = () async =>
          LostDataResponse(file: XFile(video.path), type: RetrieveType.video);
      await _recreate(tester);
      expect(r.lost.calls, 1);
      expect(r.queue.calls, isEmpty);
      expect(r.h.draft!.completedSets, 2);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      final l10n = _l10n(tester);
      expect(find.byKey(_setSave), findsNothing);
      expect(find.text(l10n.videoReadyTitle.toUpperCase()), findsOneWidget);
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);

      expect(r.queue.calls, hasLength(1));
      final call = r.queue.calls.single;
      expect(call.path, video.path);
      expect(call.expectedSession, 'owner:1:test');
      expect(call.contentType, 'video/mp4');
      expect(call.mediaType, 'VIDEO');
      expect(call.feedbackKind, 'LAST_SET');
      expect(call.exerciseId, 'ex-1');
      expect(call.trainingId, activeExerciseTrainingId);
      expect(call.trainingExerciseId, 'te-1');
      expect(call.assignmentDate, '2026-11-18');
      expect(call.sessionId, isNull);
      expect(r.h.draft!.completedSets, 3);
      expect(_lastSaved(r.h)['reps'], 9);
      expect(_lastSaved(r.h)['weight_kg'], 82.5);
      expect(r.h.draft!.lastSetFeedbackClientUploadId, 'fb-1');
      // The entry is gone once the set is dispatched.
      expect(_store(tester).entries, isEmpty);

      await _recreate(tester);
      expect(r.lost.calls, 1);
      expect(r.queue.calls, hasLength(1));
      expect(r.h.draft!.completedSets, 3);
      expect(video.existsSync(), isTrue);
    });

    testWidgets('the open picker is in the saved state before the picker is '
        'called (Android saves it when the camera stops the activity)', (
      tester,
    ) async {
      final r = await _pump(tester);
      TestRestorationData? atPick;
      mockVideoPicker(tester, (_) {
        atPick = tester.binding.restorationManager.restorationData;
        return Completer<String?>().future;
      });
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);
      expect(atPick, isNotNull);
      expect(r.lost.calls, 0);
      // What Android would hand back if it destroyed the activity right then.
      await tester.restoreFrom(atPick!);
      // Asked right at the restore (r4: an empty answer is asked again
      // during the late-result window, which is let run out below).
      expect(r.lost.calls, 1);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a feedback already attached before the destruction is '
        'reused: no second enqueue', (tester) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_0002.mp4');
      _cameraStaysOpen(tester);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);
      // Hive already holds the queued feedback for this set (it was attached
      // right before the activity went away).
      final draft = r.h.draft!;
      r.h.draft = ActiveWorkoutHiveModel(
        trainingId: draft.trainingId,
        exerciseId: draft.exerciseId,
        currentSet: draft.currentSet,
        completedSets: draft.completedSets,
        lastWeightKg: draft.lastWeightKg,
        completedSetData: draft.completedSetData,
        lastSetFeedbackClientUploadId: 'fb-old',
      );
      r.lost.answer = () async =>
          LostDataResponse(file: XFile(video.path), type: RetrieveType.video);
      await _recreate(tester);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(r.queue.calls, isEmpty);
      expect(r.h.draft!.completedSets, 3);
      expect(_lastSaved(r.h)['reps'], 9);
      expect(r.h.draft!.lastSetFeedbackClientUploadId, 'fb-old');
    });

    testWidgets('an empty LostDataResponse recovers nothing: the set is kept, '
        'the sheet opens in the source, no notice', (tester) async {
      final r = await _pump(tester);
      _cameraStaysOpen(tester);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);

      r.lost.answer = () async => LostDataResponse.empty();
      await _recreate(tester);
      // r4: asked at the restore and then during the late-result window
      // (every 250 ms for 5 s); nothing comes, so it ends as a cancel.
      await tester.pump(const Duration(seconds: 6));
      expect(r.lost.calls, 1 + 5000 ~/ 250);
      final l10n = _l10n(tester);
      expect(find.text(l10n.lastSetVideoRecoveryError), findsNothing);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(find.byKey(_record), findsOneWidget);
      expect(find.byKey(_use), findsNothing);
      expect(r.queue.calls, isEmpty);
      expect(r.h.draft!.completedSets, 2);
    });

    testWidgets('a LostDataResponse with an error shows a notice and keeps '
        'the set; the video is asked again', (tester) async {
      final r = await _pump(tester);
      _cameraStaysOpen(tester);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);

      r.lost.answer = () async => LostDataResponse(
        exception: PlatformException(code: 'no_available_camera'),
        type: RetrieveType.video,
      );
      await _recreate(tester);
      final l10n = _l10n(tester);
      expect(find.text(l10n.lastSetVideoRecoveryError), findsOneWidget);
      expect(r.h.draft!.completedSets, 2);

      mockVideoPicker(tester, (_) async => '/tmp/otra.mp4');
      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(find.byKey(_record), findsOneWidget);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls.single.path, '/tmp/otra.mp4');
      expect(_lastSaved(r.h)['reps'], 9);
      expect(_lastSaved(r.h)['weight_kg'], 82.5);
    });

    testWidgets('a picker that throws while recovering is the same notice', (
      tester,
    ) async {
      final r = await _pump(tester);
      _cameraStaysOpen(tester);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);
      r.lost.answer = () =>
          Future<LostDataResponse>.error(StateError('lost picker data'));
      await _recreate(tester);
      expect(
        find.text(_l10n(tester).lastSetVideoRecoveryError),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('another account in between: nothing is applied nor queued; '
        'the entry and the file are kept for the owner', (tester) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_0003.mp4');
      _cameraStaysOpen(tester);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);

      r.lost.answer = () async =>
          LostDataResponse(file: XFile(video.path), type: RetrieveType.video);
      r.h.sessionStamp = 'other:0:test';
      await _recreate(tester);
      expect(find.text(_l10n(tester).lastSetVideoRecoveryError), findsNothing);
      // The other account gets the plain set sheet with nothing pending.
      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsOneWidget);
      expect(find.byKey(_videoSheet), findsNothing);
      await tester.tap(find.byKey(const Key('set-sheet-cancel')));
      await _frames(tester, 6);
      expect(r.queue.calls, isEmpty);
      expect(video.existsSync(), isTrue);
      expect(_store(tester).entryFor('owner', 'test')?.videoPath, video.path);

      // The owner signs in again (new process generation, same account).
      r.h.sessionStamp = 'owner:0:test';
      await _recreate(tester);
      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(
        find.text(_l10n(tester).videoReadyTitle.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls.single.path, video.path);
      expect(r.queue.calls.single.expectedSession, 'owner:0:test');
      expect(r.h.draft!.completedSets, 3);
    });

    testWidgets('an entry for another execution or a draft that moved on is '
        'not applied', (tester) async {
      final r = await _pump(tester);
      mockVideoPicker(tester, (_) async => null);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_cancel));
      await _frames(tester, 6);
      final entry = _store(tester).entryFor('owner', 'test')!;
      // Another execution of the same exercise.
      _store(tester).write(
        PendingLastSetEntry.fromJson({
          ...entry.toJson(),
          'session_id': 'another-execution',
        })!,
      );
      await tester.pump();
      await _recreate(tester);
      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsOneWidget);
      await tester.tap(find.byKey(const Key('set-sheet-cancel')));
      await _frames(tester, 6);

      // The same execution, but Hive is already at another set.
      _store(tester).write(entry);
      await tester.pump();
      final draft = r.h.draft!;
      r.h.draft = ActiveWorkoutHiveModel(
        trainingId: draft.trainingId,
        exerciseId: draft.exerciseId,
        currentSet: 2,
        completedSets: 1,
        lastWeightKg: draft.lastWeightKg,
        completedSetData: draft.completedSetData.take(1).toList(),
      );
      await _recreate(tester);
      expect(_store(tester).entries, isEmpty);
      expect(r.queue.calls, isEmpty);
      expect(r.h.trainingEvents.whereType<MarkExerciseCompleted>(), isEmpty);
    });

    testWidgets('without a restoration scope the page behaves as before', (
      tester,
    ) async {
      await pumpActiveExercise(
        tester,
        initialWeightKg: 62.5,
        seed: _seedLastSet(),
        requiresLastSetVideo: true,
        registerExtra: () => sl.registerSingleton<FeedbackUploadQueueService>(
          RecordingVideoQueue(),
        ),
      );
      await _frames(tester);
      expect(
        PendingLastSetRestoration.maybeOf(
          tester.element(find.byType(ActiveExercisePage)),
        ),
        isNull,
      );
      await _saveLastSetTyped(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('P-E3b-1 r2', () {
    testWidgets('a lost-data request that never answers ends after the cap: '
        'the video counts as lost (notice) and the set is kept', (
      tester,
    ) async {
      final r = await _pump(tester);
      _cameraStaysOpen(tester);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);

      r.lost.answer = () => Completer<LostDataResponse>().future;
      await _recreate(tester);
      expect(r.lost.calls, 1);
      await tester.pump(const Duration(seconds: 5));
      await _frames(tester, 6);
      expect(
        find.text(_l10n(tester).lastSetVideoRecoveryError),
        findsOneWidget,
      );
      expect(r.h.draft!.completedSets, 2);

      mockVideoPicker(tester, (_) async => '/tmp/otra.mp4');
      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(find.byKey(_record), findsOneWidget);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls.single.path, '/tmp/otra.mp4');
      expect(_lastSaved(r.h)['reps'], 9);
      expect(_lastSaved(r.h)['weight_kg'], 82.5);
    });

    testWidgets('a video already chosen in the sheet survives a recreation '
        'before «Usar vídeo»: the sheet comes back in «Vídeo preparado» with '
        'it and queues it once', (tester) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_0004.mp4');
      mockVideoPicker(tester, (_) async => video.path);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);
      expect(find.byKey(_use), findsOneWidget);
      expect(_store(tester).entryFor('owner', 'test')?.videoPath, video.path);

      await _recreate(tester);
      expect(r.lost.calls, 0);
      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(
        find.text(_l10n(tester).videoReadyTitle.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls.single.path, video.path);
      expect(r.h.draft!.completedSets, 3);
      expect(_lastSaved(r.h)['reps'], 9);
      expect(_store(tester).entries, isEmpty);
    });

    testWidgets('entries are kept per account: B leaving its own entry does '
        "not overwrite A's; back with A, A's set and video are applied", (
      tester,
    ) async {
      final r = await _pump(tester);
      final videoA = _tempVideo('VID_A.mp4');
      await _recoverWithVideo(tester, r, videoA, recreateAs: 'other:0:test');

      // B types its own last set and opens the camera; Android destroys the
      // activity again.
      await tester.tap(find.byKey(_footer));
      await _frames(tester, 3);
      expect(find.byKey(_setSave), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('set-sheet-count-field')),
        '7',
      );
      await tester.enterText(
        find.byKey(const Key('set-sheet-weight-field')),
        '50',
      );
      await tester.pump();
      await tester.tap(find.byKey(_setSave));
      await _frames(tester, 6);
      await tester.tap(find.byKey(_record));
      await _frames(tester);
      expect(_store(tester).entryFor('other', 'test')?.reps, 7);
      expect(_store(tester).entryFor('owner', 'test')?.videoPath, videoA.path);

      r.lost.answer = () async => LostDataResponse.empty();
      r.h.sessionStamp = 'owner:0:test';
      await _recreate(tester);
      // r4: the empty answer is asked again until the late-result window
      // runs out.
      await tester.pump(const Duration(seconds: 6));
      final other = _store(tester).entryFor('other', 'test');
      expect(other?.reps, 7);
      expect(other?.picking, isFalse);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(
        find.text(_l10n(tester).videoReadyTitle.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls.single.path, videoA.path);
      expect(r.queue.calls.single.expectedSession, 'owner:0:test');
      expect(_lastSaved(r.h)['reps'], 9);
      expect(_lastSaved(r.h)['weight_kg'], 82.5);
      // B's entry is still there for B.
      expect(_store(tester).entryFor('other', 'test')?.reps, 7);
      expect(_store(tester).entryFor('owner', 'test'), isNull);
    });

    testWidgets('leaving the page (or dismissing the sheet with the scrim) '
        'keeps what was recovered: reopening the exercise offers the same '
        'set and video', (tester) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_0005.mp4');
      await _recoverWithVideo(tester, r, video);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(
        find.text(_l10n(tester).videoReadyTitle.toUpperCase()),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(195, 20));
      await _frames(tester, 6);
      expect(find.byKey(_videoSheet), findsNothing);

      await _leave(tester);
      expect(
        _storeAt(tester, find.text('home')).entryFor('owner', 'test'),
        isA<PendingLastSetEntry>()
            .having((e) => e.reps, 'reps', 9)
            .having((e) => e.videoPath, 'videoPath', video.path),
      );
      await _reopen(tester);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(
        find.text(_l10n(tester).videoReadyTitle.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls.single.path, video.path);
      expect(_lastSaved(r.h)['reps'], 9);
      expect(_store(tester).entries, isEmpty);
    });

    testWidgets('«Cancelar» on the sheet with the recovered video is an '
        'explicit discard: the video is no longer offered, the set stays '
        'pending on the page and leaving drops it as before P-E3b-1', (
      tester,
    ) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_0006.mp4');
      await _recoverWithVideo(tester, r, video);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_use), findsOneWidget);
      await tester.tap(find.byKey(_cancel));
      await _frames(tester, 6);
      final kept = _store(tester).entryFor('owner', 'test');
      expect(kept?.reps, 9);
      expect(kept?.videoPath, isNull);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(find.byKey(_record), findsOneWidget);
      expect(find.byKey(_use), findsNothing);
      await tester.tap(find.byKey(_cancel));
      await _frames(tester, 6);

      await _leave(tester);
      expect(
        _storeAt(tester, find.text('home')).entryFor('owner', 'test'),
        isNull,
      );
      // The clip itself is never deleted here.
      expect(video.existsSync(), isTrue);
      await _reopen(tester);
      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsOneWidget);
      expect(r.queue.calls, isEmpty);
    });
  });

  // D1 (emulator, C3): the gallery's photo picker is a sheet over the app.
  // With the activity destroyed while it is open, relaunching the app
  // recreates the activity (and restores the entry) right away, under the
  // still-open picker: `retrieveLostData` answers empty because nothing has
  // been chosen yet. Only when the clip is chosen does the picker close, the
  // activity resume and the plugin store the clip, a little later (it copies
  // it off the main thread).
  group('P-E3b-1 r3 (D1: gallery under a recreated activity)', () {
    /// The owner's last set (9 × 82,5) with the gallery open; Android destroys
    /// the activity and brings it back with the picker still over it (no
    /// foreground yet). The first lost-data request answers empty.
    Future<void> recreateUnderOpenGallery(
      WidgetTester tester,
      _Restorable r,
    ) async {
      final sources = mockVideoPicker(
        tester,
        (_) => Completer<String?>().future,
      );
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      expect(sources, [ImageSource.gallery.index]);
      expect(_store(tester).entryFor('owner', 'test')?.picking, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      r.lost.answer = () async => LostDataResponse.empty();
      await _recreate(tester);
      expect(r.lost.calls, 1);
    }

    testWidgets('a clip chosen after the activity came back under the open '
        'gallery is recovered once the app resumes, even when the picker '
        'stores it late: «Vídeo preparado», queued once', (tester) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_G1.mp4');
      await recreateUnderOpenGallery(tester, r);
      // Still waiting for the picker: nothing decided, no notice.
      expect(_store(tester).entryFor('owner', 'test')?.picking, isTrue);
      expect(find.text(_l10n(tester).lastSetVideoRecoveryError), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(r.lost.calls, 1);

      // The clip is chosen: the picker closes and the activity resumes; the
      // plugin has not stored the clip yet.
      var stored = false;
      r.lost.answer = () async => stored
          ? LostDataResponse(file: XFile(video.path), type: RetrieveType.video)
          : LostDataResponse.empty();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(r.lost.calls, 2);
      stored = true;
      await _frames(tester, 6);
      final asked = r.lost.calls;
      expect(asked, greaterThan(2));
      expect(
        _store(tester).entryFor('owner', 'test'),
        isA<PendingLastSetEntry>()
            .having((e) => e.picking, 'picking', isFalse)
            .having((e) => e.videoPath, 'videoPath', video.path),
      );

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(
        find.text(_l10n(tester).videoReadyTitle.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls.single.path, video.path);
      expect(r.h.draft!.completedSets, 3);
      expect(_lastSaved(r.h)['reps'], 9);
      expect(_lastSaved(r.h)['weight_kg'], 82.5);
      expect(_store(tester).entries, isEmpty);

      // Nothing is asked again, nothing is queued again.
      await tester.pump(const Duration(seconds: 10));
      await _recreate(tester);
      expect(r.lost.calls, asked);
      expect(r.queue.calls, hasLength(1));
      expect(r.h.draft!.completedSets, 3);
    });

    testWidgets('the gallery cancelled under the recreated activity: once the '
        'app resumes and nothing comes, the set is kept, no notice, the '
        'sheet opens in the source', (tester) async {
      final r = await _pump(tester);
      await recreateUnderOpenGallery(tester, r);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 6));
      await _frames(tester, 6);
      final asked = r.lost.calls;
      expect(asked, greaterThan(1));
      expect(_store(tester).entryFor('owner', 'test')?.picking, isFalse);
      expect(find.text(_l10n(tester).lastSetVideoRecoveryError), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(r.lost.calls, asked);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(find.byKey(_record), findsOneWidget);
      expect(find.byKey(_use), findsNothing);
      expect(r.queue.calls, isEmpty);
      expect(r.h.draft!.completedSets, 2);
    });

    testWidgets('destroyed again while waiting for the gallery: the saved '
        'state still has the picker open, so the next recreation asks again '
        'and recovers the clip once', (tester) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_G2.mp4');
      await recreateUnderOpenGallery(tester, r);

      await _recreate(tester);
      expect(r.lost.calls, 2);
      expect(_store(tester).entryFor('owner', 'test')?.picking, isTrue);

      r.lost.answer = () async =>
          LostDataResponse(file: XFile(video.path), type: RetrieveType.video);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _frames(tester, 6);
      expect(r.lost.calls, 3);
      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls.single.path, video.path);
      expect(r.h.draft!.completedSets, 3);
      expect(tester.takeException(), isNull);
    });

  });

  // r4: the review's findings on r3.
  group('P-E3b-1 r4', () {
    /// Asks of one wait: the first one, then one every poll interval until
    /// the late-result window has passed.
    const maxAsks = 1 + 5000 ~/ 250;

    /// The owner's last set (9 × 82,5) with the camera open; Android destroys
    /// the activity, which comes back already in the foreground.
    Future<void> recreateAfterCamera(WidgetTester tester) async {
      _cameraStaysOpen(tester);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);
      await _recreate(tester);
    }

    testWidgets('F1: in the foreground, a result the plugin stores after the '
        'first (empty) answer is still recovered: «Vídeo preparado», queued '
        'once', (tester) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_F1.mp4');
      // An opaque picker (the camera, or GET_CONTENT on API <= 33): the
      // activity resumes before the plugin's executor stores the clip.
      var asked = 0;
      r.lost.answer = () async => ++asked < 3
          ? LostDataResponse.empty()
          : LostDataResponse(file: XFile(video.path), type: RetrieveType.video);
      await recreateAfterCamera(tester);
      await _frames(tester, 6);
      expect(r.lost.calls, 3);
      expect(
        _store(tester).entryFor('owner', 'test'),
        isA<PendingLastSetEntry>()
            .having((e) => e.picking, 'picking', isFalse)
            .having((e) => e.videoPath, 'videoPath', video.path),
      );

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(
        find.text(_l10n(tester).videoReadyTitle.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(r.queue.calls.single.path, video.path);
      expect(r.h.draft!.completedSets, 3);
      await tester.pump(const Duration(seconds: 10));
      expect(r.lost.calls, 3);
      expect(r.queue.calls, hasLength(1));
    });

    testWidgets('F1: in the foreground, nothing within the window is a '
        'cancel: the set is kept, no notice, the sheet opens in the source', (
      tester,
    ) async {
      final r = await _pump(tester);
      r.lost.answer = () async => LostDataResponse.empty();
      await recreateAfterCamera(tester);
      expect(_store(tester).entryFor('owner', 'test')?.picking, isTrue);
      await tester.pump(const Duration(seconds: 6));
      await _frames(tester, 6);
      expect(_store(tester).entryFor('owner', 'test')?.picking, isFalse);
      final asked = r.lost.calls;
      expect(asked, maxAsks);
      await tester.pump(const Duration(seconds: 10));
      expect(r.lost.calls, asked);
      expect(find.text(_l10n(tester).lastSetVideoRecoveryError), findsNothing);

      await tester.tap(find.byKey(_footer));
      await _frames(tester, 6);
      expect(find.byKey(_setSave), findsNothing);
      expect(find.byKey(_record), findsOneWidget);
      expect(find.byKey(_use), findsNothing);
      expect(r.queue.calls, isEmpty);
    });

    testWidgets('F2: destroyed again while the first request is in flight: '
        'the old store does not wait for the app to resume', (tester) async {
      final r = await _pump(tester);
      mockVideoPicker(tester, (_) => Completer<String?>().future);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final first = Completer<LostDataResponse>();
      r.lost.answer = () => first.future;
      await _recreate(tester);
      final old = tester.state(find.byType(PendingLastSetRestoration));
      expect(old, isA<WidgetsBindingObserver>());

      r.lost.answer = () async => LostDataResponse.empty();
      await _recreate(tester);
      first.complete(LostDataResponse.empty());
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.binding.removeObserver(old as WidgetsBindingObserver),
        isFalse,
      );
      expect(r.lost.calls, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('F3: destroyed while a request after the resume is in flight: '
        'its late answer is dropped, the old store is not used after dispose',
        (tester) async {
      final r = await _pump(tester);
      final video = _tempVideo('VID_F3.mp4');
      mockVideoPicker(tester, (_) => Completer<String?>().future);
      await _saveLastSetTyped(tester);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      r.lost.answer = () async => LostDataResponse.empty();
      await _recreate(tester);

      final inFlight = Completer<LostDataResponse>();
      r.lost.answer = () => inFlight.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 50));
      expect(r.lost.calls, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      r.lost.answer = () async => LostDataResponse.empty();
      await _recreate(tester);
      inFlight.complete(
        LostDataResponse(file: XFile(video.path), type: RetrieveType.video),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      // The new store still waits with the picker open.
      expect(_store(tester).entryFor('owner', 'test')?.picking, isTrue);
      expect(_store(tester).entryFor('owner', 'test')?.videoPath, isNull);
    });
  });

  group('PendingLastSetEntries (saved state, v2)', () {
    PendingLastSetEntry entryOf(String owner, {int reps = 9}) =>
        PendingLastSetEntry(
          ownerId: owner,
          environment: 'test',
          trainingId: 't',
          trainingExerciseId: 'te',
          assignmentDate: '2026-11-18',
          sessionId: null,
          setNumber: 3,
          reps: reps,
          seconds: null,
          weightKg: 82.5,
          rir: 2,
          skipped: false,
        );

    test('reads a v1 value (a single entry) as one entry', () {
      final v1 = jsonEncode(entryOf('a').toJson());
      expect(PendingLastSetEntries.decode(v1), [entryOf('a')]);
    });

    test('round-trips several accounts, oldest first', () {
      final entries = [entryOf('a'), entryOf('b')];
      final raw = PendingLastSetEntries.encode(entries);
      expect(jsonDecode(raw!), containsPair('v', 2));
      expect(PendingLastSetEntries.decode(raw), entries);
      expect(PendingLastSetEntries.encode(const []), isNull);
    });

    test('one entry per account: writing again replaces it and makes it the '
        'newest', () {
      var entries = PendingLastSetEntries.upsert(const [], entryOf('a'));
      entries = PendingLastSetEntries.upsert(entries, entryOf('b'));
      entries = PendingLastSetEntries.upsert(entries, entryOf('a', reps: 5));
      expect(entries, [entryOf('b'), entryOf('a', reps: 5)]);
    });

    test('at most ${PendingLastSetEntries.maxEntries} accounts: the oldest '
        'is dropped', () {
      var entries = const <PendingLastSetEntry>[];
      for (final owner in ['a', 'b', 'c', 'd']) {
        entries = PendingLastSetEntries.upsert(entries, entryOf(owner));
      }
      expect(entries.map((e) => e.ownerId), ['b', 'c', 'd']);
    });

    test('ignores malformed values and entries, keeps the valid ones', () {
      expect(PendingLastSetEntries.decode(null), isEmpty);
      expect(PendingLastSetEntries.decode('not json'), isEmpty);
      expect(PendingLastSetEntries.decode('{"v":3,"entries":[]}'), isEmpty);
      final raw = jsonEncode({
        'v': 2,
        'entries': [
          {'v': 1, 'owner_id': 'x'},
          entryOf('b').toJson(),
        ],
      });
      expect(PendingLastSetEntries.decode(raw), [entryOf('b')]);
    });
  });

  group('PendingLastSetEntry', () {
    const entry = PendingLastSetEntry(
      ownerId: 'owner',
      environment: 'test',
      trainingId: 't',
      trainingExerciseId: 'te',
      assignmentDate: '2026-11-18',
      sessionId: null,
      setNumber: 3,
      reps: 9,
      seconds: null,
      weightKg: 82.5,
      rir: 3,
      skipped: false,
      picking: true,
    );

    test('round-trips through JSON', () {
      expect(PendingLastSetEntry.fromJson(entry.toJson()), entry);
      final withVideo = entry.copyWith(picking: false, videoPath: '/v.mp4');
      expect(PendingLastSetEntry.fromJson(withVideo.toJson()), withVideo);
    });

    test('rejects other versions and malformed values', () {
      expect(PendingLastSetEntry.fromJson({...entry.toJson(), 'v': 2}), isNull);
      expect(
        PendingLastSetEntry.fromJson({...entry.toJson(), 'set_number': '3'}),
        isNull,
      );
      expect(PendingLastSetEntry.fromJson('x'), isNull);
    });

    test('belongs to the same account and environment only', () {
      expect(entry.belongsTo('owner', 'test'), isTrue);
      expect(entry.belongsTo('other', 'test'), isFalse);
      expect(entry.belongsTo('owner', 'prod'), isFalse);
      expect(entry.belongsTo(null, 'test'), isFalse);
    });
  });
}
