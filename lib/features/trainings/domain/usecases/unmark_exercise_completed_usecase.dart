import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class UnmarkExerciseCompletedUseCase {
  final TrainingRepository _repository;

  const UnmarkExerciseCompletedUseCase(this._repository);

  Future<void> call(String trainingExerciseId, String date) =>
      _repository.unmarkExerciseCompleted(trainingExerciseId, date);
}
