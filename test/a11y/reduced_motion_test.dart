// S11-08a: with `MediaQuery.disableAnimations` the reduced variants of plan
// §8 apply and no information travels by movement alone. §8a/b/c, the
// count-up, the grow bar, the month grid, the countdowns and the route
// transitions have their reduced-motion tests next to each widget; this file
// closes the gap of the in-place state changes (set chips of the active
// exercise and rows of a circuit round): they crossfade in 120 ms with no
// slide or scale, and the new state (check, top rule, words) is in the tree
// without depending on the animation.
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/widgets/active_exercise_set_chips.dart';
import 'package:exom_app/features/trainings/presentation/widgets/circuit_round_list.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_value_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';

const _weight = WeightText(UnitSystem.metric, ',');

Widget _chips({required int completed, int? current}) => ActiveExerciseSetChips(
  totalSets: 3,
  completedSets: completed,
  currentSet: current,
  performances: [
    for (var i = 1; i <= completed; i++)
      SetPerformance(setNumber: i, reps: 8, weightKg: 60),
  ],
  targetLabel: '8 reps',
  weightText: _weight,
);

Widget _circuit({required CircuitRowState first}) => CircuitRoundList(
  title: 'Ronda 1',
  rows: [
    (
      key: const Key('row-a'),
      name: 'Sentadilla',
      state: first,
      value: first == CircuitRowState.done ? '8 reps' : null,
    ),
    (
      key: const Key('row-b'),
      name: 'Remo',
      state: CircuitRowState.next,
      value: null,
    ),
  ],
);

bool _hasMovement(WidgetTester tester, Finder within) => find
    .descendant(
      of: within,
      matching: find.byWidgetPredicate(
        (w) =>
            w is SlideTransition ||
            w is ScaleTransition ||
            w is AnimatedSlide ||
            w is AnimatedScale,
      ),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  group('ActiveExerciseSetChips con movimiento reducido', () {
    testWidgets('fundido de 120 ms, sin desplazamiento ni escala', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        _chips(completed: 0, current: 1),
        disableAnimations: true,
      );
      final switchers = tester.widgetList<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switchers, hasLength(3));
      for (final s in switchers) {
        expect(s.duration, ExomMotion.reducedFade);
      }
      expect(
        _hasMovement(tester, find.byType(ActiveExerciseSetChips)),
        isFalse,
      );
    });

    testWidgets('confirmar una serie: check y regla presentes al terminar '
        'el fundido, la anterior ya no está', (tester) async {
      await pumpComponent(
        tester,
        _chips(completed: 0, current: 1),
        disableAnimations: true,
      );
      expect(find.byKey(ActiveExerciseSetChips.doneRuleKey), findsNothing);
      expect(find.byIcon(ExomIcons.check), findsNothing);

      await pumpComponent(
        tester,
        _chips(completed: 1, current: 2),
        disableAnimations: true,
      );
      // The rule is not part of the crossfade: it is there at once.
      expect(find.byKey(ActiveExerciseSetChips.doneRuleKey), findsOneWidget);
      await tester.pump(ExomMotion.reducedFade);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byIcon(ExomIcons.check), findsOneWidget);
      expect(find.text('Ahora'), findsOneWidget);
    });

    testWidgets('contraste: con movimiento normal el fundido sigue a los '
        '120 ms (160 ms)', (tester) async {
      await pumpComponent(tester, _chips(completed: 0, current: 1));
      await pumpComponent(tester, _chips(completed: 1, current: 2));
      await tester.pump(ExomMotion.reducedFade);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Ahora'), findsNWidgets(2));
    });
  });

  group('CircuitRoundList con movimiento reducido', () {
    testWidgets('fundido de 120 ms, sin desplazamiento ni escala', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        _circuit(first: CircuitRowState.now),
        disableAnimations: true,
      );
      final switchers = tester.widgetList<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switchers, isNotEmpty);
      for (final s in switchers) {
        expect(s.duration, ExomMotion.reducedFade);
      }
      expect(_hasMovement(tester, find.byType(CircuitRoundList)), isFalse);
    });

    testWidgets('registrar un ejercicio: el check y el valor quedan en el '
        'árbol al acabar el fundido', (tester) async {
      await pumpComponent(
        tester,
        _circuit(first: CircuitRowState.now),
        disableAnimations: true,
      );
      expect(find.byIcon(ExomIcons.check), findsNothing);

      await pumpComponent(
        tester,
        _circuit(first: CircuitRowState.done),
        disableAnimations: true,
      );
      await tester.pump(ExomMotion.reducedFade);
      await tester.pump();
      expect(find.byIcon(ExomIcons.check), findsOneWidget);
      expect(find.text('8 reps'), findsOneWidget);
    });
  });
}
