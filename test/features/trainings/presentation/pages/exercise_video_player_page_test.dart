// L5-A2 «Reproductor de vídeo» (docs/plans/rediseno-app-l5-contrato-v2.md,
// D17-3): the controls hide after inactivity, come back with a touch without
// delaying it, stay visible with a screen reader (accessibleNavigation) and
// the double tap ±5 s and the long-press 2× are kept.
//
// The page takes a `controllerFactory` (visible for testing); here it returns a
// [FakeVideoController], so no platform video is needed.
import 'dart:io';

import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/wcag_contrast.dart';
import '../../../../core/widgets/exom_component_harness.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'exercise_video_player_harness.dart';

/// Idle time before the controls hide (decision L5-A2: the sketch has no
/// duration, only the 160 ms fade; 3 s proposed to the owner).
const Duration kIdle = Duration(seconds: 3);

const Key _controlsKey = ValueKey('video-player-controls');
const Key _toggleKey = ValueKey('video-player-toggle');
const List<Key> _veilKeys = [
  ValueKey('video-player-veil-top'),
  ValueKey('video-player-veil-bottom'),
];

double _controlsOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byKey(_controlsKey)).opacity;

Offset _stageCenter(WidgetTester tester) =>
    Offset(tester.view.physicalSize.width / 2, 300);

