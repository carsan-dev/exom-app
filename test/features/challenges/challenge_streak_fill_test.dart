// M5 fill of the streak weeks grid (rounds 4 and 5, owner's request; L5-D40):
// the lit squares change colour in a wave, in reading order, once per opening
// of the page, with one controller, ease-out and 600 ms in all (300 ms each),
// starting when the entry transition of the route ends; only the colour moves;
// reduced motion, a refresh or a reload show the final state directly.
import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_milestone_mark.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_streak_weeks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/exom_component_harness.dart';
import 'challenges_test_support.dart';

/// Progress (0 = rule tone, 1 = data colour) of each lit square, in reading
/// order, read from its current colour.
List<double> litProgress(WidgetTester tester) {
  final elements = find.byKey(ChallengeStreakWeeks.onKey).evaluate();
  if (elements.isEmpty) return const [];
  final palette = elements.first.exomPalette;
  final off = palette.borderSoft;
  final on = palette.data;
  final channels = <double Function(Color)>[
    (c) => c.a,
    (c) => c.r,
    (c) => c.g,
    (c) => c.b,
  ];
  // The channel that tells the two tones apart the most.
  final channel = channels.reduce(
    (a, b) => (a(on) - a(off)).abs() >= (b(on) - b(off)).abs() ? a : b,
  );
  return [
    for (final element in elements)
      (channel((element.widget as ColoredBox).color) - channel(off)) /
          (channel(on) - channel(off)),
  ];
}

bool allLitFull(WidgetTester tester) {
  final elements = find.byKey(ChallengeStreakWeeks.onKey).evaluate();
  if (elements.isEmpty) return false;
  final data = elements.first.exomPalette.data;
  return elements.every((e) => (e.widget as ColoredBox).color == data);
}

bool allLitDark(WidgetTester tester) =>
    litProgress(tester).every((p) => p == 0);

/// Squares strictly between the rule tone and the data colour.
int midway(WidgetTester tester) =>
    litProgress(tester).where((p) => p > 0 && p < 1).length;

/// Sizes of the lit squares.
List<Size> litSizes(WidgetTester tester) => [
  for (final element in find.byKey(ChallengeStreakWeeks.onKey).evaluate())
    tester.getSize(find.byWidget(element.widget)),
];

Widget _mark(int days, {StreakFillGate? gate}) {
  final mark = ChallengeMilestoneMark(
    value: '$days',
    days: days,
    semanticsLabel: '$days días',
  );
  return gate == null ? mark : StreakFillScope(gate: gate, child: mark);
}

