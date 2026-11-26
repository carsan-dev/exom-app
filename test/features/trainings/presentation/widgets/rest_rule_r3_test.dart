// L5-E3e, round r3 (owner's decisions after the emulator pass):
//
// D2 · «altas en gris claro»: an unlit tall mark used a dark grey
// (`textSecondary`) background and the green draining over it was hardly
// visible (1.17:1 light, 1.46:1 dark), so the edge seemed to stop for ~72 %
// of a tall mark. Unlit tall marks now use exactly the colour of the unlit
// short ones; only their height tells them apart.
//
// Tall mark at 0: the rule is framed by a tall mark at each end; the inner
// tall marks stay on exact multiples of the step. Round r4: the one at 0 is a
// boundary marker without time, so no two tall marks are ever adjacent.
//
// D1 · figures behind the rule: the «m:ss» figures were refreshed by a timer
// started when the widget mounted, out of phase with the deadline, so they
// changed 50-250 ms after the rule crossed the second and the rule sat empty
// with «0:01». Now each figure change is scheduled on the exact second
// boundary of the deadline. The tests drive the widgets with the fake clock
// of the test binding, so timers and clock move together.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_timer_inline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/theme/wcag_contrast.dart';
import '../../../../core/widgets/exom_component_harness.dart';
import 'execution_timer_rule_test.dart' show pumpTimer, timerState;

double _ruleValue(WidgetTester tester) =>
    tester.widget<RestTickRule>(find.byType(RestTickRule)).value;

/// Whole seconds the rule shows as left: the same rounding as the figures.
int _ruleSeconds(WidgetTester tester, int totalSeconds) =>
    (_ruleValue(tester) * totalSeconds - 1e-9).ceil();

/// Moves the fake clock until [left] remains before [end], arriving with a
/// last 16 ms frame as on a device (a long pump may rebuild the whole tree).
Future<void> _reach(WidgetTester tester, DateTime end, Duration left) async {
  const frame = Duration(milliseconds: 16);
  await tester.pump(end.difference(tester.binding.clock.now()) - left - frame);
  await tester.pump(frame);
}

