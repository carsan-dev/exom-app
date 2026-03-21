import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class GetTodayTrainingUseCase {
  final TrainingRepository _repository;

  const GetTodayTrainingUseCase(this._repository);

  Future<TrainingEntity?> call() => _repository.getTodayTraining();
}
