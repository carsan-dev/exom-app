import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class GetCompletedExercisesUseCase {
  final TrainingRepository _repository;

  const GetCompletedExercisesUseCase(this._repository);

  Future<Set<String>> call([String? date]) =>
      _repository.getCompletedExerciseIds(date: date);
}
