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
  Future<List<TrainingEntity>> getTrainings({
    int page = 1,
    int limit = 20,
  }) async {
    final models = await _remoteDataSource.getTrainings(
      page: page,
      limit: limit,
    );
    return models.map(_mapToEntity).toList();
  }

  @override
  Future<TrainingEntity> getTraining(String id) async {
    final model = await _remoteDataSource.getTraining(id);
    return _mapToEntity(model);
  }

  @override
  Future<void> markExerciseCompleted(String exerciseId, String date,
      {double? weightUsed}) {
    return _remoteDataSource.markExerciseCompleted(exerciseId, date,
        weightUsed: weightUsed);
  }

  @override
  Future<void> unmarkExerciseCompleted(String exerciseId, String date) {
    return _remoteDataSource.unmarkExerciseCompleted(exerciseId, date);
  }

  @override
  Future<void> completeTraining(String date, {String? notes}) {
    return _remoteDataSource.completeTraining(date, notes: notes);
  }

  @override
  Future<({Set<String> ids, Map<String, double> weights})>
      getCompletedExerciseIds({String? date}) {
    return _remoteDataSource.getCompletedExerciseIds(date: date);
  }

  TrainingEntity _mapToEntity(TrainingModel model) {
    return TrainingEntity(
      id: model.id,
      name: model.name,
      type: model.type,
      level: model.level,
      estimatedDurationMin: model.estimatedDurationMin,
      estimatedCalories: model.estimatedCalories,
      warmupDescription: model.warmupDescription,
      cooldownDescription: model.cooldownDescription,
      tags: model.tags,
      exercises: model.exercises.map(_mapExerciseToEntity).toList(),
    );
  }

  TrainingExerciseEntity _mapExerciseToEntity(TrainingExerciseModel model) {
    return TrainingExerciseEntity(
      id: model.id,
      order: model.order,
      sets: model.sets,
      repsOrDuration: model.repsOrDuration,
      restSeconds: model.restSeconds,
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
}