void main() {
  group('streakFillTiming', () {
    double stepMs(int lit) {
      final t = streakFillTiming(lit);
      return t.step * t.total.inMicroseconds / 1000;
    }

    test('wave: 300 ms per square, 600 ms in all, no stagger cap', () {
      expect(ExomMotion.streakSquareFill, const Duration(milliseconds: 300));
      // lit: (total ms, stagger ms).
      const table = {1: (300, 0.0), 2: (600, 300.0), 12: (600, 300 / 11)};
      for (final entry in table.entries) {
        final timing = streakFillTiming(entry.key);
        expect(timing.total.inMicroseconds, entry.value.$1 * 1000);
        expect(stepMs(entry.key), closeTo(entry.value.$2, 1e-6));
        expect(
          timing.fade * timing.total.inMicroseconds / 1000,
          closeTo(300, 1e-6),
        );
      }
      expect(streakFillTiming(28).total, ExomMotion.countUp);
      expect(stepMs(28), closeTo(300 / 27, 1e-6));
    });
  });

  group('ChallengeStreakWeeks fill (M5)', () {
    testWidgets('0 lit on the first frame, all after 600 ms, in reading '
        'order', (tester) async {
      await pumpComponent(tester, _mark(12, gate: StreakFillGate()));
      expect(find.byKey(ChallengeStreakWeeks.onKey), findsNWidgets(12));
      expect(allLitDark(tester), isTrue);
      await tester.pump();
      expect(allLitDark(tester), isTrue);

      await tester.pump(const Duration(milliseconds: 100));
      final partial = litProgress(tester);
      // Reading order: earlier squares are never behind later ones.
      for (var i = 1; i < partial.length; i++) {
        expect(partial[i], lessThanOrEqualTo(partial[i - 1]));
      }
      expect(partial.first, greaterThan(0));
      expect(partial.last, 0);
      // Dark squares do not move.
      expect(find.byKey(ChallengeStreakWeeks.offKey), findsNWidgets(2));

      await tester.pump(const Duration(milliseconds: 500));
      expect(allLitFull(tester), isTrue);
      await tester.pumpAndSettle();
      expect(allLitFull(tester), isTrue);
      // The grid keeps its 50 %.
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byKey(ChallengeStreakWeeks.gridKey),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        0.5,
      );
    });

    testWidgets('midway: several squares at once in intermediate tones', (
      tester,
    ) async {
      await pumpComponent(tester, _mark(12, gate: StreakFillGate()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(midway(tester), greaterThanOrEqualTo(4));
      // The first ones are done, the last ones have not started.
      final progress = litProgress(tester);
      expect(progress.first, 1.0);
      expect(progress.last, 0.0);
      await tester.pumpAndSettle();
    });

    testWidgets('no square changes size while filling', (tester) async {
      await pumpComponent(tester, _mark(12, gate: StreakFillGate()));
      final initial = litSizes(tester);
      expect(initial.every((s) => s == const Size.square(18)), isTrue);
      expect(
        find.descendant(
          of: find.byKey(ChallengeStreakWeeks.gridKey),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(litSizes(tester), initial, reason: 'frame $i');
      }
      await tester.pumpAndSettle();
      expect(litSizes(tester), initial);
    });

    testWidgets('waits for the entry transition of the route', (tester) async {
      await pumpComponent(tester, const SizedBox());
      final navigator = Navigator.of(tester.element(find.byType(Scaffold)));
      final gate = StreakFillGate();
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: _mark(12, gate: gate)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final route = ModalRoute.of(
        tester.element(find.byType(ChallengeStreakWeeks)),
      )!.animation!;
      expect(route.status, AnimationStatus.forward);
      expect(find.byKey(ChallengeStreakWeeks.onKey), findsNWidgets(12));
      // Mid transition and up to its very last frames: every lit square
      // still looks dark.
      var midTransition = 0;
      while (route.status != AnimationStatus.completed) {
        expect(allLitDark(tester), isTrue, reason: 'route ${route.value}');
        midTransition++;
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(midTransition, greaterThan(3));
      // The transition has ended; the fill starts in the next frame.
      expect(allLitDark(tester), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(midway(tester), greaterThanOrEqualTo(4));
      await tester.pumpAndSettle();
      expect(allLitFull(tester), isTrue);
    });

    testWidgets('one controller for the whole grid', (tester) async {
      await pumpComponent(tester, _mark(28, gate: StreakFillGate()));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('reduced motion: final state from the first frame', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        _mark(12, gate: StreakFillGate()),
        disableAnimations: true,
      );
      expect(allLitFull(tester), isTrue);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a claimed gate (second build of the page) does not animate', (
      tester,
    ) async {
      final gate = StreakFillGate();
      await pumpComponent(tester, _mark(12, gate: gate));
      await tester.pumpAndSettle();
      await pumpComponent(tester, const SizedBox());
      await pumpComponent(tester, _mark(12, gate: gate));
      expect(allLitFull(tester), isTrue);
    });

    testWidgets('no scope: no animation', (tester) async {
      await pumpComponent(tester, _mark(12));
      expect(allLitFull(tester), isTrue);
    });

    testWidgets('new days while filling: final state at once', (tester) async {
      final gate = StreakFillGate();
      await pumpComponent(tester, _mark(12, gate: gate));
      await tester.pump(const Duration(milliseconds: 50));
      await pumpComponent(tester, _mark(13, gate: gate));
      expect(find.byKey(ChallengeStreakWeeks.onKey), findsNWidgets(13));
      expect(allLitFull(tester), isTrue);
    });
  });

  group('page (M5 once per opening)', () {
    Future<void> waitForMark(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        if (find.byType(ChallengeMilestoneMark).evaluate().isNotEmpty) return;
        await tester.pump();
      }
      fail('the streak mark never appeared');
    }

    testWidgets('fills on opening; a pull-to-refresh does not refill', (
      tester,
    ) async {
      final repository = FakeChallengesRepository();
      await pumpChallengesPage(
        tester,
        repository,
        height: 844,
        settle: false,
        disableAnimations: false,
      );
      await waitForMark(tester);
      expect(allLitDark(tester), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(allLitFull(tester), isTrue);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      for (var i = 0; i < 40 && repository.loads < 2; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(repository.loads, 2);
      await waitForMark(tester);
      expect(allLitFull(tester), isTrue);
      await tester.pumpAndSettle();
      expect(allLitFull(tester), isTrue);
    });

    testWidgets('reduced motion on the page: final state at once', (
      tester,
    ) async {
      await pumpChallengesPage(
        tester,
        FakeChallengesRepository(),
        height: 844,
        settle: false,
      );
      await waitForMark(tester);
      expect(allLitFull(tester), isTrue);
    });
  });
}
