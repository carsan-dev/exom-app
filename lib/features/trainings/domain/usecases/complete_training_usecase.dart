import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class CompleteTrainingUseCase {
  final TrainingRepository _repository;

  const CompleteTrainingUseCase(this._repository);

  Future<void> call(String date, {String? notes}) =>
      _repository.completeTraining(date, notes: notes);
}
