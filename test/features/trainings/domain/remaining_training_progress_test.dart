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