void main() {
  group('D2: unlit tall marks share the colour of the unlit short ones', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: same colour and opacity, only the '
          'height differs; lit vs unlit >= 3:1 for both', (tester) async {
        // 15 s, half left: marks 0..21 lit, 22 partial, the rest unlit.
        await pumpComponent(
          tester,
          const Padding(
            padding: EdgeInsets.all(24),
            child: RestTickRule(value: 0.5, totalSeconds: 15),
          ),
          brightness: brightness,
        );
        final layout = RestTickLayout.forSeconds(15);
        final marks = find.byKey(const ValueKey('rest-countdown-mark'));
        final palette = tester.element(marks.first).exomPalette;
        final unlitTall = layout.marks.indexWhere(
          (m) => m.tall && m.startMs >= 7500,
        );
        final unlitShort = layout.marks.indexWhere(
          (m) => !m.tall && m.startMs >= 7500,
        );
        ColoredBox only(int i) {
          final boxes = find.descendant(
            of: marks.at(i),
            matching: find.byType(ColoredBox),
          );
          expect(boxes, findsOneWidget, reason: 'mark $i is unlit');
          return tester.widget<ColoredBox>(boxes);
        }

        double height(int i) => tester
            .getSize(
              find.descendant(
                of: marks.at(i),
                matching: find.byType(ColoredBox),
              ),
            )
            .height;

        final tall = only(unlitTall).color;
        final short = only(unlitShort).color;
        expect(tall, short);
        expect(tall.a, short.a);
        expect(height(unlitTall), closeTo(RestTickRule.height * 0.72, 0.01));
        expect(height(unlitShort), closeTo(RestTickRule.height * 0.5, 0.01));

        // The colours really painted: data over the unlit background.
        for (final (name, unlit) in [('tall', tall), ('short', short)]) {
          final ratio = contrastRatio(palette.data, unlit);
          // ignore: avoid_print
          print(
            'CONTRAST ${brightness.name} lit ${hexRgb(palette.data)} / '
            'unlit $name ${hexRgb(unlit)} = ${ratio.toStringAsFixed(2)}:1',
          );
          expect(ratio, greaterThanOrEqualTo(3.0), reason: name);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  // Round r4: the tall mark at 0 is a boundary marker of its own (no time),
  // not the first slice made tall, so with 2 parts per step (20, 40, 300,
  // 600 s) the first two marks are no longer both tall and adjacent.
  group('Tall mark at 0: the rule is framed at both ends', () {
    const steps = {
      15: 1,
      20: 1,
      40: 2,
      47: 5,
      90: 5,
      180: 10,
      300: 15,
      600: 30,
    };
    steps.forEach((seconds, step) {
      test('$seconds s: a boundary marker at 0, tall marks on every multiple '
          'of $step s and at the end, never two tall ones together', () {
        final layout = RestTickLayout.forSeconds(seconds);
        final marks = layout.marks;
        expect(layout.stepSeconds, step);
        // The marker at 0 stands for no time and is tall.
        expect(marks.first.startMs, 0);
        expect(marks.first.endMs, 0);
        expect(marks.first.tall, isTrue);
        // The first slice keeps its normal height (it ends inside a step).
        expect(marks[1].tall, isFalse);
        final tallEnds = [
          for (final m in marks.skip(1))
            if (m.tall) m.endMs,
        ];
        expect(tallEnds, [
          for (var t = step; t <= seconds; t += step) t * 1000,
          if (seconds % step != 0) seconds * 1000,
        ]);
        expect(marks.last.tall, isTrue);
        for (var i = 1; i < marks.length; i++) {
          expect(
            marks[i].tall && marks[i - 1].tall,
            isFalse,
            reason: 'marks ${i - 1} and $i are both tall',
          );
        }
        // The marker counts towards the limit of the painted marks.
        expect(marks.length, inInclusiveRange(40, 60));
      });
    });

    for (final seconds in const [20, 90]) {
      testWidgets('$seconds s: the marker is as wide as the first slice and '
          'stays lit until the time is up', (tester) async {
        Future<void> pump(double value) => pumpComponent(
          tester,
          Padding(
            padding: const EdgeInsets.all(24),
            child: RestTickRule(value: value, totalSeconds: seconds),
          ),
          brightness: Brightness.light,
        );
        final marks = find.byKey(const ValueKey('rest-countdown-mark'));
        await pump(0.001);
        expect(
          marks,
          findsNWidgets(RestTickLayout.forSeconds(seconds).marks.length),
        );
        expect(
          tester.getSize(marks.at(0)).width,
          closeTo(tester.getSize(marks.at(1)).width, 0.01),
        );
        final data = tester.element(marks.first).exomPalette.data;
        Finder litBox(int i) => find.descendant(
          of: marks.at(i),
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == data,
          ),
        );
        // Lit and full height while any time is left.
        expect(litBox(0), findsOneWidget);
        expect(tester.getSize(litBox(0)).height, RestTickRule.height);
        await pump(0);
        expect(litBox(0), findsNothing);
        expect(
          tester
              .getSize(
                find.descendant(
                  of: marks.at(0),
                  matching: find.byType(ColoredBox),
                ),
              )
              .height,
          closeTo(RestTickRule.height * 0.72, 0.01),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('D1: figures and rule change in the same frame', () {
    testWidgets('rest countdown: on every second boundary and at the '
        'deadline', (tester) async {
      DateTime now() => tester.binding.clock.now();
      // Mounted 600 ms off the whole second, as on a real device.
      final endsAt = now().add(const Duration(milliseconds: 89400));
      await pumpComponent(
        tester,
        RestCountdown(restEndsAt: endsAt, totalSeconds: 90, now: now),
      );
      expect(find.text('1:30'), findsOneWidget);
      for (var k = 89; k >= 1; k--) {
        // 1 ms into second k (k s minus 1 ms left).
        final left = Duration(milliseconds: k * 1000 - 1);
        await _reach(tester, endsAt, left);
        expect(find.text(formatRestClock(k)), findsOneWidget, reason: '$k');
        expect(_ruleSeconds(tester, 90), k, reason: 'rule at $k');
      }
      // At the deadline: «0:00» and an empty rule in the same frame.
      await _reach(tester, endsAt, Duration.zero);
      expect(find.text('0:00'), findsOneWidget);
      expect(_ruleValue(tester), 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('floating rest timer: on every second boundary and at the '
        'deadline', (tester) async {
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
      for (var k = 29; k >= 1; k--) {
        final left = Duration(milliseconds: k * 1000 - 1);
        await _reach(tester, endsAt, left);
        expect(find.text('$k'), findsOneWidget, reason: '$k');
        expect(_ruleSeconds(tester, 30), k, reason: 'rule at $k');
      }
      await _reach(tester, endsAt, Duration.zero);
      expect(find.text('0'), findsOneWidget);
      expect(_ruleValue(tester), 0);
      // The end is still dispatched by the same once-a-second tick.
      await tester.pump(const Duration(seconds: 1));
      expect(finished, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('timer of a timed set: on every second boundary and at the '
        'deadline', (tester) async {
      DateTime now() => tester.binding.clock.now();
      // Started 10.5 s ago: the 200 ms refresh runs out of phase.
      final startedAt = now().subtract(const Duration(milliseconds: 10500));
      final deadline = startedAt.add(const Duration(seconds: 60));
      await pumpTimer(
        tester,
        timerState(totalSeconds: 60, startedAt: startedAt),
        now: now,
      );
      expect(find.textContaining('Tramo: 0:50'), findsOneWidget);
      for (var k = 49; k >= 1; k--) {
        final left = Duration(milliseconds: k * 1000 - 1);
        await _reach(tester, deadline, left);
        final figure = formatRestClock(k);
        expect(
          find.text('Tramo: $figure · Total restante: $figure'),
          findsOneWidget,
          reason: '$k',
        );
        expect(_ruleSeconds(tester, 60), k, reason: 'rule at $k');
      }
      await _reach(tester, deadline, Duration.zero);
      expect(find.text('Tiempo finalizado'), findsOneWidget);
      expect(_ruleValue(tester), 0);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
