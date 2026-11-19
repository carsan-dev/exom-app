import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

void main() {
  TrainingExerciseEntity exercise(String id, int sets) {
    return TrainingExerciseEntity(
      id: 'training-$id',
      order: 0,
      sets: sets,
      repsOrDuration: '10',
      restSeconds: 60,
      exercise: ExerciseEntity(id: id, name: id, muscleGroups: const []),
    );
  }

  test('weights remaining duration by pending sets', () {
    final training = TrainingEntity(
      id: 'training',
      name: 'Training',
      types: const [],
      level: 'MEDIUM',
      estimatedDurationMin: 60,
      tags: const [],
      exercises: [exercise('one', 2), exercise('two', 4)],
    );

    final remaining = training.remainingProgress({'training-one'});

    expect(remaining.remainingExercises, 1);
    expect(remaining.remainingSets, 4);
    expect(remaining.remainingDurationMin, 40);
  });

  test('returns zero when every exercise is complete', () {
    final training = TrainingEntity(
      id: 'training',
      name: 'Training',
      types: const [],
      level: 'MEDIUM',
      estimatedDurationMin: 45,
      tags: const [],
      exercises: [exercise('one', 3)],
    );

    final remaining = training.remainingProgress({'one'});

    expect(remaining.remainingExercises, 0);
    expect(remaining.remainingSets, 0);
    expect(remaining.remainingDurationMin, 0);
  });

  // L4b-D5: a circuit exercise weighs sets x rounds of its block. The API
  // stores sets: 1 per circuit exercise, and the circuit marks each exercise
  // completed only after its last round, so progress goes 0 -> N of N.
  group('session with a circuit', () {
    TrainingExerciseEntity circuitExercise(String id, {int? rounds = 3}) {
      return TrainingExerciseEntity(
        id: 'training-$id',
        order: 0,
        sets: 1,
        repsOrDuration: '10',
        restSeconds: 30,
        blockId: 'block-1',
        blockRounds: rounds,
        exercise: ExerciseEntity(id: id, name: id, muscleGroups: const []),
      );
    }

    TrainingEntity session() => TrainingEntity(
      id: 'training',
      name: 'Training',
      types: const [],
      level: 'MEDIUM',
      estimatedDurationMin: 50,
      tags: const [],
      exercises: [
        exercise('squat', 4),
        circuitExercise('burpee'),
        circuitExercise('row'),
      ],
    );

    test('nothing done: every round of the circuit is pending', () {
      final remaining = session().remainingProgress({});
      expect(remaining.remainingExercises, 3);
      expect(remaining.remainingSets, 10);
      expect(remaining.remainingDurationMin, 50);
    });

    test('partly done: a finished circuit exercise drops all its rounds', () {
      final remaining = session().remainingProgress({'training-burpee'});
      expect(remaining.remainingExercises, 2);
      expect(remaining.remainingSets, 7);
      expect(remaining.remainingDurationMin, 35);
    });

    test('all rounds done: progress reaches N of N', () {
      final remaining = session().remainingProgress({
        'training-squat',
        'training-burpee',
        'training-row',
      });
      expect(remaining.remainingExercises, 0);
      expect(remaining.remainingSets, 0);
      expect(remaining.remainingDurationMin, 0);
    });

    test('missing block rounds count the API default of 3', () {
      final training = TrainingEntity(
        id: 'training',
        name: 'Training',
        types: const [],
        level: 'MEDIUM',
        estimatedDurationMin: 30,
        tags: const [],
        exercises: [circuitExercise('burpee', rounds: null)],
      );
      expect(training.remainingProgress({}).remainingSets, 3);
    });
  });

  test('omits duration when training has no sets', () {
    final training = TrainingEntity(
      id: 'training',
      name: 'Training',
      types: const [],
      level: 'MEDIUM',
      estimatedDurationMin: 45,
      tags: const [],
      exercises: [exercise('one', 0)],
    );

    expect(training.remainingProgress({}).remainingDurationMin, isNull);
  });
}
