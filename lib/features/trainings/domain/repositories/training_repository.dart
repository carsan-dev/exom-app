import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

abstract class TrainingRepository {
  Future<TrainingEntity?> getTodayTraining({String? date});
  Future<List<TrainingHistoryEntity>> getTrainings({String? date});
  Future<TrainingEntity> getTraining(String id);
  Future<void> markExerciseCompleted(
    String trainingExerciseId,
    String exerciseId,
    String date, {
    double? weightUsed,
    List<SetPerformance>? sets,
  });
  Future<void> unmarkExerciseCompleted(String trainingExerciseId, String date);
  Future<void> completeTraining(String date, {String? notes});
  Future<({Set<String> ids, Map<String, double> weights})>
  getCompletedExerciseIds({String? date});
}
