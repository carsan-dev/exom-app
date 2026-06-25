import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

class GetCompletedExercisesUseCase {
  final TrainingRepository _repository;

  const GetCompletedExercisesUseCase(this._repository);

  Future<CompletedExerciseProgress> call([String? date]) =>
      _repository.getCompletedExerciseIds(date: date);
}
