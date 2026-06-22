import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/normalize_training_progress.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingExerciseEntity _trainingExercise(String id, String exerciseId) {
  return TrainingExerciseEntity(
    id: id,
    order: 1,
    sets: 3,
    repsOrDuration: '10',
    restSeconds: 60,
    exercise: ExerciseEntity(
      id: exerciseId,
      name: exerciseId,
      muscleGroups: const [],
    ),
  );
}

void main() {
  final training = TrainingEntity(
    id: 'training-1',
    name: 'Fuerza',
    types: const [],
    level: 'INTERMEDIO',
    tags: const [],
    exercises: [
      _trainingExercise('training-exercise-1', 'exercise-1'),
      _trainingExercise('training-exercise-2', 'exercise-2'),
    ],
  );

  test('maps legacy exercise ids to training exercise ids', () {
    final result = normalizeTrainingProgress(
      training: training,
      rawIds: {'exercise-1', 'exercise-2'},
      rawWeights: {'exercise-1': 40},
    );

    expect(result.ids, {'training-exercise-1', 'training-exercise-2'});
    expect(result.weights, {'training-exercise-1': 40});
  });

  test('drops ids outside current training and avoids overcounting', () {
    final result = normalizeTrainingProgress(
      training: training,
      rawIds: {'exercise-1', 'training-exercise-1', 'unrelated-exercise'},
      rawWeights: const {},
    );

    expect(result.ids, {'training-exercise-1'});
    expect(result.ids.length, lessThanOrEqualTo(training.exercises.length));
  });
}
