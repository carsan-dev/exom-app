import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class GetTrainingUseCase {
  final TrainingRepository _repository;

  const GetTrainingUseCase(this._repository);

  Future<TrainingEntity> call(String id) => _repository.getTraining(id);
}
