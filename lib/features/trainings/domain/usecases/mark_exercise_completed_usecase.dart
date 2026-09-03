import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

class MarkExerciseCompletedUseCase {
  final TrainingRepository _repository;

  const MarkExerciseCompletedUseCase(this._repository);

  Future<void> call(
    String trainingExerciseId,
    String exerciseId,
    String date, {
    double? weightUsed,
    List<SetPerformance>? sets,
    String? lastSetFeedbackClientUploadId,
    String? trainingId,
  }) => _repository.markExerciseCompleted(
    trainingExerciseId,
    exerciseId,
    date,
    weightUsed: weightUsed,
    sets: sets,
    lastSetFeedbackClientUploadId: lastSetFeedbackClientUploadId,
    trainingId: trainingId,
  );
}