Future<void> _waitUntilHidden(WidgetTester tester) async {
  await tester.pump(kIdle + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
  expect(_controlsOpacity(tester), 0);
}

Rect _videoRect(WidgetTester tester) =>
    tester.getRect(find.byType(VideoPlayer));

List<CustomSemanticsAction> stageActions(WidgetTester tester) => tester
    .getSemantics(find.byKey(const ValueKey('video-player-stage')))
    .getSemanticsData()
    .customSemanticsActionIds!
    .map((id) => CustomSemanticsAction.getAction(id)!)
    .toList();

void main() {
  group('smoke', () {
    testWidgets('shows play state, the times and keeps the controller', (
      tester,
    ) async {
      final controller = await pumpPlayer(tester);

      expect(find.byIcon(ExomIcons.pause), findsOneWidget);
      expect(find.text('00:12 / 00:38'), findsOneWidget);
      expect(controller.calls, contains('play'));
      expectNoOverflow(tester);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('controls auto-hide (D17-3)', () {
    testWidgets('hide after the inactivity and a touch brings them back', (
      tester,
    ) async {
      final controller = await pumpPlayer(tester);
      expect(_controlsOpacity(tester), 1);

      await tester.pump(kIdle + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(_controlsOpacity(tester), 0);

      // The touch reveals at once and does not run another action.
      final callsBefore = List<String>.of(controller.calls);
      await tester.tapAt(_stageCenter(tester));
      await tester.pump();
      expect(
        tester.widget<AnimatedOpacity>(find.byKey(_controlsKey)).opacity,
        1,
      );
      expect(controller.calls, callsBefore);

      // And they hide again after another idle period.
      await tester.pump(kIdle + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(_controlsOpacity(tester), 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hidden controls do not act: the first touch only reveals', (
      tester,
    ) async {
      final controller = await pumpPlayer(tester);
      await tester.pump(kIdle + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(_controlsOpacity(tester), 0);

      await tester.tap(find.byKey(_toggleKey), warnIfMissed: false);
      await tester.pump();
      expect(controller.calls, isNot(contains('pause')));
      expect(_controlsOpacity(tester), 1);

      // Visible now: the same tap pauses.
      await tester.tap(find.byKey(_toggleKey));
      await tester.pump();
      expect(controller.calls, contains('pause'));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a touch restarts the idle countdown', (tester) async {
      await pumpPlayer(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.tapAt(_stageCenter(tester));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(_controlsOpacity(tester), 1);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_controlsOpacity(tester), 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('accessibleNavigation: they never hide and keep semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPlayer(tester, accessibleNavigation: true);
      await tester.pump(kIdle * 4);
      await tester.pumpAndSettle();

      expect(_controlsOpacity(tester), 1);
      expect(
        tester.getSemantics(find.byKey(_toggleKey)).getSemanticsData().tooltip,
        'Pausar',
      );
      expect(find.bySemanticsLabel('Progreso del vídeo'), findsOneWidget);
      semantics.dispose();

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the fade is 160 ms, and the reduced variant 120 ms', (
      tester,
    ) async {
      await pumpPlayer(tester);
      expect(
        tester.widget<AnimatedOpacity>(find.byKey(_controlsKey)).duration,
        ExomMotion.resolve(reduced: false).inPlaceSwitch,
      );
      expect(
        ExomMotion.resolve(reduced: false).inPlaceSwitch.inMilliseconds,
        160,
      );
      await tester.pumpWidget(const SizedBox());

      await pumpPlayer(tester, disableAnimations: true);
      expect(
        tester.widget<AnimatedOpacity>(find.byKey(_controlsKey)).duration,
        ExomMotion.resolve(reduced: true).inPlaceSwitch,
      );
      expect(
        ExomMotion.resolve(reduced: true).inPlaceSwitch.inMilliseconds,
        120,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('gestures are kept', () {
    testWidgets('double tap seeks 5 s back or forward', (tester) async {
      final controller = await pumpPlayer(tester);

      Future<void> doubleTapAt(Offset at) async {
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(at);
        await tester.pumpAndSettle();
      }

      await doubleTapAt(const Offset(300, 300));
      expect(controller.calls, contains('seek:17'));
      await doubleTapAt(const Offset(90, 300));
      expect(controller.calls, contains('seek:12'));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('long press runs 2x with the flat pill and restores speed', (
      tester,
    ) async {
      final controller = await pumpPlayer(tester);
      expect(
        find.byKey(const ValueKey('video-player-speed-pill')),
        findsNothing,
      );

      final gesture = await tester.startGesture(const Offset(90, 300));
      await tester.pump(const Duration(milliseconds: 700));
      expect(controller.calls, contains('speed:2.0'));
      expect(
        find.byKey(const ValueKey('video-player-speed-pill')),
        findsOneWidget,
      );
      expect(find.text('2×'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.calls.last, 'speed:1.0');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('double tap seeks with the controls hidden', (tester) async {
      final controller = await pumpPlayer(tester);
      await _waitUntilHidden(tester);

      await tester.tapAt(const Offset(300, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(300, 300));
      await tester.pumpAndSettle();
      expect(controller.calls, contains('seek:17'));

      await _waitUntilHidden(tester);
      await tester.tapAt(const Offset(90, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(90, 300));
      await tester.pumpAndSettle();
      expect(controller.calls, contains('seek:12'));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('long press runs 2x with the controls hidden', (tester) async {
      final controller = await pumpPlayer(tester);
      await _waitUntilHidden(tester);

      final gesture = await tester.startGesture(const Offset(90, 300));
      await tester.pump(const Duration(milliseconds: 700));
      expect(controller.calls, contains('speed:2.0'));
      expect(
        find.byKey(const ValueKey('video-player-speed-pill')),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.calls.last, 'speed:1.0');

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('layout (F1): the video never collapses', () {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('landscape 640x360 at ${scale}x: full screen video, '
          'controls reachable', (tester) async {
        final controller = await pumpPlayer(
          tester,
          width: 640,
          height: 360,
          textScale: scale,
          title: 'Sentadilla búlgara con mancuernas',
        );
        expectNoOverflow(tester);
        expect(_videoRect(tester), const Rect.fromLTWH(0, 0, 640, 360));

        final toggle = tester.getRect(find.byKey(_toggleKey));
        expect(
          const Rect.fromLTWH(0, 0, 640, 360).intersect(toggle),
          toggle,
          reason: 'the play button is on screen',
        );
        expect(find.text('00:12 / 00:38'), findsOneWidget);
        await tester.tap(find.byKey(_toggleKey));
        await tester.pump();
        expect(controller.calls, contains('pause'));

        await tester.pumpWidget(const SizedBox());
      });
    }

    for (final (width, height) in const [(360.0, 640.0), (320.0, 480.0)]) {
      testWidgets('portrait ${width.toInt()}x${height.toInt()} at 2.0x: '
          'full-width video, everything reachable by scrolling', (
        tester,
      ) async {
        final controller = await pumpPlayer(
          tester,
          width: width,
          height: height,
          textScale: 2.0,
          title: 'Sentadilla búlgara con mancuernas',
        );
        expectNoOverflow(tester);

        // Decision: in portrait the video keeps its full-width contain size
        // (width x 9/16 for a 16:9 clip) and is never squeezed by the text;
        // when headline + video + controls do not fit, the page scrolls.
        final video = _videoRect(tester);
        expect(video.width, moreOrLessEquals(width));
        expect(video.height, greaterThanOrEqualTo(width * 9 / 16 - 0.01));
        if (video.height < height / 2) {
          expect(find.byType(Scrollable), findsWidgets);
        }

        await tester.ensureVisible(find.byType(VideoPlayer));
        await tester.pumpAndSettle();
        final screen = Rect.fromLTWH(0, 0, width, height);
        final shown = _videoRect(tester);
        expect(screen.intersect(shown), shown, reason: 'whole video visible');

        await tester.ensureVisible(find.byKey(_toggleKey));
        await tester.pumpAndSettle();
        final toggle = tester.getRect(find.byKey(_toggleKey));
        expect(screen.intersect(toggle), toggle, reason: 'play button visible');
        await tester.tap(find.byKey(_toggleKey));
        await tester.pump();
        expect(controller.calls, contains('pause'));

        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('details', () {
    testWidgets('a one-word title paints a single headline line', (
      tester,
    ) async {
      await pumpPlayer(tester, title: 'Plancha');
      expect(find.text('PLANCHA'), findsOneWidget);
      expect(find.text(''), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('times use two-digit minutes like the sketch', (tester) async {
      await pumpPlayer(tester);
      expect(find.text('00:12 / 00:38'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the play icon sits on the content edge (margin -14)', (
      tester,
    ) async {
      await pumpPlayer(tester);
      final icon = tester.getRect(
        find.descendant(
          of: find.byKey(_toggleKey),
          matching: find.byType(Icon),
        ),
      );
      // Content inset 20 (ExomSpacing.xl), like the progress rule.
      expect(icon.left, moreOrLessEquals(20));
      await tester.pumpWidget(const SizedBox());
    });

    for (final brightness in Brightness.values) {
      testWidgets('status bar icons are light on black (${brightness.name})', (
        tester,
      ) async {
        await pumpPlayer(tester, brightness: brightness);
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find
              .descendant(
                of: find.byType(ExerciseVideoPlayerPage),
                matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
              )
              .first,
        );
        expect(region.value, SystemUiOverlayStyle.light);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a scrubber drag longer than the idle time re-arms it', (
      tester,
    ) async {
      await pumpPlayer(tester);
      final scrubber = tester.getCenter(find.byType(VideoScrubber));
      final gesture = await tester.startGesture(scrubber);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(seconds: 4));
      await gesture.up();
      await tester.pump();
      expect(_controlsOpacity(tester), 1);

      await _waitUntilHidden(tester);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('screen reader: custom actions seek 5 s (es)', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await pumpPlayer(tester);
      final actions = stageActions(tester);
      expect(actions.map((a) => a.label), ['Retroceder 5 s', 'Avanzar 5 s']);

      final node = find.semantics.byAction(SemanticsAction.customAction);
      tester.semantics.customAction(node, actions.last);
      await tester.pump();
      expect(controller.calls, contains('seek:17'));
      tester.semantics.customAction(node, actions.first);
      await tester.pump();
      expect(controller.calls.last, 'seek:12');

      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('screen reader: custom action labels (en)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPlayer(tester, locale: const Locale('en'));
      expect(stageActions(tester).map((a) => a.label), [
        'Rewind 5 s',
        'Forward 5 s',
      ]);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('review 4: veil contrast and reading order', () {
    testWidgets('the flat veil keeps the chrome at 4.5:1 over a white video', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        width: 640,
        height: 360,
        title: 'Sentadilla búlgara con mancuernas',
      );
      final veil = tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byKey(_veilKeys.first),
              matching: find.byType(ColoredBox),
            ),
          )
          .color;
      // Black at alpha a over pure white: every channel is 1 - a.
      final level = 1 - veil.a;
      final ground = Color.from(
        alpha: 1,
        red: level,
        green: level,
        blue: level,
      );
      const ink = {
        'white': Color(0xFFFFFFFF),
        'textPrimary': Color(0xFFF2F1E9),
        'data': Color(0xFFBAF23A),
        'textSecondary': Color(0xFFB7BCB3),
      };
      for (final entry in ink.entries) {
        expect(
          contrastRatio(entry.value, ground),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key} over the veil on a white video',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });

    // Pre-order walk of the semantics tree in traversal (reading) order.
    List<SemanticsNode> readingOrder(WidgetTester tester) {
      final out = <SemanticsNode>[];
      void walk(SemanticsNode node) {
        out.add(node);
        for (final child in node.debugListChildrenInOrder(
          DebugSemanticsDumpOrder.traversalOrder,
        )) {
          walk(child);
        }
      }

      var root = tester.getSemantics(find.byKey(_toggleKey));
      while (root.parent != null) {
        root = root.parent!;
      }
      walk(root);
      return out;
    }

    for (final (name, width, height) in const [
      ('sketch', 390.0, 844.0),
      ('overlay landscape', 640.0, 360.0),
      ('overlay vertical clip', 390.0, 844.0),
    ]) {
      testWidgets('reading order is back, headline, stage, controls '
          '($name) and the title is announced once', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpPlayer(
          tester,
          width: width,
          height: height,
          title: 'Sentadilla búlgara con mancuernas',
          videoSize: name == 'overlay vertical clip'
              ? const Size(720, 1280)
              : const Size(1280, 720),
        );
        final order = readingOrder(tester);
        int at(Finder finder) {
          final id = tester.getSemantics(finder).id;
          final index = order.indexWhere((n) => n.id == id);
          expect(index, isNonNegative, reason: '$finder in the tree');
          return index;
        }

        final back = at(find.byType(BackButton));
        final headline = at(find.byType(ExomTwoLineHeadline));
        final stage = at(find.byKey(const ValueKey('video-player-stage')));
        final controls = at(find.byKey(_toggleKey));
        expect(back, lessThan(headline));
        expect(headline, lessThan(stage));
        expect(stage, lessThan(controls));

        final titled = order.where(
          (n) =>
              n.getSemanticsData().label.toLowerCase().contains('sentadilla'),
        );
        expect(titled, hasLength(1), reason: 'the title is read once');
        expect(stageActions(tester).map((a) => a.label), [
          'Retroceder 5 s',
          'Avanzar 5 s',
        ]);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('overlay layout (review 2)', () {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('F2: landscape at ${scale}x, the 2x pill clears the '
          'headline and the back button', (tester) async {
        await pumpPlayer(
          tester,
          width: 640,
          height: 360,
          textScale: scale,
          title: 'Sentadilla búlgara con mancuernas',
        );
        // Hold on the right edge of the video, between header and controls.
        final scrubberTop = tester.getRect(find.byType(VideoScrubber)).top;
        final gesture = await tester.startGesture(
          Offset(630, (kToolbarHeight + scrubberTop) / 2),
        );
        await tester.pump(const Duration(milliseconds: 700));
        final pill = tester.getRect(
          find.byKey(const ValueKey('video-player-speed-pill')),
        );
        expect(pill.top, greaterThanOrEqualTo(0));
        final lines = find.descendant(
          of: find.byType(ExomTwoLineHeadline),
          matching: find.byType(Text),
        );
        expect(lines, findsNWidgets(2));
        for (final line in lines.evaluate()) {
          final rect = tester.getRect(find.byWidget(line.widget));
          expect(pill.overlaps(rect), isFalse, reason: '$pill vs $rect');
        }
        expect(pill.overlaps(tester.getRect(find.byType(BackButton))), isFalse);
        await gesture.up();
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        await tester.pumpWidget(const SizedBox());
      });
    }

    for (final (width, height, video) in const [
      (390.0, 844.0, Size(720, 1280)),
      (360.0, 780.0, Size(720, 1280)),
      (360.0, 640.0, Size(720, 1280)),
      (390.0, 844.0, Size(1080, 1080)),
      (390.0, 844.0, Size(1080, 1350)),
    ]) {
      testWidgets('F3: ${width.toInt()}x${height.toInt()} with a '
          '${video.width.toInt()}x${video.height.toInt()} clip: play and '
          'progress on screen without scrolling', (tester) async {
        final controller = await pumpPlayer(
          tester,
          width: width,
          height: height,
          videoSize: video,
        );
        expectNoOverflow(tester);
        final screen = Rect.fromLTWH(0, 0, width, height);
        for (final finder in [
          find.byKey(_toggleKey),
          find.byType(VideoScrubber),
        ]) {
          final rect = tester.getRect(finder);
          expect(screen.intersect(rect), rect, reason: '$finder on screen');
        }
        for (final scrollable in find.byType(Scrollable).evaluate()) {
          final state = tester.state<ScrollableState>(
            find.byWidget(scrollable.widget),
          );
          expect(state.position.pixels, 0);
        }
        await tester.tap(find.byKey(_toggleKey));
        await tester.pump();
        expect(controller.calls, contains('pause'));
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('flat veil behind the chrome only in the overlay layout, '
        'fading with it', (tester) async {
      await pumpPlayer(tester, width: 640, height: 360);
      for (final key in _veilKeys) {
        expect(tester.widget<AnimatedOpacity>(find.byKey(key)).opacity, 1);
        final size = tester.getSize(find.byKey(key));
        expect(size.width, 640);
        expect(size.height, greaterThan(0));
        final box = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(box.color, Colors.black.withValues(alpha: 0.72));
      }
      // Behind header + headline and behind the controls.
      final top = tester.getRect(find.byKey(_veilKeys.first));
      final bottom = tester.getRect(find.byKey(_veilKeys.last));
      final headline = tester.getRect(find.byType(ExomTwoLineHeadline));
      expect(top.top, 0);
      expect(top.bottom, greaterThanOrEqualTo(headline.bottom));
      expect(
        bottom.top,
        lessThanOrEqualTo(tester.getRect(find.byType(VideoScrubber)).top),
      );
      expect(bottom.bottom, 360);

      await _waitUntilHidden(tester);
      for (final key in _veilKeys) {
        expect(tester.widget<AnimatedOpacity>(find.byKey(key)).opacity, 0);
      }
      await tester.pumpWidget(const SizedBox());

      // The sketch layout (portrait, 16:9 clip) has no veil.
      await pumpPlayer(tester);
      for (final key in _veilKeys) {
        final veil = find.byKey(key);
        if (veil.evaluate().isNotEmpty) {
          expect(tester.getSize(veil), Size.zero);
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a double tap over the headline still seeks', (tester) async {
      final controller = await pumpPlayer(tester, width: 640, height: 360);
      final line = tester.getCenter(find.text('SENTADILLA'));
      await tester.tapAt(line);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(line);
      await tester.pumpAndSettle();
      expect(controller.calls, contains('seek:7'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the stage semantics node is named "Vídeo" (the headline '
        'announces the title)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPlayer(tester);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('video-player-stage')))
            .label,
        'Vídeo',
      );
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rotating keeps the same video view and controller', (
      tester,
    ) async {
      final controller = await pumpPlayer(tester);
      final before = tester.state(find.byType(VideoPlayer));

      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      expect(tester.getRect(find.byType(VideoPlayer)).width, 844);
      expect(tester.state(find.byType(VideoPlayer)), same(before));

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(tester.state(find.byType(VideoPlayer)), same(before));
      expect(controller.calls.where((c) => c == 'play'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('without factory', () {
    testWidgets('the default controller path is used (no video, error shown)', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        ExerciseVideoPlayerPage(
          title: 'Sentadilla',
          videoUri: Uri.parse('https://video.example.test/clip.mp4'),
        ),
        wrapInScaffold: false,
      );
      await tester.pump();
      await tester.pump();
      // The unimplemented platform fails initialize(): the page shows its
      // retry state instead of crashing.
      expect(find.byType(ExerciseVideoPlayerPage), findsOneWidget);
      expect(find.byIcon(ExomIcons.pause), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    test('the three callers build the page without a factory', () {
      for (final path in const [
        'lib/features/trainings/presentation/pages/active_circuit_page.dart',
        'lib/features/trainings/presentation/pages/active_exercise_page.dart',
        'lib/features/trainings/presentation/pages/training_detail_page.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('ExerciseVideoPlayerPage('), reason: path);
        expect(source, isNot(contains('controllerFactory')), reason: path);
      }
    });
  });

  group('main scene (controls visible)', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final (width, scale) in const [
        (320.0, 1.3),
        (320.0, 1.6),
        (360.0, 1.6),
        (320.0, 2.0),
      ]) {
        testWidgets(
          'no overflow at $width dp, ${scale}x, ${locale.languageCode}',
          (tester) async {
            await pumpPlayer(
              tester,
              width: width,
              height: 640,
              textScale: scale,
              locale: locale,
              title: 'Sentadilla búlgara con mancuernas',
            );
            expectNoOverflow(tester);
            expect(find.text('00:12 / 00:38'), findsOneWidget);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }

    testWidgets('English texts', (tester) async {
      await pumpPlayer(tester, locale: const Locale('en'));
      expect(
        tester.getSemantics(find.byKey(_toggleKey)).getSemanticsData().tooltip,
        'Pause',
      );
      await tester.pumpWidget(const SizedBox());
    });

    for (final brightness in Brightness.values) {
      for (final scale in const [1.0, 1.6]) {
        testWidgets('guidelines in ${brightness.name} at ${scale}x', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await pumpPlayer(tester, brightness: brightness, textScale: scale);
          await expectTapTargetGuidelines(tester);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          final toggle = tester.getSize(find.byKey(_toggleKey));
          expect(toggle.shortestSide, greaterThanOrEqualTo(48));

          // The player is pure black in both themes (sketch A3): it forces the
          // dark palette, where lime is the data colour. `expectNoLimeInk`
          // does not apply inside that Theme (light-theme rule D13, accepted
          // exception of the sketch), so it is rooted at the Scaffold, which
          // resolves to the forced dark theme, and the forced theme is proved.
          final scaffold = find.byType(Scaffold);
          expect(
            Theme.of(tester.element(scaffold)).brightness,
            Brightness.dark,
          );
          expectNoLimeInk(tester, root: scaffold);
          semantics.dispose();
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });
}
