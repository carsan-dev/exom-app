// L4b-D5: one rule for the sets of a session. A standalone exercise counts
// its own sets; an exercise of a circuit block counts sets x rounds of the
// block (the API stores sets: 1 per circuit exercise and the rounds on the
// block, 3 by default).
import 'package:exom_app/features/trainings/domain/planned_sets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plannedSetsOf', () {
    test('a standalone exercise counts its sets', () {
      expect(plannedSetsOf(sets: 4, inBlock: false), 4);
      // Rounds of a block never apply to an exercise outside it.
      expect(plannedSetsOf(sets: 4, inBlock: false, blockRounds: 5), 4);
    });

    test('a circuit exercise counts sets x rounds', () {
      expect(plannedSetsOf(sets: 1, inBlock: true, blockRounds: 4), 4);
      expect(plannedSetsOf(sets: 2, inBlock: true, blockRounds: 3), 6);
    });

    test('missing rounds fall back to the API default of 3', () {
      expect(defaultBlockRounds, 3);
      expect(plannedSetsOf(sets: 1, inBlock: true), 3);
    });

    test('rounds below 1 count as one round', () {
      expect(plannedSetsOf(sets: 2, inBlock: true, blockRounds: 0), 2);
      expect(plannedSetsOf(sets: 2, inBlock: true, blockRounds: -2), 2);
    });
  });

  group('tallyPlannedSets', () {
    ({int sets, bool inBlock, int? rounds, bool done}) item(
      int sets, {
      bool inBlock = false,
      int? rounds,
      bool done = false,
    }) => (sets: sets, inBlock: inBlock, rounds: rounds, done: done);

    PlannedSetsTally tally(
      List<({int sets, bool inBlock, int? rounds, bool done})> items,
    ) => tallyPlannedSets(
      items,
      plannedSets: (e) => plannedSetsOf(
        sets: e.sets,
        inBlock: e.inBlock,
        blockRounds: e.rounds,
      ),
      isCompleted: (e) => e.done,
    );

    test('standalone exercises add their sets', () {
      final result = tally([item(3), item(4, done: true)]);
      expect(result.total, 7);
      expect(result.completed, 4);
      expect(result.remaining, 3);
    });

    test('a circuit with rounds counts every round', () {
      final result = tally([
        item(1, inBlock: true, rounds: 4),
        item(1, inBlock: true, rounds: 4),
      ]);
      expect(result.total, 8);
      expect(result.remaining, 8);
    });

    test('mixed session: standalone sets plus circuit sets x rounds', () {
      final result = tally([
        item(4),
        item(1, inBlock: true, rounds: 3, done: true),
        item(1, inBlock: true, rounds: 3),
      ]);
      expect(result.total, 10);
      expect(result.completed, 3);
      expect(result.remaining, 7);
    });

    test('missing rounds count 3 per circuit exercise', () {
      expect(tally([item(1, inBlock: true)]).total, 3);
    });

    test('an empty list has no sets and no remaining minutes', () {
      final result = tally(const []);
      expect(result.total, 0);
      expect(result.remaining, 0);
      expect(result.remainingMinutes(45), isNull);
    });

    test('remaining minutes are prorated by remaining sets', () {
      final result = tally([item(2, done: true), item(4)]);
      expect(result.remainingMinutes(60), 40);
      expect(result.remainingMinutes(null), isNull);
    });
  });
}
