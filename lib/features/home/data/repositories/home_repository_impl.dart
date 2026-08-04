import 'package:exom_app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  const HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<HomeSummaryEntity> getHomeSummary({DateTime? date}) async {
    final model = await _remoteDataSource.getHomeSummary(date: date);
    return HomeSummaryEntity(
      trainingId: model.trainingId,
      trainingName: model.trainingName,
      trainingTypes: model.trainingTypes,
      trainingAccentColor: model.trainingAccentColor,
      trainingDurationMin: model.trainingDurationMin,
      remainingTrainingDurationMin: model.remainingTrainingDurationMin,
      trainingCompleted: model.trainingCompleted,
      trainings: model.trainings
          .map(
            (training) => HomeTrainingItemEntity(
              id: training.id,
              name: training.name,
              completed: training.completed,
            ),
          )
          .toList(growable: false),
      exercisesCompleted: model.exercisesCompleted,
      totalExercises: model.totalExercises,
      dietId: model.dietId,
      dietName: model.dietName,
      nextMealId: model.nextMealId,
      nextMealName: model.nextMealName,
      totalCalories: model.totalCalories,
      remainingCalories: model.remainingCalories,
      mealsCompleted: model.mealsCompleted,
      totalMeals: model.totalMeals,
      isRestDay: model.isRestDay,
      streakDays: model.streakDays,
      clientName: model.clientName,
      avatarUrl: model.avatarUrl,
      lastWeightKg: model.lastWeightKg,
      lastWeightDate: model.lastWeightDate,
      lastSleepHours: model.lastSleepHours,
    );
  }
}
