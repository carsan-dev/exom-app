import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class MarkExerciseCompletedUseCase {
  final TrainingRepository _repository;

  const MarkExerciseCompletedUseCase(this._repository);

  Future<void> call(
    String trainingExerciseId,
    String exerciseId,
    String date, {
    double? weightUsed,
  }) => _repository.markExerciseCompleted(
    trainingExerciseId,
    exerciseId,
    date,
    weightUsed: weightUsed,
  );
}
