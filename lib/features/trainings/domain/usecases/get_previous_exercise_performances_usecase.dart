import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class GetPreviousExercisePerformancesUseCase {
  final TrainingRepository _repository;

  const GetPreviousExercisePerformancesUseCase(this._repository);

  Future<Map<String, List<SetPerformance>>> call(
    List<String> exerciseIds,
    String beforeDate,
  ) {
    return _repository.getPreviousExercisePerformances(exerciseIds, beforeDate);
  }
}
