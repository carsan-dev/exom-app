// M5 fill of the streak weeks grid (round 4, owner's request; L5-D40): the lit
// squares fill in reading order once per opening of the page, with one
// controller, ease-out and at most 600 ms; reduced motion, a refresh or a
// reload show the final state directly.
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_milestone_mark.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_streak_weeks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/exom_component_harness.dart';
import 'challenges_test_support.dart';

/// Effective opacity of each lit square inside the grid (the product of the
/// fades between the square and the grid), in reading order.
List<double> litOpacities(WidgetTester tester) {
  final result = <double>[];
  for (final element in find.byKey(ChallengeStreakWeeks.onKey).evaluate()) {
    var opacity = 1.0;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget.key == ChallengeStreakWeeks.gridKey) return false;
      if (widget is FadeTransition) opacity *= widget.opacity.value;
      return true;
    });
    result.add(opacity);
  }
  return result;
}

int visibleLit(WidgetTester tester) =>
    litOpacities(tester).where((o) => o > 0).length;

bool allLitFull(WidgetTester tester) =>
    litOpacities(tester).every((o) => o == 1.0);

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
    test('at most 600 ms and 40 ms per square, ease-out spread', () {
      for (final lit in const [1, 3, 12, 15, 26, 28]) {
        final timing = streakFillTiming(lit);
        expect(
          timing.total,
          lessThanOrEqualTo(ExomMotion.countUp),
          reason: '$lit',
        );
        final stepMs = timing.step * timing.total.inMicroseconds / 1000;
        expect(stepMs, lessThanOrEqualTo(40.0001), reason: '$lit');
      }
      // Few days: not slowed down by the stagger.
      expect(streakFillTiming(1).total, ExomMotion.chipCrossfade);
      expect(
        streakFillTiming(3).total,
        ExomMotion.chipCrossfade + const Duration(milliseconds: 80),
      );
      // Many days: the whole 600 ms (integer microseconds per step).
      expect(
        streakFillTiming(28).total.inMicroseconds,
        closeTo(ExomMotion.countUp.inMicroseconds, 30),
      );
    });
  });

  group('ChallengeStreakWeeks fill (M5)', () {
    testWidgets('0 lit on the first frame, all after 600 ms, in reading '
        'order', (tester) async {
      await pumpComponent(tester, _mark(12, gate: StreakFillGate()));
      expect(find.byKey(ChallengeStreakWeeks.onKey), findsNWidgets(12));
      expect(visibleLit(tester), 0);

      await tester.pump(const Duration(milliseconds: 100));
      final partial = litOpacities(tester);
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

    testWidgets('one controller for the whole grid', (tester) async {
      await pumpComponent(tester, _mark(28, gate: StreakFillGate()));
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
      expect(visibleLit(tester), 12);
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
      expect(visibleLit(tester), 0);
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
      expect(visibleLit(tester), 12);
      expect(allLitFull(tester), isTrue);
    });
  });
}
