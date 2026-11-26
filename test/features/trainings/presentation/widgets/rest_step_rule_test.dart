// L5-D48 (tanda CRONO): the rule of the rest countdown, of the floating rest
// timer and of the timer of a timed set is «N1 · Barra con tic» of
// `docs/bocetos/rediseno-exom-app/extension/h-regla-crono-r2.html`:
//
// - one solid bar in the data colour, 8 dp high and full width, over a track
//   in the rule tone; its length is the whole seconds left over the total;
// - it steps down once a second on the same whole second of the deadline as
//   the figures ([untilFigureChange], round r3 D1), in 140 ms on
//   `Cubic(0.23, 1, 0.32, 1)`, with no frame-driven draining in between;
// - a scale under it with 3 to 5 labelled marks (ticks 2 x 6, labels at 13 in
//   the secondary colour), outside the semantics;
// - over the last 5 s the figure beats 1 → 1.06 → 1 in 150 ms once a second;
// - «+30 s» rescales the bar and the scale to the new total in 180 ms and the
//   new marks fade in over 150 ms;
// - reduced motion: everything jumps once a second, no beat.
//
// The widgets are driven with the fake clock of the test binding, so timers
// and clock move together.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_timer_inline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/theme/wcag_contrast.dart';
import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/exom_component_harness.dart';

Finder get _rule => find.byType(RestStepRule);

/// Painted share of the bar: lit width over the track width.
double painted(WidgetTester tester, {Finder? rule}) {
  final of = rule ?? _rule;
  final track = find.descendant(
    of: of,
    matching: find.byKey(const Key('rest-step-track')),
  );
  final bar = find.descendant(
    of: of,
    matching: find.byKey(const Key('rest-step-bar')),
  );
  return tester.getSize(bar).width / tester.getSize(track).width;
}

int _target(WidgetTester tester) =>
    tester.widget<RestStepRule>(_rule).remainingSeconds;

double _beat(WidgetTester tester) => tester
    .widget<ScaleTransition>(find.byKey(const Key('rest-figure-pulse')))
    .scale
    .value;

double _scaleOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.byKey(const Key('rest-step-scale')))
    .opacity
    .value;

List<String> _labels(WidgetTester tester, {Finder? rule}) => [
  for (final element
      in find
          .descendant(of: rule ?? _rule, matching: find.byType(Text))
          .evaluate())
    (element.widget as Text).data!,
];

/// Moves the fake clock until [left] remains before [end], arriving with a
/// last 16 ms frame as on a device.
Future<void> _reach(WidgetTester tester, DateTime end, Duration left) async {
  const frame = Duration(milliseconds: 16);
  await tester.pump(end.difference(tester.binding.clock.now()) - left - frame);
  await tester.pump(frame);
}

/// Runs the step that started in the last frame to its end: the ticker takes
/// its first tick on the next frame, then [step] more.
Future<void> _finishStep(
  WidgetTester tester, [
  Duration step = const Duration(milliseconds: 140),
]) async {
  await tester.pump();
  await tester.pump(step);
}

