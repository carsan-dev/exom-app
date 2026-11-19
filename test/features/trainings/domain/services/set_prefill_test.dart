import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/set_prefill.dart';
import 'package:flutter_test/flutter_test.dart';

// Decision D4 (owner, 2026-11-18): weight prefill = today's value for this set
// -> last weight this session (which already starts at initialWeightKg) ->
// previous session's same set -> previous session's last weighted set -> empty.

void main() {
  const previous = [
    SetPerformance(setNumber: 1, reps: 8, weightKg: 60, rir: 2),
    SetPerformance(setNumber: 2, reps: 8, weightKg: 62.5, rir: 2),
    SetPerformance(setNumber: 3, reps: 6),
  ];

  group('prefillWeightKg', () {
    test("today's set wins over everything", () {
      expect(
        prefillWeightKg(
          today: const SetPerformance(setNumber: 2, reps: 8, weightKg: 70),
          sessionWeightKg: 65,
          previous: previous,
          setNumber: 2,
        ),
        70,
      );
    });

    test('then the last weight of this session (or initialWeightKg)', () {
      expect(
        prefillWeightKg(
          today: const SetPerformance(setNumber: 2, reps: 8),
          sessionWeightKg: 65,
          previous: previous,
          setNumber: 2,
        ),
        65,
      );
    });

    test('then the same set of the previous session', () {
      expect(
        prefillWeightKg(
          today: null,
          sessionWeightKg: null,
          previous: previous,
          setNumber: 2,
        ),
        62.5,
      );
    });

    test('then the last weighted set of the previous session', () {
      // Set 3 has no weight; set 4 does not exist.
      expect(
        prefillWeightKg(
          today: null,
          sessionWeightKg: null,
          previous: previous,
          setNumber: 3,
        ),
        62.5,
      );
      expect(
        prefillWeightKg(
          today: null,
          sessionWeightKg: null,
          previous: previous,
          setNumber: 4,
        ),
        62.5,
      );
    });

    test('empty without any source', () {
      expect(
        prefillWeightKg(
          today: null,
          sessionWeightKg: null,
          previous: const [],
          setNumber: 1,
        ),
        isNull,
      );
      expect(
        prefillWeightKg(
          today: null,
          sessionWeightKg: null,
          previous: null,
          setNumber: 1,
        ),
        isNull,
      );
    });

    test('returns the stored double untouched (no rounding)', () {
      expect(
        prefillWeightKg(
          today: null,
          sessionWeightKg: 61.235,
          previous: null,
          setNumber: 1,
        ),
        61.235,
      );
    });
  });

  group('prefillCount', () {
    test("reps: today's set, then this execution, then previous, then target",
        () {
      expect(
        prefillCount(
          today: const SetPerformance(setNumber: 2, reps: 9),
          lastThisExecution: const SetPerformance(setNumber: 1, reps: 7),
          previousSameSet: const SetPerformance(setNumber: 2, reps: 8),
          target: 10,
          timed: false,
        ),
        9,
      );
      expect(
        prefillCount(
          today: null,
          lastThisExecution: const SetPerformance(setNumber: 1, reps: 7),
          previousSameSet: const SetPerformance(setNumber: 2, reps: 8),
          target: 10,
          timed: false,
        ),
        7,
      );
      expect(
        prefillCount(
          today: null,
          lastThisExecution: null,
          previousSameSet: const SetPerformance(setNumber: 2, reps: 8),
          target: 10,
          timed: false,
        ),
        8,
      );
      expect(
        prefillCount(
          today: null,
          lastThisExecution: null,
          previousSameSet: null,
          target: 10,
          timed: false,
        ),
        10,
      );
      expect(
        prefillCount(
          today: null,
          lastThisExecution: null,
          previousSameSet: null,
          target: null,
          timed: false,
        ),
        isNull,
      );
    });

    test('seconds read the seconds of each source', () {
      expect(
        prefillCount(
          today: null,
          lastThisExecution: const SetPerformance(setNumber: 1, reps: 7),
          previousSameSet: const SetPerformance(setNumber: 1, seconds: 40),
          target: 45,
          timed: true,
        ),
        40,
      );
    });
  });

  group('prefillRir', () {
    test('a new set preselects the prescription target', () {
      expect(prefillRir(today: null, targetRir: 2), 2);
      expect(prefillRir(today: null, targetRir: null), isNull);
    });

    test('a set already logged today shows its stored value', () {
      expect(
        prefillRir(
          today: const SetPerformance(setNumber: 1, reps: 8, rir: 8),
          targetRir: 2,
        ),
        8,
      );
      expect(
        prefillRir(
          today: const SetPerformance(setNumber: 1, reps: 8),
          targetRir: 2,
        ),
        isNull,
      );
    });
  });

  group('rirChipFor', () {
    test('values above 5 are shown as 5+', () {
      expect(rirChipFor(null), isNull);
      expect(rirChipFor(0), 0);
      expect(rirChipFor(4), 4);
      expect(rirChipFor(5), 5);
      expect(rirChipFor(8), 5);
    });
  });
}
