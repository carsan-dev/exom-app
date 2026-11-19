// Regressions of the three defects found in the pre-L3 active circuit page
// (L3 unit 4 brief, F1-F3). Written before the fix and run against the
// released page first: every test here failed on b033b6a's
// active_circuit_page.dart. They only use finders that exist before and
// after the redesign (Keys, l10n strings of the exit dialog, cache writes).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'circuit_test_harness.dart';

void main() {
  final a = circuitExercise('a', 'Burpees', restSeconds: 30);
  final b = circuitExercise('b', 'Sentadilla con salto', restSeconds: 20);

  testWidgets('F1: a one-exercise circuit with rest reaches its final rest '
      'without a RangeError', (tester) async {
    final end = DateTime.now().add(const Duration(seconds: 30));
    await pumpCircuit(
      tester,
      exercises: [a],
      rounds: 2,
      restored: preL3State(
        round: 2,
        exerciseIndex: 0,
        status: 'finalResting',
        restEndsAt: end,
        performances: {
          'a': [
            {'set_number': 1, 'reps': 12},
            {'set_number': 2, 'reps': 12},
          ],
        },
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(ValueKey('round-rest-${end.millisecondsSinceEpoch}')),
      findsOneWidget,
    );
  });

  Future<String> exitMessage(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settleFrames(tester);
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final l10n = circuitL10n(tester);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text(l10n.activeExerciseCloseTitle),
      ),
      findsOneWidget,
    );
    final texts = tester
        .widgetList<Text>(find.descendant(of: dialog, matching: find.byType(Text)))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    return texts.firstWhere((text) => text != l10n.activeExerciseCloseTitle);
  }

  for (final (name, state, completed) in [
    (
      'round rest after round 1',
      preL3State(
        round: 1,
        exerciseIndex: 1,
        status: 'roundResting',
        restEndsAt: DateTime.now().add(const Duration(minutes: 5)),
      ),
      2,
    ),
    (
      'executing the second exercise of round 2',
      preL3State(round: 2, exerciseIndex: 1),
      3,
    ),
    (
      'final rest',
      preL3State(
        round: 2,
        exerciseIndex: 1,
        status: 'finalResting',
        restEndsAt: DateTime.now().add(const Duration(minutes: 5)),
      ),
      4,
    ),
    (
      'ready to finish',
      preL3State(round: 2, exerciseIndex: 1, readyToFinish: true),
      4,
    ),
  ]) {
    testWidgets('F2: the exit message counts $completed of 4 sets done '
        '($name)', (tester) async {
      await pumpCircuit(
        tester,
        exercises: [a, b],
        rounds: 2,
        restBetweenRounds: 60,
        restored: state,
      );
      final l10n = circuitL10n(tester);
      expect(
        await exitMessage(tester),
        l10n.activeExerciseCloseMessage(completed, 4),
      );
    });
  }

  testWidgets('F3: a failed finish after the final rest leaves a retry '
      '(ready to finish), not a rest footer stuck at 0 s', (tester) async {
    final end = DateTime.now().subtract(const Duration(seconds: 5));
    final restored = preL3State(
      round: 2,
      exerciseIndex: 1,
      status: 'finalResting',
      restEndsAt: end,
      performances: {
        'a': [
          {'set_number': 1, 'reps': 12},
          {'set_number': 2, 'reps': 12},
        ],
        'b': [
          {'set_number': 1, 'reps': 10},
          {'set_number': 2, 'reps': 10},
        ],
      },
    );
    var failures = 0;
    final h = await pumpCircuit(
      tester,
      exercises: [a, b],
      rounds: 2,
      restored: restored,
      // The first dispatch of 'b' fails (e.g. a 409 from syncForDate).
      failWhen: (event) => event.trainingExerciseId == 'b' && failures++ == 0,
    );
    await settleFrames(tester);

    expect(
      find.byKey(ValueKey('round-rest-${end.millisecondsSinceEpoch}')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('circuit-executing-footer')),
      findsOneWidget,
    );
    expect(h.storage.lastWrite['status'], 'executing');
    expect(h.storage.lastWrite['ready_to_finish'], isTrue);
    expect(h.storage.lastWrite['rest_ends_at'], isNull);
  });
}
