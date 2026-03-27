import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

abstract class TrainingRepository {
  Future<TrainingEntity?> getTodayTraining({String? date});
  Future<List<TrainingEntity>> getTrainings({int page = 1, int limit = 20});
  Future<TrainingEntity> getTraining(String id);
  Future<void> markExerciseCompleted(String exerciseId, String date,
      {double? weightUsed});
  Future<void> unmarkExerciseCompleted(String exerciseId, String date);
  Future<void> completeTraining(String date, {String? notes});
  Future<({Set<String> ids, Map<String, double> weights})>
      getCompletedExerciseIds({String? date});
}
