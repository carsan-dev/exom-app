import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class CompleteTrainingUseCase {
  final TrainingRepository _repository;

  const CompleteTrainingUseCase(this._repository);

  Future<void> call(String date, {required String trainingId, String? notes}) =>
      _repository.completeTraining(date, trainingId: trainingId, notes: notes);
}
