import 'package:exom_app/features/trainings/data/datasources/training_remote_datasource.dart';
import 'package:exom_app/features/trainings/data/models/training_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';

class TrainingRepositoryImpl implements TrainingRepository {
  final TrainingRemoteDataSource _remoteDataSource;

  const TrainingRepositoryImpl(this._remoteDataSource);

  @override
  Future<TrainingEntity?> getTodayTraining({String? date}) async {
    final model = await _remoteDataSource.getTodayTraining(date: date);
    if (model == null) return null;
    return _mapToEntity(model);
  }

  @override
  Future<List<TrainingEntity>> getDayTrainings({String? date}) async {
    final models = await _remoteDataSource.getDayTrainings(date: date);
    return models.map(_mapToEntity).toList(growable: false);
  }

  @override
  Future<List<TrainingHistoryEntity>> getTrainings({String? date}) async {
    final models = await _remoteDataSource.getTrainings(date: date);
    return models.map(_mapHistoryToEntity).toList();
  }

  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async {
    final model = await _remoteDataSource.getTraining(id, date: date);
    return _mapToEntity(model);
  }

  @override
  Future<void> markExerciseCompleted(
    String trainingExerciseId,
    String exerciseId,
    String date, {
    double? weightUsed,
    List<SetPerformance>? sets,
    String? lastSetFeedbackClientUploadId,
    String? trainingId,
  }) {
    return _remoteDataSource.markExerciseCompleted(
      trainingExerciseId,
      exerciseId,
      date,
      weightUsed: weightUsed,
      sets: sets,
      lastSetFeedbackClientUploadId: lastSetFeedbackClientUploadId,
      trainingId: trainingId,
    );
  }

  @override
  Future<void> unmarkExerciseCompleted(String trainingExerciseId, String date) {
    return _remoteDataSource.unmarkExerciseCompleted(trainingExerciseId, date);
  }

  @override
  Future<void> completeTraining(
    String date, {
    required String trainingId,
    String? notes,
  }) {
    return _remoteDataSource.completeTraining(
      date,
      trainingId: trainingId,
      notes: notes,
    );
  }

  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) {
    return _remoteDataSource.getCompletedExerciseIds(date: date);
  }

  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) {
    return _remoteDataSource.getPreviousExercisePerformances(
      exerciseIds,
      beforeDate,
    );
  }

  TrainingEntity _mapToEntity(TrainingModel model) {
    return TrainingEntity(
      id: model.id,
      name: model.name,
      types: model.types,
      accentColor: model.accentColor,
      level: model.level,
      estimatedDurationMin: model.estimatedDurationMin,
      estimatedCalories: model.estimatedCalories,
      warmupDescription: model.warmupDescription,
      cooldownDescription: model.cooldownDescription,
      tags: model.tags,
      exercises: model.exercises.map(_mapExerciseToEntity).toList(),
      assignmentTrainingId: model.assignmentTrainingId,
      assignmentDate: model.assignmentDate,
      requiresLastSetVideo: model.requiresLastSetVideo,
    );
  }

  TrainingExerciseEntity _mapExerciseToEntity(TrainingExerciseModel model) {
    return TrainingExerciseEntity(
      id: model.id,
      order: model.order,
      sets: model.sets,
      repsOrDuration: model.repsOrDuration,
      measureType: model.measureType,
      targetValue: model.targetValue,
      targetRir: model.targetRir,
      restSeconds: model.restSeconds,
      requestSetTracking: model.requestSetTracking,
      blockId: model.blockId,
      positionInBlock: model.positionInBlock,
      blockName: model.blockName,
      blockOrder: model.blockOrder,
      blockRounds: model.blockRounds,
      restBetweenRoundsSeconds: model.restBetweenRoundsSeconds,
      exercise: ExerciseEntity(
        id: model.exercise.id,
        name: model.exercise.name,
        muscleGroups: model.exercise.muscleGroups,
        videoUrl: model.exercise.videoUrl,
        thumbnailUrl: model.exercise.thumbnailUrl,
        techniqueText: model.exercise.techniqueText,
        commonErrorsText: model.exercise.commonErrorsText,
        explanationText: model.exercise.explanationText,
      ),
    );
  }

  TrainingHistoryEntity _mapHistoryToEntity(TrainingHistoryModel model) {
    return TrainingHistoryEntity(
      id: model.id,
      name: model.name,
      types: model.types,
      accentColor: model.accentColor,
      level: model.level,
      estimatedDurationMin: model.estimatedDurationMin,
      estimatedCalories: model.estimatedCalories,
      date: model.date,
      isCompleted: model.isCompleted,
    );
  }
}
