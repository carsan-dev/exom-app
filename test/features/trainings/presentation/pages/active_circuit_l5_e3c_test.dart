// L5-E3c «Última ronda y vídeo del circuito» (D17-6, L5-D23 iv, L5-D43): the
// circuit gets the same change E3b made on the active exercise. In the last
// round the old «Última serie» dialog becomes a band with «Recordármelo»
// (same preference, minimal line when off); saving the round opens the shared
// last-set video sheet («Grabar ahora», «Elegir de la galería», comment in the
// same sheet, «Cambiar» / «Usar vídeo», «Cancelar»). What is queued does not
// change: the same `enqueue` fields as before E3c and the missing videos still
// asked at the end, the same ones in the same order. The sheet opens only once
// the round is persisted (the circuit does not inherit P-E3b-1).
import 'dart:io';

import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/local_video_thumbnail.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_performance_sheet.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'circuit_test_harness.dart';
import 'last_set_video_test_support.dart' show mockVideoPicker;
import '../widgets/local_video_preview_fake.dart' show FakePreviewFactory;

const _footer = ValueKey('circuit-executing-footer');
const _reminderBand = Key('last-set-video-reminder');
const _reminderOff = Key('last-set-video-reminder-off');
const _videoSheet = Key('last-set-video-sheet');
const _record = Key('last-set-video-record');
const _gallery = Key('last-set-video-gallery');
const _cancel = Key('last-set-video-cancel');
const _change = Key('last-set-video-change');
const _comment = Key('last-set-video-comment');
const _use = Key('last-set-video-use');

final _a = circuitExercise('a', 'Burpees');
final _b = circuitExercise('b', 'Sentadilla con salto');

/// One-round circuit (its only round is the last one) with a required video.
Future<CircuitHarness> _pumpLastRound(
  WidgetTester tester, {
  bool reminder = true,
  bool requiresLastSetVideo = true,
  int rounds = 1,
  Map<String, dynamic>? restored,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  TextScaler? textScaler,
  String? sessionId,
}) async {
  final h = await pumpCircuit(
    tester,
    exercises: [_a, _b],
    rounds: rounds,
    requiresLastSetVideo: requiresLastSetVideo,
    lastSetVideoReminder: reminder,
    restored: restored,
    brightness: brightness,
    width: width,
    height: height,
    textScaler: textScaler,
    sessionId: sessionId,
  );
  await settleFrames(tester);
  return h;
}

AppLocalizations _l10n(WidgetTester tester) => circuitL10n(tester);

/// «Registrar serie» → «Guardar serie» on the current exercise.
Future<void> _saveRound(WidgetTester tester) async {
  await tester.tap(find.byKey(_footer));
  await settleFrames(tester, 3);
  expect(find.byType(SetPerformanceSheet), findsOneWidget);
  await tester.tap(find.byKey(const Key('set-sheet-save')));
  await settleFrames(tester, 6);
}

/// The missing-videos sheet at the end lists these trainingExercise ids.
List<String> _missingAtEnd(WidgetTester tester) => tester
    .widget<CircuitFeedbackForm>(find.byType(CircuitFeedbackForm))
    .targets
    .map((target) => target.key)
    .toList();

List<Object?> _loggedRounds(Map<String, dynamic> write, String id) =>
    ((write['performances'] as Map)[id] as List?) ?? const [];

