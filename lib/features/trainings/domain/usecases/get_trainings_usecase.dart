import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class GetTrainingsUseCase {
  final TrainingRepository _repository;

  const GetTrainingsUseCase(this._repository);

  Future<List<TrainingHistoryEntity>> call({String? date}) =>
      _repository.getTrainings(date: date);
}