void main() {
  group('scale marks (`hitos`, 3 to 5)', () {
    for (final (total, marks) in const [
      (30, [0, 10, 20, 30]),
      (60, [0, 15, 30, 45, 60]),
      (90, [0, 30, 60, 90]),
      (120, [0, 30, 60, 90, 120]),
      (180, [0, 60, 120, 180]),
    ]) {
      test('$total s: $marks', () {
        expect(restScaleMarks(total), marks);
      });
    }

    test('every duration of 10..3600 s: 0 first, the total last, increasing, '
        '3 to 5 marks', () {
      for (var total = 10; total <= 3600; total++) {
        final marks = restScaleMarks(total);
        expect(marks.first, 0, reason: '$total');
        expect(marks.last, total, reason: '$total');
        expect(marks.length, inInclusiveRange(3, 5), reason: '$total');
        for (var i = 1; i < marks.length; i++) {
          expect(marks[i], greaterThan(marks[i - 1]), reason: '$total');
        }
      }
    });

    test('a mark too close to the end gives way (under 12 % of the total)', () {
      // 100 s: steps of 30 → 0, 30, 60, 90 (10 % before the end), 100.
      expect(restScaleMarks(100), [0, 30, 60, 100]);
    });
  });

  group('rest countdown', () {
    testWidgets('bar and figures change on the same whole second, the step '
        'lasts 140 ms and nothing drains in between', (tester) async {
      DateTime now() => tester.binding.clock.now();
      // Mounted 600 ms off the whole second, as on a real device.
      final endsAt = now().add(const Duration(milliseconds: 89400));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: now),
      );
      expect(find.text('1:30'), findsOneWidget);
      expect(painted(tester), closeTo(1.0, 1e-9));
      for (var k = 89; k >= 0; k--) {
        await _reach(tester, endsAt, Duration(milliseconds: k * 1000 - 1));
        // Same frame: the figures and the bar's target.
        expect(find.text(formatRestClock(k)), findsOneWidget, reason: '$k');
        expect(_target(tester), k, reason: 'bar target at $k');
        // The step starts from the previous second, never from a drain.
        expect(painted(tester), closeTo((k + 1) / 90, 1e-9), reason: '$k');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final mid = painted(tester);
        expect(mid, lessThan((k + 1) / 90), reason: 'moving at $k');
        expect(mid, greaterThan(k / 90), reason: 'moving at $k');
        await tester.pump(const Duration(milliseconds: 124));
        expect(painted(tester), closeTo(k / 90, 1e-9), reason: 'step $k');
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no ticker runs between two seconds: one repaint a second', (
      tester,
    ) async {
      DateTime now() => tester.binding.clock.now();
      final endsAt = now().add(const Duration(milliseconds: 60400));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 60, now: now),
      );
      await _reach(tester, endsAt, const Duration(milliseconds: 59999));
      await tester.pump();
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'the 140 ms step runs',
      );
      // The ticker lets go on the first frame after the 140 ms.
      await tester.pump(const Duration(milliseconds: 140));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      final still = painted(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(painted(tester), still);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a clock jump (NTP) forwards or backwards shows on the next '
        'refresh in the figures and the bar alike', (tester) async {
      var now = DateTime(2026, 11, 26, 10);
      final endsAt = now.add(const Duration(seconds: 90));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: () => now),
      );
      now = now.add(const Duration(milliseconds: 4300));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1:26'), findsOneWidget);
      expect(_target(tester), 86);
      await _finishStep(tester);
      expect(painted(tester), closeTo(86 / 90, 1e-9));
      // A real jump backwards is accepted: the deadline is the truth.
      now = now.subtract(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1:28'), findsOneWidget);
      expect(_target(tester), 88);
      await _finishStep(tester);
      expect(painted(tester), closeTo(88 / 90, 1e-9));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the figure beats once a second over the last 5 s only', (
      tester,
    ) async {
      DateTime now() => tester.binding.clock.now();
      final endsAt = now().add(const Duration(milliseconds: 8400));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 30, now: now),
      );
      for (var k = 8; k >= 0; k--) {
        await _reach(tester, endsAt, Duration(milliseconds: k * 1000 - 1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 52));
        if (k >= 1 && k <= 5) {
          expect(_beat(tester), greaterThan(1.05), reason: 'beat at $k');
          expect(_beat(tester), lessThanOrEqualTo(1.06), reason: '$k');
        } else {
          expect(_beat(tester), 1.0, reason: 'no beat at $k');
        }
        await tester.pump(const Duration(milliseconds: 98));
        expect(_beat(tester), 1.0, reason: 'back to rest at $k');
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: the bar jumps in the frame of the figures, no '
        'beat and no ticker', (tester) async {
      DateTime now() => tester.binding.clock.now();
      final endsAt = now().add(const Duration(milliseconds: 7400));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 30, now: now),
        disableAnimations: true,
      );
      for (var k = 7; k >= 0; k--) {
        await _reach(tester, endsAt, Duration(milliseconds: k * 1000 - 1));
        expect(find.text(formatRestClock(k)), findsOneWidget);
        expect(painted(tester), closeTo(k / 30, 1e-9), reason: '$k');
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 0, reason: '$k');
        await tester.pump(const Duration(milliseconds: 52));
        expect(_beat(tester), 1.0, reason: '$k');
      }
      await tester.pumpWidget(const SizedBox());
    });

    Future<void Function(Duration)> pumpExtendable(
      WidgetTester tester, {
      bool reduced = false,
      bool scope = true,
    }) async {
      DateTime now() => tester.binding.clock.now();
      var endsAt = now().add(const Duration(seconds: 90));
      late StateSetter setOuter;
      await pumpComponent(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            // The callers key the countdown by its deadline.
            final countdown = RestCountdown(
              key: ValueKey('rest-countdown-${endsAt.millisecondsSinceEpoch}'),
              restEndsAt: endsAt,
              totalSeconds: 90,
              now: now,
            );
            return scope
                ? RestCountdownScope(restId: 'rest', child: countdown)
                : countdown;
          },
        ),
        disableAnimations: reduced,
      );
      return (extra) => setOuter(() => endsAt = endsAt.add(extra));
    }

    testWidgets('«+30 s»: the bar and the scale rescale to the new total in '
        '180 ms and the new marks fade in over 150 ms', (tester) async {
      final extend = await pumpExtendable(tester);
      expect(_labels(tester), ['0', '30', '60', '90 s']);
      await tester.pump(const Duration(seconds: 30));
      await _finishStep(tester);
      expect(find.text('1:00'), findsOneWidget);
      expect(painted(tester), closeTo(60 / 90, 1e-9));

      extend(const Duration(seconds: 30));
      await tester.pump();
      expect(find.text('1:30'), findsOneWidget);
      expect(tester.widget<RestStepRule>(_rule).totalSeconds, 120);
      expect(_labels(tester), ['0', '30', '60', '90', '120 s']);
      // It grows from where it was, it does not start over.
      expect(painted(tester), closeTo(60 / 90, 1e-9));
      expect(_scaleOpacity(tester), 0.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(painted(tester), greaterThan(60 / 90));
      expect(painted(tester), lessThan(90 / 120));
      expect(_scaleOpacity(tester), inExclusiveRange(0.0, 1.0));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_scaleOpacity(tester), 1.0);
      expect(painted(tester), lessThan(90 / 120));
      await tester.pump(const Duration(milliseconds: 30));
      expect(painted(tester), closeTo(90 / 120, 1e-9));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('«+30 s» with reduced motion: rescaled at once, no fade', (
      tester,
    ) async {
      final extend = await pumpExtendable(tester, reduced: true);
      await tester.pump(const Duration(seconds: 30));
      extend(const Duration(seconds: 30));
      await tester.pump();
      expect(_labels(tester), ['0', '30', '60', '90', '120 s']);
      expect(painted(tester), closeTo(90 / 120, 1e-9));
      expect(_scaleOpacity(tester), 1.0);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a countdown mounted outside a scope starts from its deadline '
        'without animating', (tester) async {
      final extend = await pumpExtendable(tester, scope: false);
      await tester.pump(const Duration(seconds: 30));
      extend(const Duration(seconds: 30));
      await tester.pump();
      // As before L5-D48: the total is the prescribed rest or what is left.
      expect(tester.widget<RestStepRule>(_rule).totalSeconds, 90);
      expect(painted(tester), closeTo(1.0, 1e-9));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    });

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: data-colour bar over the rule tone, '
          'scale in the secondary colour, active contrast >= 3:1', (
        tester,
      ) async {
        final endsAt = DateTime(2026, 11, 26, 10, 1, 30);
        await pumpComponent(
          tester,
          RestCountdown(
            restEndsAt: endsAt,
            totalSeconds: 90,
            now: () => DateTime(2026, 11, 26, 10, 0, 45),
          ),
          brightness: brightness,
        );
        final palette = tester.element(_rule).exomPalette;
        Color colourOf(String key) => tester
            .widget<ColoredBox>(
              find
                  .descendant(
                    of: find.byKey(Key(key)),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            )
            .color;
        expect(colourOf('rest-step-bar'), palette.data);
        expect(
          tester
              .widget<ColoredBox>(find.byKey(const Key('rest-step-track')))
              .color,
          palette.borderSoft,
        );
        expect(
          tester.getSize(find.byKey(const Key('rest-step-track'))),
          const Size(390, 8),
        );
        expect(painted(tester), closeTo(0.5, 1e-9));
        for (final label
            in find
                .descendant(of: _rule, matching: find.byType(Text))
                .evaluate()) {
          final text = label.widget as Text;
          expect(text.style?.color, palette.textSecondary);
          expect(text.style?.fontSize, 13);
        }
        final ticks = find.descendant(
          of: _rule,
          matching: find.byKey(const ValueKey('rest-step-tick')),
        );
        expect(ticks, findsNWidgets(4));
        for (final tick in ticks.evaluate()) {
          expect(tick.size, const Size(2, 6));
          expect((tick.widget as ColoredBox).color, palette.textSecondary);
        }
        expect(
          contrastRatio(palette.data, palette.background),
          greaterThanOrEqualTo(3),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    for (final total in const [30, 60, 90, 180, 3600]) {
      for (final locale in const [Locale('es'), Locale('en')]) {
        testWidgets('$total s at text scale 1.6 (nonlinear, 320 dp, '
            '${locale.languageCode}): no overflow and no label overlaps', (
          tester,
        ) async {
          final now = DateTime(2026, 11, 26, 10);
          await pumpComponent(
            tester,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: RestCountdown(
                restEndsAt: now.add(Duration(seconds: total)),
                totalSeconds: total,
                now: () => now,
              ),
            ),
            width: 320,
            height: 640,
            textScaler: const AndroidNonlinearTextScaler(1.6),
            locale: locale,
          );
          expectNoOverflow(tester);
          final track = tester.getRect(
            find.byKey(const Key('rest-step-track')),
          );
          final rects = [
            for (final e
                in find
                    .descendant(of: _rule, matching: find.byType(Text))
                    .evaluate())
              tester.getRect(find.byWidget(e.widget)),
          ]..sort((a, b) => a.left.compareTo(b.left));
          expect(rects.length, greaterThanOrEqualTo(2));
          for (var i = 0; i < rects.length; i++) {
            expect(rects[i].left, greaterThanOrEqualTo(track.left - 0.01));
            expect(rects[i].right, lessThanOrEqualTo(track.right + 0.01));
            if (i > 0) {
              expect(rects[i].left, greaterThan(rects[i - 1].right));
            }
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('semantics: one container with the remaining time, the bar and '
        'scale hidden, no live region, the same three announcements', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      DateTime now() => tester.binding.clock.now();
      final endsAt = now().add(const Duration(milliseconds: 11400));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 30, now: now),
      );
      await tester.pump();
      expect(tester.takeAnnouncements().map((a) => a.message), [
        'Descanso, quedan 0:12',
      ]);
      expect(find.bySemanticsLabel('Descanso, quedan 0:12'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^30 s$')), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^10$')), findsNothing);
      final root = tester.getSemantics(find.byType(RestCountdown));
      expect(root.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      var children = 0;
      root.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0, reason: 'the bar and scale add no nodes');

      await _reach(tester, endsAt, const Duration(milliseconds: 9999));
      expect(tester.takeAnnouncements().map((a) => a.message), [
        'Quedan 10 segundos de descanso',
      ]);
      await _reach(tester, endsAt, Duration.zero);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeAnnouncements().map((a) => a.message), [
        'Descanso terminado',
      ]);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the bar repaints on its own layer', (tester) async {
      final now = DateTime(2026, 11, 26, 10);
      await pumpComponent(
        tester,
        RestCountdown(
          restEndsAt: now.add(const Duration(seconds: 90)),
          totalSeconds: 90,
          now: () => now,
        ),
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('rest-step-bar')),
          matching: find.descendant(
            of: _rule,
            matching: find.byType(RepaintBoundary),
          ),
        ),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('floating rest timer', () {
    testWidgets('bar and figures change on the same whole second and the '
        'figure beats over the last 5 s', (tester) async {
      DateTime now() => tester.binding.clock.now();
      final endsAt = now().add(const Duration(milliseconds: 29400));
      var finished = 0;
      await pumpComponent(
        tester,
        RestTimerInline(
          totalSeconds: 30,
          restEndsAt: endsAt,
          onSkip: () {},
          onFinished: () => finished++,
          now: now,
        ),
      );
      expect(_labels(tester), ['0', '10', '20', '30 s']);
      for (var k = 29; k >= 1; k--) {
        await _reach(tester, endsAt, Duration(milliseconds: k * 1000 - 1));
        expect(
          find.descendant(
            of: find.byKey(const Key('rest-figure-pulse')),
            matching: find.text('$k'),
          ),
          findsOneWidget,
          reason: '$k',
        );
        expect(_target(tester), k, reason: 'bar target at $k');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 52));
        if (k <= 5) {
          expect(_beat(tester), greaterThan(1.05), reason: 'beat at $k');
        } else {
          expect(_beat(tester), 1.0, reason: 'no beat at $k');
        }
        await tester.pump(const Duration(milliseconds: 98));
        expect(painted(tester), closeTo(k / 30, 1e-9), reason: 'step $k');
      }
      await _reach(tester, endsAt, Duration.zero);
      expect(find.text('0'), findsWidgets);
      expect(_target(tester), 0);
      // The end is still dispatched by the same once-a-second tick.
      await tester.pump(const Duration(seconds: 1));
      expect(finished, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // Round r2 of CRONO: review follow-ups and the guarantees of the retired
  // `rest_rule_motion_test.dart`, now for the bar.
  group('r2', () {
    testWidgets('the curve of the scale fade is disposed with the rule', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 26, 10);
      await pumpComponent(
        tester,
        RestCountdown(
          restEndsAt: now.add(const Duration(seconds: 90)),
          totalSeconds: 90,
          now: () => now,
        ),
      );
      final opacity = tester
          .widget<FadeTransition>(find.byKey(const Key('rest-step-scale')))
          .opacity;
      expect(opacity, isA<CurvedAnimation>());
      expect((opacity as CurvedAnimation).isDisposed, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(opacity.isDisposed, isTrue);
    });

    group('RestCountdownScope: only the same rest is extended', () {
      testWidgets('two rests in a row in the same scope: the second starts '
          'with its own total, not the sum', (tester) async {
        final rests = await _pumpRests(tester);
        await tester.pump(const Duration(seconds: 30));
        await _finishStep(tester);
        expect(painted(tester), closeTo(60 / 90, 1e-9));
        // The next set's rest starts while the first one still had 60 s.
        rests.update(() {
          rests.restId = ('exercise-a', 2);
          rests.endsAt = tester.binding.clock.now().add(
            const Duration(seconds: 90),
          );
        });
        await tester.pump();
        expect(find.text('1:30'), findsOneWidget);
        expect(tester.widget<RestStepRule>(_rule).totalSeconds, 90);
        expect(_labels(tester), ['0', '30', '60', '90 s']);
        expect(painted(tester), closeTo(1.0, 1e-9));
        expect(_scaleOpacity(tester), 1.0);
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('several «+30 s» in a row keep adding to the same rest', (
        tester,
      ) async {
        final rests = await _pumpRests(tester);
        await tester.pump(const Duration(seconds: 30));
        await _finishStep(tester);
        // 60 s left of 90.
        rests.update(() => rests.endsAt = rests.endsAt.add(_thirty));
        await tester.pump();
        expect(tester.widget<RestStepRule>(_rule).totalSeconds, 120);
        await tester.pump(const Duration(milliseconds: 200));
        expect(painted(tester), closeTo(90 / 120, 1e-9));
        // A second one straight after, while the first still settles.
        rests.update(() => rests.endsAt = rests.endsAt.add(_thirty));
        await tester.pump();
        expect(tester.widget<RestStepRule>(_rule).totalSeconds, 150);
        await tester.pump(const Duration(milliseconds: 200));
        expect(painted(tester), closeTo(120 / 150, 1e-9));
        // And a third, 10 s later.
        await _reach(
          tester,
          rests.endsAt,
          const Duration(milliseconds: 109999),
        );
        await _finishStep(tester);
        expect(find.text('1:50'), findsOneWidget);
        rests.update(() => rests.endsAt = rests.endsAt.add(_thirty));
        await tester.pump();
        expect(find.text('2:20'), findsOneWidget);
        expect(tester.widget<RestStepRule>(_rule).totalSeconds, 180);
        expect(_labels(tester), ['0', '60', '120', '180 s']);
        await tester.pump(const Duration(milliseconds: 200));
        expect(painted(tester), closeTo(140 / 180, 1e-9));
        await tester.pumpWidget(const SizedBox());
      });

      for (final (name, nextId, nextTotal) in const [
        ('another exercise', ('exercise-b', 1), 75),
        ('another round of the circuit', ('circuit', 2, 0, 'round'), 120),
      ]) {
        testWidgets('a rest of $name while the previous one runs starts with '
            'its own total ($nextTotal s)', (tester) async {
          final rests = await _pumpRests(tester);
          await tester.pump(const Duration(seconds: 30));
          await _finishStep(tester);
          // The previous rest ends in 60 s; the new one later.
          rests.update(() {
            rests.restId = nextId;
            rests.total = nextTotal;
            rests.endsAt = tester.binding.clock.now().add(
              Duration(seconds: nextTotal),
            );
          });
          await tester.pump();
          expect(tester.widget<RestStepRule>(_rule).totalSeconds, nextTotal);
          expect(painted(tester), closeTo(1.0, 1e-9));
          await tester.pump();
          expect(tester.binding.transientCallbackCount, 0);
          await tester.pumpWidget(const SizedBox());
        });
      }
    });

    for (final floating in const [false, true]) {
      final name = floating ? 'floating rest' : 'rest countdown';
      Widget rest(DateTime endsAt, int total, DateTime Function() now) =>
          floating
          ? RestTimerInline(
              totalSeconds: total,
              restEndsAt: endsAt,
              onSkip: () {},
              onFinished: () {},
              now: now,
            )
          : RestCountdown(restEndsAt: endsAt, totalSeconds: total, now: now);

      for (final scale in const [1.0, 1.6]) {
        testWidgets('$name: the beat at text scale $scale (nonlinear, 320 dp) '
            'paints inside the figure box', (tester) async {
          DateTime now() => tester.binding.clock.now();
          final endsAt = now().add(const Duration(milliseconds: 5400));
          await pumpComponent(
            tester,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: rest(endsAt, 30, now),
            ),
            width: 320,
            height: 640,
            textScaler: AndroidNonlinearTextScaler(scale),
          );
          final pulse = find.byKey(const Key('rest-figure-pulse'));
          final figure = find.descendant(
            of: pulse,
            matching: find.byType(Text),
          );
          // The box the layout gives the figure (the FittedBox).
          final box = tester.getRect(
            find.ancestor(of: pulse, matching: find.byType(FittedBox)),
          );
          await _reach(tester, endsAt, const Duration(milliseconds: 4999));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 52));
          expect(_beat(tester), greaterThan(1.05));
          final ink = tester.getRect(figure);
          expect(ink.left, greaterThanOrEqualTo(box.left - 0.01));
          expect(ink.right, lessThanOrEqualTo(box.right + 0.01));
          expect(ink.top, greaterThanOrEqualTo(box.top - 0.01));
          expect(ink.bottom, lessThanOrEqualTo(box.bottom + 0.01));
          expect(box.right, lessThanOrEqualTo(320 - 24 + 0.01));
          expectNoOverflow(tester);
          await tester.pumpWidget(const SizedBox());
        });
      }

      testWidgets('$name: a hidden route (TickerMode off) schedules no frames, '
          'not even on the second boundary', (tester) async {
        DateTime now() => tester.binding.clock.now();
        final endsAt = now().add(const Duration(milliseconds: 6400));
        await pumpComponent(
          tester,
          TickerMode(enabled: false, child: rest(endsAt, 30, now)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.binding.hasScheduledFrame, isFalse);
        for (var k = 6; k >= 3; k--) {
          await _reach(tester, endsAt, Duration(milliseconds: k * 1000 - 1));
          expect(_target(tester), k);
          expect(painted(tester), closeTo(k / 30, 1e-9), reason: '$k');
          expect(tester.binding.transientCallbackCount, 0, reason: '$k');
          expect(tester.binding.hasScheduledFrame, isFalse, reason: '$k');
          expect(_beat(tester), 1.0, reason: '$k');
        }
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('$name: TickerMode muted and enabled again, the bar is at '
          'the real value at once, without animating', (tester) async {
        DateTime now() => tester.binding.clock.now();
        final endsAt = now().add(const Duration(milliseconds: 59400));
        var enabled = true;
        late StateSetter setOuter;
        await pumpComponent(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return TickerMode(enabled: enabled, child: rest(endsAt, 60, now));
            },
          ),
        );
        await _reach(tester, endsAt, const Duration(milliseconds: 49999));
        await _finishStep(tester);
        expect(painted(tester), closeTo(50 / 60, 1e-9));
        setOuter(() => enabled = false);
        await tester.pump();
        await _reach(tester, endsAt, const Duration(milliseconds: 39999));
        setOuter(() => enabled = true);
        await tester.pump();
        expect(_target(tester), 40);
        expect(painted(tester), closeTo(40 / 60, 1e-9));
        await tester.pump(const Duration(milliseconds: 16));
        expect(painted(tester), closeTo(40 / 60, 1e-9));
        expect(tester.binding.transientCallbackCount, 0);
        // And the next second steps as usual.
        await _reach(tester, endsAt, const Duration(milliseconds: 38999));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(painted(tester), lessThan(40 / 60));
        expect(painted(tester), greaterThan(39 / 60));
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('$name: reduced motion turned on mid-rest stops the step and '
          'the beat at the right value, and nothing moves after', (
        tester,
      ) async {
        DateTime now() => tester.binding.clock.now();
        final endsAt = now().add(const Duration(milliseconds: 8400));
        // The preference changes under the rest only: re-pumping the whole
        // harness would animate the app's own theme as well.
        var reduced = false;
        late StateSetter setOuter;
        await pumpComponent(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: rest(endsAt, 30, now),
              );
            },
          ),
        );
        await _reach(tester, endsAt, const Duration(milliseconds: 4999));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        // Mid-step and mid-beat.
        expect(painted(tester), greaterThan(5 / 30));
        expect(_beat(tester), greaterThan(1.0));
        setOuter(() => reduced = true);
        await tester.pump();
        expect(painted(tester), closeTo(5 / 30, 1e-9));
        expect(_beat(tester), 1.0);
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 0);
        for (var k = 4; k >= 1; k--) {
          await _reach(tester, endsAt, Duration(milliseconds: k * 1000 - 1));
          expect(painted(tester), closeTo(k / 30, 1e-9), reason: '$k');
          await tester.pump();
          expect(tester.binding.transientCallbackCount, 0, reason: '$k');
          await tester.pump(const Duration(milliseconds: 52));
          expect(_beat(tester), 1.0, reason: '$k');
        }
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('$name: after the app is paused and resumed the figures and '
          'the bar show the real time at once, without animating the jump', (
        tester,
      ) async {
        var now = DateTime(2026, 11, 26, 10);
        final endsAt = now.add(const Duration(seconds: 60));
        await pumpComponent(tester, rest(endsAt, 60, () => now));
        now = now.add(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 10));
        await _finishStep(tester);
        expect(_target(tester), 50);
        expect(painted(tester), closeTo(50 / 60, 1e-9));
        addTearDown(
          () => tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          ),
        );
        for (final state in const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        // The process sleeps: the wall clock runs, no timer fires.
        now = now.add(const Duration(seconds: 20));
        for (final state in const [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        expect(
          find.descendant(
            of: find.byKey(const Key('rest-figure-pulse')),
            matching: find.text(floating ? '30' : '0:30'),
          ),
          findsOneWidget,
        );
        expect(_target(tester), 30);
        expect(painted(tester), closeTo(30 / 60, 1e-9));
        await tester.pump(const Duration(milliseconds: 16));
        expect(painted(tester), closeTo(30 / 60, 1e-9));
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('floating rest, reduced motion: the bar jumps with the '
        'figure, no beat and no ticker', (tester) async {
      DateTime now() => tester.binding.clock.now();
      final endsAt = now().add(const Duration(milliseconds: 7400));
      await pumpComponent(
        tester,
        RestTimerInline(
          totalSeconds: 30,
          restEndsAt: endsAt,
          onSkip: () {},
          onFinished: () {},
          now: now,
        ),
        disableAnimations: true,
      );
      for (var k = 7; k >= 1; k--) {
        await _reach(tester, endsAt, Duration(milliseconds: k * 1000 - 1));
        expect(painted(tester), closeTo(k / 30, 1e-9), reason: '$k');
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 0, reason: '$k');
        await tester.pump(const Duration(milliseconds: 52));
        expect(_beat(tester), 1.0, reason: '$k');
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('floating rest: the bar repaints on its own layer', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 26, 10);
      await pumpComponent(
        tester,
        RestTimerInline(
          totalSeconds: 90,
          restEndsAt: now.add(const Duration(seconds: 90)),
          onSkip: () {},
          onFinished: () {},
          now: () => now,
        ),
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('rest-step-bar')),
          matching: find.descendant(
            of: _rule,
            matching: find.byType(RepaintBoundary),
          ),
        ),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}

const _thirty = Duration(seconds: 30);

/// A rest view whose deadline, rest identity and total the test changes, with
/// the countdown keyed by its deadline under one [RestCountdownScope], as the
/// pages do.
class _Rests {
  _Rests(this.endsAt);

  DateTime endsAt;
  Object restId = ('exercise-a', 1);
  int total = 90;
  late StateSetter _set;

  void update(VoidCallback change) => _set(change);
}

Future<_Rests> _pumpRests(WidgetTester tester) async {
  DateTime now() => tester.binding.clock.now();
  final rests = _Rests(now().add(const Duration(seconds: 90)));
  await pumpComponent(
    tester,
    StatefulBuilder(
      builder: (context, setState) {
        rests._set = setState;
        return RestCountdownScope(
          restId: rests.restId,
          child: RestCountdown(
            key: ValueKey('rest-countdown-${rests.endsAt.millisecondsSinceEpoch}'),
            restEndsAt: rests.endsAt,
            totalSeconds: rests.total,
            now: now,
          ),
        );
      },
    ),
  );
  return rests;
}
