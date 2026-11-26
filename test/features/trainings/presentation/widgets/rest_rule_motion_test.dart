// L5-E3e, owner's follow-ups on the 50-mark rule shared by the rest
// countdown, the floating rest timer and the timer of a timed set:
//
// «Tirón por segundo»: the rule paused for an instant every second (a 1 s
// Timer set a target and a 1 s linear tween ran to it, then stood still until
// the next tick). Now it drains every frame from the real deadline; the
// «m:ss» figures still change once a second. Sampled every 16 ms across
// several second changes, the remaining share must fall strictly.
//
// «Marcas por segundo»: the rule is time based. Tall marks sit exactly on
// multiples of a round step of seconds (the smallest of 1, 2, 5, 10, 15, 30,
// 60, … with at most 20 steps in the duration) and short marks split each
// step into 2 to 5 equal parts, so the total stays close to 50 (at most 60).
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_timer_inline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/exom_component_harness.dart';
import 'execution_timer_rule_test.dart' show pumpTimer, timerState;

double _value(WidgetTester tester) =>
    tester.widget<RestTickRule>(find.byType(RestTickRule)).value;

/// Pumps [frames] frames 16 ms apart, moving the injected clock with them,
/// and returns the rule value of each.
Future<List<double>> _sample(
  WidgetTester tester,
  void Function(Duration step) advance, {
  int frames = 160,
}) async {
  const step = Duration(milliseconds: 16);
  final values = <double>[];
  for (var i = 0; i < frames; i++) {
    advance(step);
    await tester.pump(step);
    values.add(_value(tester));
  }
  return values;
}

void _expectStrictlyFalling(List<double> values) {
  for (var i = 1; i < values.length; i++) {
    expect(
      values[i],
      lessThan(values[i - 1]),
      reason:
          'frame $i (${i * 16} ms) stands still or rises: '
          '${values[i - 1]} → ${values[i]}',
    );
  }
}

