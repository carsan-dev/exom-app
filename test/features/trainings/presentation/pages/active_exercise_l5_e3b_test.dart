// L5-E3b «Última serie y vídeo» (D17-6, L5-D23 i-iii, L5-D43) on the active
// exercise: the reminder before the last set is a band with «Recordármelo»
// (same preference, minimal line when off), saving the last set opens one
// straight sheet («Grabar ahora», «Elegir de la galería», comment in the same
// sheet, «Cambiar» / «Usar vídeo», «Cancelar») and the enqueue keeps the same
// fields. Also: the exercise name on the set sheet (kicker, E4 pending) and
// the sheets repainting on a theme change while open (E4-O4). The circuit is
// unchanged here (E3c): its set sheet has no kicker.
import 'dart:ui' as ui;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'active_exercise_redesign_test.dart'
    show
        ActiveExerciseHandle,
        activeExerciseDraftKey,
        activeExerciseTrainingId,
        pumpActiveExercise;
import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'circuit_test_harness.dart';
import 'last_set_video_test_support.dart';

const _reminderBand = Key('last-set-video-reminder');
const _reminderOff = Key('last-set-video-reminder-off');
const _videoSheet = Key('last-set-video-sheet');
const _record = Key('last-set-video-record');
const _gallery = Key('last-set-video-gallery');
const _cancel = Key('last-set-video-cancel');
const _change = Key('last-set-video-change');
const _comment = Key('last-set-video-comment');
const _use = Key('last-set-video-use');

/// Set [current] of 3 executing, the previous ones saved.
ActiveWorkoutHiveModel _seedAt(int current) => ActiveWorkoutHiveModel(
  trainingId: activeExerciseTrainingId,
  exerciseId: activeExerciseDraftKey,
  currentSet: current,
  completedSets: current - 1,
  lastWeightKg: 62.5,
  completedSetData: [
    for (var set = 1; set < current; set++)
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

Future<ActiveExerciseHandle> _pumpVideo(
  WidgetTester tester, {
  int current = 3,
  bool reminder = true,
  bool requiresLastSetVideo = true,
  RecordingVideoQueue? queue,
  ValueNotifier<ThemeMode>? themeMode,
  Locale locale = const Locale('es'),
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  TextScaler? textScaler,
}) async {
  final h = await pumpActiveExercise(
    tester,
    initialWeightKg: 62.5,
    seed: _seedAt(current),
    requiresLastSetVideo: requiresLastSetVideo,
    lastSetVideoReminder: reminder,
    themeMode: themeMode,
    locale: locale,
    brightness: brightness,
    width: width,
    height: height,
    textScaler: textScaler,
    registerExtra: () => sl.registerSingleton<FeedbackUploadQueueService>(
      queue ?? RecordingVideoQueue(),
    ),
  );
  await _frames(tester);
  return h;
}

/// «Registrar serie» → «Guardar serie» on the last set: the video sheet.
Future<void> _saveLastSet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('footer-executing')));
  await _frames(tester, 3);
  await tester.tap(find.byKey(const Key('set-sheet-save')));
  await _frames(tester, 6);
}

Iterable<MarkExerciseCompleted> _completions(ActiveExerciseHandle h) =>
    h.trainingEvents.whereType<MarkExerciseCompleted>();