void main() {
  group('reminder band (L5-D23 i, iv)', () {
    testWidgets('in the last round it is a band with the circuit copy and '
        '«Recordármelo» on, not a dialog, and nothing opens by itself', (
      tester,
    ) async {
      await _pumpLastRound(tester);
      final l10n = _l10n(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(_reminderBand), findsOneWidget);
      Finder inBand(String text) =>
          find.descendant(of: find.byKey(_reminderBand), matching: find.text(text));
      expect(inBand(l10n.lastSetReminderTitle.toUpperCase()), findsOneWidget);
      expect(inBand(l10n.lastSetReminderMessage('Burpees')), findsOneWidget);
      final row = tester.widget<ExomSwitchRow>(
        find.descendant(
          of: find.byKey(_reminderBand),
          matching: find.byType(ExomSwitchRow),
        ),
      );
      expect(row.label, l10n.lastSetVideoRemindMe);
      expect(row.value, isTrue);
      expect(find.byKey(_videoSheet), findsNothing);
    });

    testWidgets('tapping «Registrar serie» opens the set sheet, no dialog', (
      tester,
    ) async {
      await _pumpLastRound(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(_footer));
      await settleFrames(tester, 3);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.lastSetReminderTitle), findsNothing);
      expect(find.text(l10n.attachAtEnd), findsNothing);
      expect(find.byType(SetPerformanceSheet), findsOneWidget);
      expect(find.byKey(_videoSheet), findsNothing);
    });

    testWidgets('not before the last round nor without a required video', (
      tester,
    ) async {
      await _pumpLastRound(tester, rounds: 2);
      expect(find.byKey(_reminderBand), findsNothing);
      expect(find.byKey(_reminderOff), findsNothing);
      await _pumpLastRound(tester, requiresLastSetVideo: false);
      expect(find.byKey(_reminderBand), findsNothing);
      expect(find.byKey(_reminderOff), findsNothing);
    });

    testWidgets('not once the exercise has its video (restored state)', (
      tester,
    ) async {
      await _pumpLastRound(
        tester,
        restored: preL3State(
          feedbackIds: const {'a': 'fb-0'},
          feedbackStatuses: const {'a': 'completed'},
        ),
      );
      expect(find.byKey(_reminderBand), findsNothing);
      expect(find.byKey(_reminderOff), findsNothing);
    });

    testWidgets('turning it off saves false and leaves the minimal line; '
        'turning it on again saves true', (tester) async {
      final h = await _pumpLastRound(tester);
      final l10n = _l10n(tester);
      await tester.ensureVisible(find.text(l10n.lastSetVideoRemindMe));
      await tester.tap(find.text(l10n.lastSetVideoRemindMe));
      await settleFrames(tester);
      expect(h.storage.settings['last_set_video_reminder_enabled'], isFalse);
      expect(find.byKey(_reminderBand), findsNothing);
      expect(find.byKey(_reminderOff), findsOneWidget);
      final offNode = find.text(l10n.lastSetVideoReminderOption);
      expect(
        tester.getSemantics(offNode),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      expect(
        tester.getSize(find.byKey(_reminderOff)).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.byKey(_reminderOff));
      await settleFrames(tester);
      expect(h.storage.settings['last_set_video_reminder_enabled'], isTrue);
      expect(find.byKey(_reminderBand), findsOneWidget);
    });

    testWidgets('a failed save reverts the switch and says so (as E3b r2)', (
      tester,
    ) async {
      final h = await _pumpLastRound(tester);
      final l10n = _l10n(tester);
      h.storage.failSettingSaves = true;
      await tester.ensureVisible(find.text(l10n.lastSetVideoRemindMe));
      await tester.tap(find.text(l10n.lastSetVideoRemindMe));
      await settleFrames(tester);
      expect(find.byKey(_reminderBand), findsOneWidget);
      expect(find.byKey(_reminderOff), findsNothing);
      expect(h.storage.settings['last_set_video_reminder_enabled'], isTrue);
      expect(find.text(l10n.settingsSwitchDisableFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed save turning it on reverts to the minimal line', (
      tester,
    ) async {
      final h = await _pumpLastRound(tester, reminder: false);
      final l10n = _l10n(tester);
      expect(find.byKey(_reminderOff), findsOneWidget);
      h.storage.failSettingSaves = true;
      await tester.ensureVisible(find.byKey(_reminderOff));
      await tester.tap(find.byKey(_reminderOff));
      await settleFrames(tester);
      expect(find.byKey(_reminderOff), findsOneWidget);
      expect(find.byKey(_reminderBand), findsNothing);
      expect(h.storage.settings['last_set_video_reminder_enabled'], isFalse);
      expect(find.text(l10n.settingsSwitchEnableFailed), findsOneWidget);
    });
  });

  group('video sheet (L5-D23 ii-iii, iv)', () {
    testWidgets('saving the last round opens the shared straight sheet with '
        '«Grabar ahora», «Elegir de la galería» and «Cancelar»', (
      tester,
    ) async {
      final h = await _pumpLastRound(tester);
      final l10n = _l10n(tester);
      await _saveRound(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(l10n.lastSetVideoSheetKicker('Burpees', 1).toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(l10n.attachLastSetVideo.toUpperCase()), findsOneWidget);
      expect(
        tester.widget<ExomPrimaryButton>(find.byKey(_record)).label,
        l10n.recordNow,
      );
      expect(
        tester.widget<ExomTextLink>(find.byKey(_gallery)).label,
        l10n.chooseFromGallery,
      );
      expect(find.byKey(_cancel), findsOneWidget);
      // Nothing queued while the sheet is open.
      expect(h.queue.calls, isEmpty);
    });

    testWidgets('the round is saved before the sheet opens: with the camera '
        'open nothing typed lives only in memory (no P-E3b-1)', (tester) async {
      final h = await _pumpLastRound(tester);
      await _saveRound(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      // Exercise a's last round is already in the cache, without a video.
      expect(_loggedRounds(h.storage.lastWrite, 'a'), hasLength(1));
      expect(h.storage.lastWrite['feedback_ids'], isEmpty);
      expect(h.storage.lastWrite['exercise_index'], 1);
      await tester.tap(find.byKey(_cancel));
      await settleFrames(tester, 6);

      // Last exercise of the circuit: ready to finish is saved first too.
      await _saveRound(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(_loggedRounds(h.storage.lastWrite, 'b'), hasLength(1));
      expect(h.storage.lastWrite['ready_to_finish'], isTrue);
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(h.bloc.events, isEmpty);
    });

    testWidgets('gallery → comment in the same sheet → «Usar vídeo» queues '
        'the same fields as before E3c, once the round is saved', (
      tester,
    ) async {
      final sources = mockVideoPicker(tester, (_) async => '/tmp/ronda.mov');
      final h = await _pumpLastRound(tester, sessionId: 'session-1');
      final l10n = _l10n(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_gallery));
      await settleFrames(tester);
      expect(sources, [1]);
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.videoReadyTitle.toUpperCase()), findsOneWidget);
      expect(find.byKey(_record), findsNothing);
      expect(
        tester.getSemantics(find.byKey(_change)).label,
        l10n.changeVideoA11y,
      );
      await tester.enterText(find.byKey(_comment), '  Última ronda dura  ');
      await tester.pump();
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 6);

      expect(h.queue.calls, hasLength(1));
      final call = h.queue.calls.single;
      expect(call.path, '/tmp/ronda.mov');
      // r2 (2026-11-26): the page owner's session, as the active exercise;
      // every other field as before E3c.
      expect(call.expectedSession, 'owner:1:test');
      expect(call.contentType, 'video/quicktime');
      expect(call.mediaType, 'VIDEO');
      expect(call.notes, 'Última ronda dura');
      expect(call.exerciseId, 'ex-a');
      expect(call.feedbackKind, 'LAST_SET');
      expect(call.trainingId, circuitTrainingId);
      expect(call.trainingExerciseId, 'a');
      expect(call.assignmentDate, circuitDate);
      expect(call.sessionId, 'session-1');
      expect(find.byKey(_videoSheet), findsNothing);

      // Order: the round is written first, then the video id.
      final withVideo = h.storage.writes.indexWhere(
        (w) => (w['feedback_ids'] as Map).containsKey('a'),
      );
      final withRound = h.storage.writes.indexWhere(
        (w) => _loggedRounds(w, 'a').isNotEmpty,
      );
      expect(withRound, isNot(-1));
      expect(withVideo, greaterThan(withRound));
      expect(
        (h.storage.writes[withRound]['feedback_ids'] as Map).containsKey('a'),
        isFalse,
      );
      expect(_loggedRounds(h.storage.lastWrite, 'a'), hasLength(1));
      expect(h.storage.lastWrite['feedback_ids'], {'a': 'fb-1'});
      expect(h.storage.lastWrite['feedback_statuses'], {'a': 'queued'});
      // Next exercise, also in its last round: the band again, for it.
      expect(find.byKey(_reminderBand), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_reminderBand),
          matching: find.text(l10n.lastSetReminderMessage('Sentadilla con salto')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty comment queues notes null; a camera failure still '
        'offers the gallery', (tester) async {
      final sources = mockVideoPicker(tester, (source) async {
        if (source == 0) throw PlatformException(code: 'camera_unavailable');
        return '/tmp/ronda.mp4';
      });
      final h = await _pumpLastRound(tester);
      final l10n = _l10n(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_record));
      await settleFrames(tester);
      expect(sources, [0]);
      await tester.tap(find.text(l10n.feedbackFromGallery));
      await settleFrames(tester);
      expect(sources, [0, 1]);
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 6);
      expect(h.queue.calls.single.contentType, 'video/mp4');
      expect(h.queue.calls.single.notes, isNull);
    });

    testWidgets('«Cancelar» queues nothing and logs the round, as «Al '
        'terminar» did: the video is asked again at the end', (tester) async {
      final h = await _pumpLastRound(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_cancel));
      await settleFrames(tester, 6);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(h.queue.calls, isEmpty);
      expect(_loggedRounds(h.storage.lastWrite, 'a'), hasLength(1));
      expect(h.storage.lastWrite['feedback_ids'], isEmpty);
      // Exercise b: dismissing (scrim) is the same as «Cancelar».
      await _saveRound(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      // The scrim ignores taps until the sheet has entered (S11-09).
      await settleFrames(tester, 2);
      await tester.tapAt(const Offset(10, 10));
      await settleFrames(tester, 6);
      // Ready to finish: the same missing videos as before E3c, in order.
      expect(find.byType(CircuitFeedbackForm), findsOneWidget);
      expect(_missingAtEnd(tester), ['a', 'b']);
      expect(h.bloc.events, isEmpty);
      expect(h.queue.calls, isEmpty);
    });

    testWidgets('a video given in the round is not asked again at the end '
        '(no duplicates)', (tester) async {
      mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
      final h = await _pumpLastRound(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_gallery));
      await settleFrames(tester);
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 6);
      await _saveRound(tester);
      await tester.tap(find.byKey(_cancel));
      await settleFrames(tester, 6);
      expect(find.byType(CircuitFeedbackForm), findsOneWidget);
      expect(_missingAtEnd(tester), ['b']);
      expect(h.queue.calls, hasLength(1));
    });

    testWidgets('with «Recordármelo» off nothing is asked in the round (as '
        'before E3c); the videos are asked at the end', (tester) async {
      final h = await _pumpLastRound(tester, reminder: false);
      await _saveRound(tester);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(_loggedRounds(h.storage.lastWrite, 'a'), hasLength(1));
      await _saveRound(tester);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(_missingAtEnd(tester), ['a', 'b']);
      expect(h.queue.calls, isEmpty);
    });

    testWidgets('«Vídeo preparado» in the circuit shows the first frame and '
        'the duration (L5-E3d, same sheet)', (tester) async {
      final factory = FakePreviewFactory(duration: const Duration(seconds: 7));
      debugLocalVideoPreviewFactoryOverride = factory.call;
      addTearDown(() => debugLocalVideoPreviewFactoryOverride = null);
      debugResetLocalVideoDisposals();
      mockVideoPicker(tester, (_) async => '/tmp/ronda.mov');
      await _pumpLastRound(tester);
      final l10n = _l10n(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_gallery));
      await settleFrames(tester, 6);
      expect(find.text(l10n.videoReadyTitle.toUpperCase()), findsOneWidget);
      expect(factory.created.single.file.path, '/tmp/ronda.mov');
      expect(find.byType(LocalVideoThumbnail), findsOneWidget);
      expect(find.byKey(const Key('fake-video-frame')), findsOneWidget);
      final line = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().endsWith(' · 0:07'),
      );
      expect(line, findsOneWidget);
      expect(
        tester.widget<RichText>(line).text.toPlainText(),
        isNot(contains('. ·')),
      );
      await tester.tap(find.byKey(_cancel));
      await settleFrames(tester, 6);
      expect(factory.alive, 0);
    });

    testWidgets('«Cambiar» goes back to the source and queues nothing', (
      tester,
    ) async {
      mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
      final h = await _pumpLastRound(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_gallery));
      await settleFrames(tester);
      await tester.tap(find.byKey(_change));
      await settleFrames(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(find.byKey(_record), findsOneWidget);
      expect(find.byKey(_use), findsNothing);
      expect(h.queue.calls, isEmpty);
    });

    testWidgets('a double tap on «Usar vídeo» queues once', (tester) async {
      mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
      final h = await _pumpLastRound(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_gallery));
      await settleFrames(tester);
      await tester.tap(find.byKey(_use));
      await tester.tap(find.byKey(_use), warnIfMissed: false);
      await settleFrames(tester, 6);
      expect(h.queue.calls, hasLength(1));
      expect(_loggedRounds(h.storage.lastWrite, 'a'), hasLength(1));
    });

    testWidgets('a router location change closes the sheet without queuing '
        '(CC 11)', (tester) async {
      mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
      final h = await _pumpLastRound(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_gallery));
      await settleFrames(tester);
      GoRouter.of(tester.element(find.byType(ActiveCircuitPage))).go('/');
      await settleFrames(tester, 6);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(h.queue.calls, isEmpty);
      expect(h.bloc.events, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  // r2: the last round's video sheet stays open while a rest runs out (the
  // exercise has a rest, so the sheet opens during it). The rest timer reads
  // the wall clock, so these tests wait for it for real.
  group('rest ending with the video sheet open (r2)', () {
    /// Saves the only round of [exercises].first and opens the video sheet,
    /// then picks the gallery video when [pick].
    Future<CircuitHarness> pumpWithRest(
      WidgetTester tester, {
      required List<TrainingExerciseEntity> exercises,
      bool pick = true,
      bool Function(MarkExerciseCompleted event)? failWhen,
    }) async {
      mockVideoPicker(tester, (_) async => '/tmp/ronda.mp4');
      final h = await pumpCircuit(
        tester,
        exercises: exercises,
        rounds: 1,
        requiresLastSetVideo: true,
        lastSetVideoReminder: true,
        failWhen: failWhen,
      );
      await settleFrames(tester);
      await _saveRound(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      if (pick) {
        await tester.tap(find.byKey(_gallery));
        await settleFrames(tester);
        expect(find.byKey(_use), findsOneWidget);
      }
      return h;
    }

    /// Lets the 2 s rest run out under the open sheet.
    Future<void> outlastRest(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2600)),
      );
      await tester.pump(const Duration(seconds: 1));
      await settleFrames(tester, 6);
    }

    testWidgets('final rest: it only saves «ready to finish»; «Usar vídeo» '
        'queues once and the circuit completes once and closes', (
      tester,
    ) async {
      final h = await pumpWithRest(
        tester,
        exercises: [circuitExercise('b', 'Burpees', restSeconds: 2)],
      );
      await outlastRest(tester);
      // Nothing on top of the sheet and nothing completed yet.
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(h.bloc.events, isEmpty);
      expect(h.storage.lastWrite['ready_to_finish'], isTrue);
      expect(h.storage.lastWrite['status'], 'executing');

      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 10);
      expect(h.queue.calls, hasLength(1));
      expect(h.queue.calls.single.trainingExerciseId, 'b');
      expect(h.queue.calls.single.path, '/tmp/ronda.mp4');
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(h.bloc.completions, hasLength(1));
      expect(h.bloc.completions.single.lastSetFeedbackClientUploadId, 'fb-1');
      // The page closed, not just the sheet.
      expect(find.byType(ActiveCircuitPage), findsNothing);
      expect(find.text('detail'), findsOneWidget);
      expect(h.storage.removedKeys, [circuitStateKey()]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('r3: a throwing enqueue in the round shows circuitLastRoundVideoSaveError, '
        'keeps «ready to finish» and the retry asks for the video again', (
      tester,
    ) async {
      mockVideoPicker(tester, (_) async => '/tmp/ronda.mov');
      final h = await _pumpLastRound(tester, sessionId: 'session-1');
      final l10n = _l10n(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_gallery));
      await settleFrames(tester);
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 6);
      expect(h.queue.calls, hasLength(1));
      // The last exercise of the last round: its enqueue throws.
      h.queue.failNextEnqueue = StateError('enqueue boom');
      await _saveRound(tester);
      await tester.tap(find.byKey(_gallery));
      await settleFrames(tester);
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 6);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.circuitLastRoundVideoSaveError), findsOneWidget);
      expect(find.text(l10n.circuitSaveError), findsNothing);
      // r4: not covered by the missing-videos sheet (no rest: same path).
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(find.text(l10n.circuitLastRoundVideoSaveError).hitTestable(), findsOneWidget);
      expect(h.queue.calls, hasLength(1));
      expect(find.byType(ActiveCircuitPage), findsOneWidget);
      expect(h.storage.lastWrite['ready_to_finish'], isTrue);

      // Retry: «Terminar circuito» asks again for the video that is missing.
      await tester.tap(find.byKey(_footer));
      await settleFrames(tester, 6);
      expect(find.byType(CircuitFeedbackForm), findsOneWidget);
      expect(_missingAtEnd(tester), ['b']);
      expect(tester.takeException(), isNull);
      expect(h.queue.calls, hasLength(1));
    });

    testWidgets('r4 (D1): final rest over + a throwing enqueue: the '
        'circuitLastRoundVideoSaveError SnackBar is not covered by the missing-videos '
        'sheet; «Terminar circuito» then asks for the video', (tester) async {
      final h = await pumpWithRest(
        tester,
        exercises: [circuitExercise('b', 'Burpees', restSeconds: 2)],
      );
      final l10n = _l10n(tester);
      await outlastRest(tester);
      expect(h.storage.lastWrite['ready_to_finish'], isTrue);
      h.queue.failNextEnqueue = StateError('enqueue boom');
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 10);

      expect(tester.takeException(), isNull);
      // Visible: nothing modal on top of the page's SnackBar.
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(find.text(l10n.circuitLastRoundVideoSaveError).hitTestable(), findsOneWidget);
      expect(h.queue.calls, isEmpty);
      expect(h.bloc.events, isEmpty);
      expect(find.byType(ActiveCircuitPage), findsOneWidget);
      expect(h.storage.lastWrite['ready_to_finish'], isTrue);
      expect(h.storage.removedKeys, isEmpty);

      // The video is still asked for, in the missing-videos sheet.
      await tester.tap(find.byKey(_footer));
      await settleFrames(tester, 6);
      expect(find.byType(CircuitFeedbackForm), findsOneWidget);
      expect(_missingAtEnd(tester), ['b']);
      expect(h.queue.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('r4: rest still running + a throwing enqueue: the SnackBar '
        'shows and the end of the rest opens the missing-videos sheet', (
      tester,
    ) async {
      final h = await pumpWithRest(
        tester,
        exercises: [circuitExercise('b', 'Burpees', restSeconds: 2)],
      );
      final l10n = _l10n(tester);
      h.queue.failNextEnqueue = StateError('enqueue boom');
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 6);
      expect(tester.takeException(), isNull);
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(find.text(l10n.circuitLastRoundVideoSaveError).hitTestable(), findsOneWidget);
      expect(h.queue.calls, isEmpty);

      await outlastRest(tester);
      expect(find.byType(CircuitFeedbackForm), findsOneWidget);
      expect(_missingAtEnd(tester), ['b']);
      expect(h.queue.calls, isEmpty);
      expect(h.bloc.events, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('final rest + failed completion: no second enqueue, and the '
        'retry does not ask for the video again', (tester) async {
      final h = await pumpWithRest(
        tester,
        exercises: [circuitExercise('b', 'Burpees', restSeconds: 2)],
        failWhen: (_) => true,
      );
      await outlastRest(tester);
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 10);
      expect(h.queue.calls, hasLength(1));
      expect(h.bloc.completions, hasLength(1));
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(find.byType(ActiveCircuitPage), findsOneWidget);
      expect(h.storage.lastWrite['ready_to_finish'], isTrue);
      expect(h.storage.lastWrite['feedback_ids'], {'b': 'fb-1'});
      expect(h.storage.removedKeys, isEmpty);

      // «Terminar circuito» retries with the same video, not asked again.
      await tester.tap(find.byKey(_footer));
      await settleFrames(tester, 10);
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(h.queue.calls, hasLength(1));
      expect(h.bloc.completions, hasLength(2));
      expect(
        h.bloc.completions.map((c) => c.lastSetFeedbackClientUploadId),
        ['fb-1', 'fb-1'],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('final rest + «Cancelar»: the missing-videos sheet opens '
        'once, after the video sheet closed', (tester) async {
      final h = await pumpWithRest(
        tester,
        exercises: [circuitExercise('b', 'Burpees', restSeconds: 2)],
        pick: false,
      );
      await outlastRest(tester);
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      await tester.tap(find.byKey(_cancel));
      await settleFrames(tester, 10);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(find.byType(CircuitFeedbackForm), findsOneWidget);
      expect(_missingAtEnd(tester), ['b']);
      expect(h.queue.calls, isEmpty);
      expect(h.bloc.events, isEmpty);
    });

    testWidgets('rest between exercises: no double advance, no sheet left '
        'behind and nothing completed', (tester) async {
      final h = await pumpWithRest(
        tester,
        exercises: [
          circuitExercise('a', 'Burpees', restSeconds: 2),
          circuitExercise('b', 'Sentadilla con salto'),
        ],
      );
      expect(h.storage.lastWrite['status'], 'exerciseResting');
      expect(h.storage.lastWrite['exercise_index'], 1);
      await outlastRest(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(h.storage.lastWrite['status'], 'executing');
      expect(h.storage.lastWrite['exercise_index'], 1);
      expect(h.storage.lastWrite['round'], 1);
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 6);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(h.queue.calls, hasLength(1));
      expect(h.queue.calls.single.trainingExerciseId, 'a');
      expect(h.bloc.events, isEmpty);
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(h.storage.lastWrite['exercise_index'], 1);
      expect(h.storage.lastWrite['round'], 1);
      expect(h.storage.lastWrite['ready_to_finish'], isFalse);
      expect(h.storage.lastWrite['feedback_ids'], {'a': 'fb-1'});
      // Exercise b is next, its band shown.
      expect(
        find.descendant(
          of: find.byKey(_reminderBand),
          matching: find.text(
            _l10n(tester).lastSetReminderMessage('Sentadilla con salto'),
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('session owner (r2, AGENTS.md: no work of A with B)', () {
    testWidgets('a user change with the sheet open queues nothing', (
      tester,
    ) async {
      mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
      final h = await _pumpLastRound(tester);
      await _saveRound(tester);
      await tester.tap(find.byKey(_gallery));
      await settleFrames(tester);
      h.storage.stamp = 'other:2:test';
      await tester.tap(find.byKey(_use));
      await settleFrames(tester, 6);
      expect(h.queue.calls, isEmpty);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the missing videos at the end are queued for the page '
        'owner only', (tester) async {
      final h = await _pumpLastRound(tester, reminder: false);
      await _saveRound(tester);
      await _saveRound(tester);
      final form = tester.widget<CircuitFeedbackForm>(
        find.byType(CircuitFeedbackForm),
      );
      await form.enqueue!(
        CircuitFeedbackUpload(
          target: form.targets.first,
          file: File('/tmp/a-end.mp4'),
          notes: null,
        ),
      );
      expect(h.queue.calls.single.expectedSession, 'owner:1:test');
      expect(h.queue.calls.single.trainingExerciseId, 'a');
    });
  });

  testWidgets('light theme: band, minimal line and video sheet without lime '
      'ink', (tester) async {
    mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
    await _pumpLastRound(tester, brightness: Brightness.light);
    expect(find.byKey(_reminderBand), findsOneWidget);
    expectNoLimeInk(tester);
    await _pumpLastRound(
      tester,
      reminder: false,
      brightness: Brightness.light,
    );
    expect(find.byKey(_reminderOff), findsOneWidget);
    expectNoLimeInk(tester);
    await _pumpLastRound(tester, brightness: Brightness.light);
    await _saveRound(tester);
    expect(find.byKey(_videoSheet), findsOneWidget);
    expectNoLimeInk(tester);
  });

  testWidgets('2.0x at 320 dp: the band scrolls into view and both sheet '
      'states keep their actions reachable (CC 3)', (tester) async {
    mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
    const scaler = AndroidNonlinearTextScaler(2.0);
    await _pumpLastRound(
      tester,
      width: 320,
      height: 640,
      textScaler: scaler,
    );
    await tester.scrollUntilVisible(
      find.text(_l10n(tester).lastSetVideoRemindMe),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(_footer));
    await settleFrames(tester, 3);
    await tester.ensureVisible(find.byKey(const Key('set-sheet-save')));
    await tester.tap(find.byKey(const Key('set-sheet-save')));
    await settleFrames(tester, 6);
    expect(find.byKey(_videoSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(_record)).bottom, lessThanOrEqualTo(640));
    await tester.tap(find.byKey(_gallery));
    await settleFrames(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(_use)).bottom, lessThanOrEqualTo(640));
  });
}