void main() {
  group('Tirón por segundo: the rule drains every frame', () {
    testWidgets('rest countdown', (tester) async {
      var now = DateTime(2026, 11, 26, 10);
      final endsAt = now.add(const Duration(seconds: 90));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: () => now),
      );
      final values = await _sample(tester, (d) => now = now.add(d));
      _expectStrictlyFalling(values);
      // The figures still change once a second, not every frame.
      expect(find.text('1:28'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('floating rest timer', (tester) async {
      var now = DateTime(2026, 11, 26, 10);
      await pumpComponent(
        tester,
        RestTimerInline(
          totalSeconds: 30,
          restEndsAt: now.add(const Duration(seconds: 30)),
          onSkip: () {},
          onFinished: () {},
          now: () => now,
        ),
      );
      final values = await _sample(tester, (d) => now = now.add(d));
      _expectStrictlyFalling(values);
      expect(find.text('28'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('timer of a timed set', (tester) async {
      final t0 = DateTime(2026, 11, 26, 10);
      var now = t0.add(const Duration(seconds: 10));
      await pumpTimer(
        tester,
        timerState(totalSeconds: 60, startedAt: t0),
        now: () => now,
      );
      final values = await _sample(tester, (d) => now = now.add(d));
      _expectStrictlyFalling(values);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a hidden route schedules no frames (TickerMode)', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 26, 10);
      await pumpComponent(
        tester,
        TickerMode(
          enabled: false,
          child: RestCountdown(
            restEndsAt: now.add(const Duration(seconds: 90)),
            totalSeconds: 90,
            now: () => now,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: one step a second, no frames in between', (
      tester,
    ) async {
      var now = DateTime(2026, 11, 26, 10);
      final endsAt = now.add(const Duration(seconds: 90));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: () => now),
        disableAnimations: true,
      );
      expect(_value(tester), closeTo(1.0, 1e-9));
      now = now.add(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_value(tester), closeTo(1.0, 1e-9));
      now = now.add(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_value(tester), closeTo(89 / 90, 1e-9));
      await tester.pumpWidget(const SizedBox());
    });
  });

  // Round r2: the rest rule is read from the wall clock every frame, so it is
  // the real remaining time over the total, ends empty exactly at the
  // deadline and never drifts from it (r1 anchored the first frame a second
  // ahead and then followed the frame time, correcting only drifts > 1.5 s).
  group('r2: the rest rule follows the deadline exactly', () {
    double exact(DateTime endsAt, DateTime now, int totalSeconds) =>
        endsAt.difference(now).inMilliseconds / (totalSeconds * 1000);

    testWidgets('one second before the end it is not empty; at the deadline '
        'it is', (tester) async {
      var now = DateTime(2026, 11, 26, 10);
      final endsAt = now.add(const Duration(seconds: 90));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: () => now),
      );
      expect(_value(tester), closeTo(1.0, 1e-9));
      for (var s = 0; s < 89; s++) {
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('0:01'), findsOneWidget);
      expect(_value(tester), closeTo(1 / 90, 1e-9));
      now = now.add(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_value(tester), closeTo(0.5 / 90, 1e-9));
      now = endsAt;
      await tester.pump(const Duration(milliseconds: 500));
      expect(_value(tester), 0);
      await tester.pumpWidget(const SizedBox());
    });

    for (final jump in const [
      Duration(milliseconds: 700), // under the old 1.5 s threshold
      Duration(seconds: 4), // over it
    ]) {
      testWidgets('a clock jump of ${jump.inMilliseconds} ms (NTP) is '
          'followed on the next frame', (tester) async {
        var now = DateTime(2026, 11, 26, 10);
        final endsAt = now.add(const Duration(seconds: 90));
        await pumpComponent(
          tester,
          RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: () => now),
        );
        await _sample(tester, (d) => now = now.add(d), frames: 20);
        now = now.add(jump);
        now = now.add(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        expect(_value(tester), closeTo(exact(endsAt, now, 90), 1e-9));
        // And keeps draining from there.
        _expectStrictlyFalling(
          await _sample(tester, (d) => now = now.add(d), frames: 20),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a real clock jump backwards is accepted: the rule rises to '
        'the real remaining time', (tester) async {
      var now = DateTime(2026, 11, 26, 10);
      final endsAt = now.add(const Duration(seconds: 90));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: () => now),
      );
      await _sample(tester, (d) => now = now.add(d), frames: 200);
      final before = _value(tester);
      now = now.subtract(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_value(tester), greaterThan(before));
      expect(_value(tester), closeTo(exact(endsAt, now, 90), 1e-9));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a restarted ticker (reduced motion on and off) reads the '
        'deadline again', (tester) async {
      var now = DateTime(2026, 11, 26, 10);
      final endsAt = now.add(const Duration(seconds: 90));
      Future<void> pump({required bool reduced}) => pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: () => now),
        disableAnimations: reduced,
      );
      await pump(reduced: false);
      await _sample(tester, (d) => now = now.add(d), frames: 30);
      await pump(reduced: true);
      now = now.add(const Duration(milliseconds: 2300));
      await tester.pump(const Duration(milliseconds: 2300));
      await pump(reduced: false);
      expect(_value(tester), closeTo(exact(endsAt, now, 90), 1e-9));
      final values = await _sample(tester, (d) => now = now.add(d), frames: 30);
      _expectStrictlyFalling(values);
      expect(values.last, closeTo(exact(endsAt, now, 90), 1e-9));
      await tester.pumpWidget(const SizedBox());
    });

    for (final floating in const [false, true]) {
      testWidgets('TickerMode muted and enabled again '
          '(${floating ? 'floating rest' : 'rest countdown'}): the rule jumps '
          'to the real value without animating back', (tester) async {
        var now = DateTime(2026, 11, 26, 10);
        final endsAt = now.add(const Duration(seconds: 60));
        Future<void> pump({required bool enabled}) => pumpComponent(
          tester,
          TickerMode(
            enabled: enabled,
            child: floating
                ? RestTimerInline(
                    totalSeconds: 60,
                    restEndsAt: endsAt,
                    onSkip: () {},
                    onFinished: () {},
                    now: () => now,
                  )
                : RestCountdown(
                    restEndsAt: endsAt,
                    totalSeconds: 60,
                    now: () => now,
                  ),
          ),
        );
        await pump(enabled: true);
        await _sample(tester, (d) => now = now.add(d), frames: 30);
        await pump(enabled: false);
        now = now.add(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 10));
        await pump(enabled: true);
        expect(_value(tester), closeTo(exact(endsAt, now, 60), 1e-9));
        final values = await _sample(
          tester,
          (d) => now = now.add(d),
          frames: 30,
        );
        _expectStrictlyFalling(values);
        expect(values.last, closeTo(exact(endsAt, now, 60), 1e-9));
        await tester.pumpWidget(const SizedBox());
      });
    }

    for (final floating in const [false, true]) {
      testWidgets('the live rule repaints on its own layer (RepaintBoundary, '
          '${floating ? 'floating rest' : 'rest countdown'})', (tester) async {
        final now = DateTime(2026, 11, 26, 10);
        final endsAt = now.add(const Duration(seconds: 90));
        await pumpComponent(
          tester,
          floating
              ? RestTimerInline(
                  totalSeconds: 90,
                  restEndsAt: endsAt,
                  onSkip: () {},
                  onFinished: () {},
                  now: () => now,
                )
              : RestCountdown(
                  restEndsAt: endsAt,
                  totalSeconds: 90,
                  now: () => now,
                ),
        );
        expect(
          find.ancestor(
            of: find.byType(RestTickRule),
            matching: find.descendant(
              of: find.byType(LiveTickRule),
              matching: find.byType(RepaintBoundary),
            ),
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  // r2 · marca frontera continua: the owner saw the rule move by whole marks
  // (still for ~2 s per mark on long rules). r1 already fills the boundary
  // mark from the bottom with the share of its slice that is left, so the
  // painted lit area changes on every 16 ms frame, even in the middle of a
  // 3.3 s mark (180 s rest) or a 2.5 s mark (120 s phase of the timer).
  group('r2: the boundary mark drains continuously', () {
    /// Painted area in the data colour, measured on the laid-out boxes.
    double litArea(WidgetTester tester) {
      final rule = find.byType(RestTickRule);
      final data = tester.element(rule).exomPalette.data;
      var area = 0.0;
      for (final e
          in find
              .descendant(
                of: rule,
                matching: find.byWidgetPredicate(
                  (w) => w is ColoredBox && w.color == data,
                ),
              )
              .evaluate()) {
        area += e.size!.width * e.size!.height;
      }
      return area;
    }

    Future<void> expectEveryFrameMoves(
      WidgetTester tester,
      void Function(Duration step) advance,
    ) async {
      const step = Duration(milliseconds: 16);
      var previous = litArea(tester);
      for (var i = 1; i <= 60; i++) {
        advance(step);
        await tester.pump(step);
        final area = litArea(tester);
        expect(
          area,
          lessThan(previous),
          reason: 'frame $i: the painted rule did not move',
        );
        previous = area;
      }
    }

    testWidgets('rest countdown, 180 s (3.3 s per mark), mid-mark', (
      tester,
    ) async {
      final t0 = DateTime(2026, 11, 26, 10);
      final endsAt = t0.add(const Duration(seconds: 180));
      // 1.2 s into the boundary mark of 120..123.3 s left.
      var now = endsAt.subtract(const Duration(milliseconds: 122100));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 180, now: () => now),
      );
      await expectEveryFrameMoves(tester, (d) => now = now.add(d));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('floating rest, 180 s, mid-mark', (tester) async {
      final t0 = DateTime(2026, 11, 26, 10);
      final endsAt = t0.add(const Duration(seconds: 180));
      var now = endsAt.subtract(const Duration(milliseconds: 122100));
      await pumpComponent(
        tester,
        RestTimerInline(
          totalSeconds: 180,
          restEndsAt: endsAt,
          onSkip: () {},
          onFinished: () {},
          now: () => now,
        ),
      );
      await expectEveryFrameMoves(tester, (d) => now = now.add(d));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('timer of a timed set, 120 s (2.5 s per mark), mid-mark', (
      tester,
    ) async {
      final t0 = DateTime(2026, 11, 26, 10);
      var now = t0.add(const Duration(milliseconds: 31200));
      await pumpTimer(
        tester,
        timerState(totalSeconds: 120, startedAt: t0),
        now: () => now,
      );
      await expectEveryFrameMoves(tester, (d) => now = now.add(d));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Marcas por segundo: time-based marks', () {
    const expected = {
      // seconds: (step, marks); r4: + the boundary marker at 0.
      15: (1, 46),
      40: (2, 41),
      90: (5, 55),
      180: (10, 55),
    };
    expected.forEach((seconds, shape) {
      test('$seconds s: tall marks every ${shape.$1} s, ${shape.$2} marks', () {
        final layout = RestTickLayout.forSeconds(seconds);
        expect(layout.stepSeconds, shape.$1);
        expect(layout.marks.length, shape.$2);
        expect(layout.marks.length, inInclusiveRange(40, 60));
        // r3/r4: a tall boundary marker at t = 0; the rest close whole steps.
        expect(layout.marks.first.tall, isTrue);
        final tallEnds = [
          for (final m in layout.marks.skip(1))
            if (m.tall) m.endMs,
        ];
        expect(tallEnds, [
          for (var t = shape.$1; t <= seconds; t += shape.$1) t * 1000,
        ]);
        // Marks tile the duration without gaps.
        expect(layout.marks.first.startMs, 0);
        expect(layout.marks.last.endMs, seconds * 1000);
        for (var i = 1; i < layout.marks.length; i++) {
          expect(layout.marks[i].startMs, layout.marks[i - 1].endMs);
        }
      });
    });

    test('a duration off the step: the last section is short and only the '
        'end is tall after the last whole step', () {
      final layout = RestTickLayout.forSeconds(47);
      expect(layout.stepSeconds, 5);
      expect(layout.marks.first.tall, isTrue);
      final tallEnds = [
        for (final m in layout.marks.skip(1))
          if (m.tall) m.endMs,
      ];
      expect(tallEnds, [for (var t = 5; t <= 45; t += 5) t * 1000, 47000]);
      expect(layout.marks.length, lessThanOrEqualTo(60));
    });

    test('every duration keeps at most 20 steps and at most 60 marks', () {
      for (final seconds in [
        1,
        5,
        7,
        20,
        21,
        45,
        61,
        119,
        300,
        1200,
        1440,
        3600,
        7200,
      ]) {
        final layout = RestTickLayout.forSeconds(seconds);
        expect(
          (seconds / layout.stepSeconds).ceil(),
          lessThanOrEqualTo(20),
          reason: '$seconds s',
        );
        expect(
          layout.marks.length,
          lessThanOrEqualTo(60),
          reason: '$seconds s',
        );
        expect(layout.marks.last.endMs, seconds * 1000);
      }
    });

    testWidgets('the painted marks follow the layout: tall ones on whole '
        'steps', (tester) async {
      await pumpComponent(
        tester,
        const Padding(
          padding: EdgeInsets.all(24),
          child: RestTickRule(value: 0, totalSeconds: 15),
        ),
      );
      final marks = find.byKey(const ValueKey('rest-countdown-mark'));
      expect(marks, findsNWidgets(46));
      // Mark 0 is the boundary marker at t = 0 (r4) and is tall; marks 1
      // and 2 are short; mark 3 (ends at 1 s) is tall; mark 4 is short.
      double barHeight(int i) => tester
          .getSize(
            find.descendant(of: marks.at(i), matching: find.byType(ColoredBox)),
          )
          .height;
      expect(barHeight(0), closeTo(RestTickRule.height * 0.72, 0.01));
      expect(barHeight(1), closeTo(RestTickRule.height * 0.5, 0.01));
      expect(barHeight(2), closeTo(RestTickRule.height * 0.5, 0.01));
      expect(barHeight(3), closeTo(RestTickRule.height * 0.72, 0.01));
      expect(barHeight(4), closeTo(RestTickRule.height * 0.5, 0.01));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the lit edge falls inside the mark of the real time', (
      tester,
    ) async {
      // 15 s, 10 s left: the marker at 0 and slices 1..30 lit, 31 dark.
      await pumpComponent(
        tester,
        const RestTickRule(value: 10 / 15, totalSeconds: 15),
      );
      final marks = find.byKey(const ValueKey('rest-countdown-mark'));
      final data = tester.element(marks.first).exomPalette.data;
      int lit(int i) => find
          .descendant(
            of: marks.at(i),
            matching: find.byWidgetPredicate(
              (w) => w is ColoredBox && w.color == data,
            ),
          )
          .evaluate()
          .length;
      expect(lit(30), 1);
      expect(lit(31), 0);
      await tester.pumpWidget(const SizedBox());
    });

    for (final scale in const [1.6, 2.0]) {
      testWidgets('320 dp at text scale $scale: 60 marks and the scale fit', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                RestTickRule(value: 0.5, totalSeconds: 20),
                RestTickScale(totalSeconds: 20),
              ],
            ),
          ),
          width: 320,
          height: 640,
          textScaler: AndroidNonlinearTextScaler(scale),
        );
        expect(
          find.byKey(const ValueKey('rest-countdown-mark')),
          findsNWidgets(RestTickLayout.forSeconds(20).marks.length),
        );
        expectNoOverflow(tester);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
