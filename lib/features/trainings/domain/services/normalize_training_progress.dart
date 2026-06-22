import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

({Set<String> ids, Map<String, double> weights}) normalizeTrainingProgress({
  required TrainingEntity training,
  required Set<String> rawIds,
  required Map<String, double> rawWeights,
}) {
  final ids = <String>{};
  final weights = <String, double>{};

  for (final trainingExercise in training.exercises) {
    final trainingExerciseId = trainingExercise.id;
    final exerciseId = trainingExercise.exercise.id;
    if (!rawIds.contains(trainingExerciseId) && !rawIds.contains(exerciseId)) {
      continue;
    }

    ids.add(trainingExerciseId);
    final weight = rawWeights[trainingExerciseId] ?? rawWeights[exerciseId];
    if (weight != null) {
      weights[trainingExerciseId] = weight;
    }
  }

  return (ids: ids, weights: weights);
}