Future<Uint8List> _shot(WidgetTester tester) async {
  RenderObject? render = tester.renderObject(
    find.byKey(const Key('exom-sheet-panel')),
  );
  while (render != null && render is! RenderRepaintBoundary) {
    render = render.parent;
  }
  final boundary = render! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  group('reminder band (L5-D23 i)', () {
    testWidgets('before the last set it is a band with «Recordármelo» on, '
        'not a dialog, and nothing opens by itself', (tester) async {
      await _pumpVideo(tester, current: 2);
      final l10n = _l10n(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(_reminderBand), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_reminderBand),
          matching: find.text(l10n.upcomingLastSetMessage),
        ),
        findsOneWidget,
      );
      final row = tester.widget<ExomSwitchRow>(
        find.descendant(
          of: find.byKey(_reminderBand),
          matching: find.byType(ExomSwitchRow),
        ),
      );
      expect(row.label, l10n.lastSetVideoRemindMe);
      expect(row.value, isTrue);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(find.text(l10n.recordNow), findsNothing);
    });

    testWidgets('on the last set too, still without opening the video', (
      tester,
    ) async {
      await _pumpVideo(tester, current: 3);
      expect(find.byKey(_reminderBand), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(find.byKey(const Key('exom-sheet-panel')), findsNothing);
    });

    testWidgets('the band copy says «this is the last set» on the last set '
        'and «the next is the last» on the one before (r3, D1)', (
      tester,
    ) async {
      await _pumpVideo(tester, current: 3);
      var l10n = _l10n(tester);
      Finder inBand(String text) => find.descendant(
        of: find.byKey(_reminderBand),
        matching: find.text(text),
      );
      expect(inBand(l10n.currentLastSetMessage), findsOneWidget);
      expect(inBand(l10n.upcomingLastSetMessage), findsNothing);

      await _pumpVideo(tester, current: 2);
      l10n = _l10n(tester);
      expect(inBand(l10n.upcomingLastSetMessage), findsOneWidget);
      expect(inBand(l10n.currentLastSetMessage), findsNothing);
    });

    testWidgets('not on earlier sets nor without a required video', (
      tester,
    ) async {
      await _pumpVideo(tester, current: 1);
      expect(find.byKey(_reminderBand), findsNothing);
      expect(find.byKey(_reminderOff), findsNothing);
      await _pumpVideo(tester, current: 3, requiresLastSetVideo: false);
      expect(find.byKey(_reminderBand), findsNothing);
      expect(find.byKey(_reminderOff), findsNothing);
    });

    testWidgets('turning it off saves false and leaves the minimal line; '
        'turning it on again saves true', (tester) async {
      final h = await _pumpVideo(tester, current: 2);
      final l10n = _l10n(tester);
      await tester.tap(find.text(l10n.lastSetVideoRemindMe));
      await _frames(tester);
      expect(h.settings['last_set_video_reminder_enabled'], isFalse);
      expect(find.byKey(_reminderBand), findsNothing);
      expect(find.byKey(_reminderOff), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_reminderOff),
          matching: find.text(l10n.lastSetVideoReminderOption),
        ),
        findsOneWidget,
      );
      // One merged node: «Recordármelo», its line, a switch that is off.
      final offNode = find.text(l10n.lastSetVideoReminderOption);
      expect(
        tester.getSemantics(offNode),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      expect(
        tester.getSemantics(offNode).getSemanticsData().label,
        contains(l10n.lastSetVideoRemindMe),
      );
      expect(tester.getSize(find.byKey(_reminderOff)).height,
          greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(_reminderOff));
      await _frames(tester);
      expect(h.settings['last_set_video_reminder_enabled'], isTrue);
      expect(find.byKey(_reminderBand), findsOneWidget);
    });

    testWidgets('a failed save reverts the switch and says so (as Ajustes)', (
      tester,
    ) async {
      final h = await _pumpVideo(tester, current: 2);
      final l10n = _l10n(tester);
      h.failSettingSaves = true;
      await tester.tap(find.text(l10n.lastSetVideoRemindMe));
      await _frames(tester);
      // Back to on: the band, not the minimal line; nothing saved.
      expect(find.byKey(_reminderBand), findsOneWidget);
      expect(find.byKey(_reminderOff), findsNothing);
      expect(h.settings['last_set_video_reminder_enabled'], isTrue);
      expect(find.text(l10n.settingsSwitchDisableFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed save turning it on reverts to the minimal line', (
      tester,
    ) async {
      final h = await _pumpVideo(tester, current: 2, reminder: false);
      final l10n = _l10n(tester);
      h.failSettingSaves = true;
      await tester.tap(find.byKey(_reminderOff));
      await _frames(tester);
      expect(find.byKey(_reminderOff), findsOneWidget);
      expect(find.byKey(_reminderBand), findsNothing);
      expect(h.settings['last_set_video_reminder_enabled'], isFalse);
      expect(find.text(l10n.settingsSwitchEnableFailed), findsOneWidget);
    });

    testWidgets('with the preference off it starts as the minimal line', (
      tester,
    ) async {
      await _pumpVideo(tester, current: 2, reminder: false);
      expect(find.byKey(_reminderBand), findsNothing);
      expect(find.byKey(_reminderOff), findsOneWidget);
    });
  });

  group('video sheet (L5-D23 ii-iii)', () {
    testWidgets('saving the last set opens one straight sheet with «Grabar '
        'ahora» (primary), «Elegir de la galería» (link) and «Cancelar»', (
      tester,
    ) async {
      final h = await _pumpVideo(tester);
      final l10n = _l10n(tester);
      await _saveLastSet(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(l10n.lastSetVideoSheetKicker('Sentadilla búlgara', 3)
            .toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(l10n.attachLastSetVideo.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.lastSetVideoRequiredDescription), findsOneWidget);
      expect(
        tester.widget<ExomPrimaryButton>(find.byKey(_record)).label,
        l10n.recordNow,
      );
      expect(
        tester.widget<ExomTextLink>(find.byKey(_gallery)).label,
        l10n.chooseFromGallery,
      );
      expect(find.byKey(_cancel), findsOneWidget);
      // The set is not dispatched until the video is queued (same rule).
      expect(h.draft!.completedSets, 2);
    });

    testWidgets('gallery → comment in the same sheet → «Usar vídeo» queues '
        'the same fields and completes the set', (tester) async {
      final queue = RecordingVideoQueue();
      final sources = mockVideoPicker(tester, (_) async => '/tmp/serie.mov');
      final h = await _pumpVideo(tester, queue: queue);
      final l10n = _l10n(tester);
      await _saveLastSet(tester);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      expect(sources, [1]);
      // Same sheet, second state: no second dialog.
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.videoReadyTitle.toUpperCase()), findsOneWidget);
      expect(find.byKey(_record), findsNothing);
      expect(
        tester.getSemantics(find.byKey(_change)).label,
        l10n.changeVideoA11y,
      );
      await tester.enterText(find.byKey(_comment), '  Me ha costado  ');
      await tester.pump();
      expect(
        tester.widget<ExomPrimaryButton>(find.byKey(_use)).label,
        l10n.useVideo,
      );
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);

      expect(queue.calls, hasLength(1));
      final call = queue.calls.single;
      expect(call.path, '/tmp/serie.mov');
      expect(call.expectedSession, 'owner:1:test');
      expect(call.contentType, 'video/quicktime');
      expect(call.mediaType, 'VIDEO');
      expect(call.notes, 'Me ha costado');
      expect(call.exerciseId, 'ex-1');
      expect(call.feedbackKind, 'LAST_SET');
      expect(call.trainingId, activeExerciseTrainingId);
      expect(call.trainingExerciseId, 'te-1');
      expect(call.assignmentDate, '2026-11-18');
      expect(call.sessionId, isNull);
      expect(find.byKey(_videoSheet), findsNothing);
      // The last set is saved with the queued video (then the final rest;
      // the exercise completion carries it, as before E3b).
      expect(h.draft!.completedSets, 3);
      expect(h.draft!.lastSetFeedbackClientUploadId, 'fb-1');
    });

    testWidgets('«Grabar ahora» opens the camera; a camera failure still '
        'offers the gallery', (tester) async {
      final queue = RecordingVideoQueue();
      final sources = mockVideoPicker(tester, (source) async {
        if (source == 0) {
          throw PlatformException(code: 'camera_unavailable');
        }
        return '/tmp/serie.mp4';
      });
      await _pumpVideo(tester, queue: queue);
      final l10n = _l10n(tester);
      await _saveLastSet(tester);
      await tester.tap(find.byKey(_record));
      await _frames(tester);
      expect(sources, [0]);
      await tester.tap(find.text(l10n.feedbackFromGallery));
      await _frames(tester);
      expect(sources, [0, 1]);
      expect(find.text(l10n.videoReadyTitle.toUpperCase()), findsOneWidget);
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(queue.calls.single.contentType, 'video/mp4');
      expect(queue.calls.single.notes, isNull);
    });

    testWidgets('cancel keeps the pending set: the next tap goes straight to '
        'the video sheet, never the set sheet twice', (tester) async {
      final queue = RecordingVideoQueue();
      final h = await _pumpVideo(tester, queue: queue);
      await _saveLastSet(tester);
      await tester.tap(find.byKey(_cancel));
      await _frames(tester, 6);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(queue.calls, isEmpty);
      expect(h.draft!.completedSets, 2);
      expect(_completions(h), isEmpty);

      await tester.tap(find.byKey(const ValueKey('footer-executing')));
      await _frames(tester, 6);
      expect(find.byKey(const Key('set-sheet-save')), findsNothing);
      expect(find.byKey(_videoSheet), findsOneWidget);
      // Dismissing (scrim) is the same as «Cancelar».
      await tester.tapAt(const Offset(10, 10));
      await _frames(tester, 6);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(queue.calls, isEmpty);
      expect(h.draft!.completedSets, 2);
    });

    testWidgets('«Cambiar» goes back to the source in the same sheet and '
        'queues nothing', (tester) async {
      final queue = RecordingVideoQueue();
      mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
      await _pumpVideo(tester, queue: queue);
      await _saveLastSet(tester);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      await tester.tap(find.byKey(_change));
      await _frames(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      expect(find.byKey(_record), findsOneWidget);
      expect(find.byKey(_use), findsNothing);
      expect(queue.calls, isEmpty);
    });

    testWidgets('a double tap on «Usar vídeo» queues once', (tester) async {
      final queue = RecordingVideoQueue();
      mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
      final h = await _pumpVideo(tester, queue: queue);
      await _saveLastSet(tester);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      await tester.tap(find.byKey(_use));
      await tester.tap(find.byKey(_use), warnIfMissed: false);
      await _frames(tester, 6);
      expect(queue.calls, hasLength(1));
      expect(h.draft!.completedSets, 3);
      expect(h.draft!.lastSetFeedbackClientUploadId, 'fb-1');
    });

    testWidgets('a user switch with the sheet open queues nothing '
        '(same _ownerSession check)', (tester) async {
      final queue = RecordingVideoQueue();
      mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
      final h = await _pumpVideo(tester, queue: queue);
      await _saveLastSet(tester);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      h.sessionStamp = 'owner:2:other';
      await tester.tap(find.byKey(_use));
      await _frames(tester, 6);
      expect(queue.calls, isEmpty);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(h.draft!.lastSetFeedbackClientUploadId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a router location change closes the sheet without queuing '
        '(CC 11)', (tester) async {
      final queue = RecordingVideoQueue();
      mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
      final h = await _pumpVideo(tester, queue: queue);
      await _saveLastSet(tester);
      await tester.tap(find.byKey(_gallery));
      await _frames(tester);
      GoRouter.of(tester.element(find.byType(ActiveExercisePage))).go('/');
      await _frames(tester, 6);
      expect(find.byKey(_videoSheet), findsNothing);
      expect(queue.calls, isEmpty);
      expect(_completions(h), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the set sheet names the exercise (E4 pending kicker)', (
    tester,
  ) async {
    await _pumpVideo(tester, current: 1, requiresLastSetVideo: false);
    final l10n = _l10n(tester);
    await tester.tap(find.byKey(const ValueKey('footer-executing')));
    await _frames(tester, 3);
    expect(
      find.descendant(
        of: find.byKey(const Key('exom-sheet-panel')),
        matching: find.text(
          l10n.setSheetExerciseKicker('Sentadilla búlgara').toUpperCase(),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the circuit set sheet is unchanged here (no kicker, E3c)', (
    tester,
  ) async {
    await pumpCircuit(
      tester,
      exercises: [circuitExercise('a', 'Burpees', targetRir: 2)],
    );
    await tester.tap(find.byKey(const ValueKey('circuit-executing-footer')));
    await _frames(tester, 3);
    expect(find.byKey(const Key('exom-sheet-panel')), findsOneWidget);
    expect(find.textContaining('· REGISTRAR'), findsNothing);
  });

  testWidgets('light theme: band, minimal line and video sheet without lime '
      'ink (only «Grabar ahora» / «Usar vídeo» are lime fills)', (
    tester,
  ) async {
    mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
    await _pumpVideo(tester, current: 2, brightness: Brightness.light);
    expect(find.byKey(_reminderBand), findsOneWidget);
    expectNoLimeInk(tester);
    await _pumpVideo(
      tester,
      current: 2,
      reminder: false,
      brightness: Brightness.light,
    );
    expect(find.byKey(_reminderOff), findsOneWidget);
    expectNoLimeInk(tester);
    await _pumpVideo(tester, brightness: Brightness.light);
    await _saveLastSet(tester);
    expect(find.byKey(_videoSheet), findsOneWidget);
    expectNoLimeInk(tester);
    await tester.tap(find.byKey(_gallery));
    await _frames(tester);
    expect(find.byKey(_use), findsOneWidget);
    expectNoLimeInk(tester);
  });

  testWidgets('2.0x at 320 dp: the band scrolls into view and both sheet '
      'states keep their actions reachable (CC 3)', (tester) async {
    mockVideoPicker(tester, (_) async => '/tmp/a.mp4');
    const scaler = AndroidNonlinearTextScaler(2.0);
    await _pumpVideo(
      tester,
      current: 2,
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
    await _pumpVideo(tester, width: 320, height: 640, textScaler: scaler);
    await _saveLastSet(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(_record)).bottom, lessThanOrEqualTo(640));
    await tester.tap(find.byKey(_gallery));
    await _frames(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(_use)).bottom, lessThanOrEqualTo(640));
    await tester.scrollUntilVisible(
      find.byKey(_comment),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(_videoSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
  });

  group('sheets follow a theme change while open (E4-O4)', () {
    Future<void> expectRepaint(
      WidgetTester tester,
      ValueNotifier<ThemeMode> mode,
      Future<void> Function() reopen,
      Future<void> Function() close,
    ) async {
      final light = await _shot(tester);
      expect(
        tester.widget<Material>(find.byKey(const Key('exom-sheet-panel'))).color,
        AppTheme.light.extension<ExomThemePalette>()!.surface,
      );
      mode.value = ThemeMode.dark;
      await _frames(tester, 6);
      final switched = await _shot(tester);
      expect(switched, isNot(equals(light)));
      await close();
      await reopen();
      // Pixel for pixel what a sheet opened in the dark theme shows.
      expect(await _shot(tester), equals(switched));
    }

    testWidgets('set sheet of the active exercise', (tester) async {
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      await _pumpVideo(
        tester,
        current: 1,
        requiresLastSetVideo: false,
        themeMode: mode,
      );
      Future<void> open() async {
        await tester.tap(find.byKey(const ValueKey('footer-executing')));
        await _frames(tester, 6);
      }

      await open();
      await expectRepaint(tester, mode, open, () async {
        await tester.tap(find.byKey(const Key('set-sheet-cancel')));
        await _frames(tester, 6);
      });
    });

    testWidgets('set sheet of the circuit', (tester) async {
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      await pumpCircuit(
        tester,
        exercises: [circuitExercise('a', 'Burpees', targetRir: 2)],
        themeMode: mode,
      );
      Future<void> open() async {
        await tester.tap(
          find.byKey(const ValueKey('circuit-executing-footer')),
        );
        await _frames(tester, 6);
      }

      await open();
      await expectRepaint(tester, mode, open, () async {
        await tester.tap(find.byKey(const Key('set-sheet-cancel')));
        await _frames(tester, 6);
      });
    });

    testWidgets('video sheet of the last set', (tester) async {
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      await _pumpVideo(tester, themeMode: mode);
      await _saveLastSet(tester);
      expect(find.byKey(_videoSheet), findsOneWidget);
      await expectRepaint(
        tester,
        mode,
        () async {
          await tester.tap(find.byKey(const ValueKey('footer-executing')));
          await _frames(tester, 6);
        },
        () async {
          await tester.tap(find.byKey(_cancel));
          await _frames(tester, 6);
        },
      );
    });
  });
}
