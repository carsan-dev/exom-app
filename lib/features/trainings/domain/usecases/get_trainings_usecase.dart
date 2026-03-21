import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class GetTrainingsUseCase {
  final TrainingRepository _repository;

  const GetTrainingsUseCase(this._repository);

  Future<List<TrainingEntity>> call({int page = 1, int limit = 20}) =>
      _repository.getTrainings(page: page, limit: limit);
}
