import 'package:exom_app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  const HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<HomeSummaryEntity> getHomeSummary() async {
    final model = await _remoteDataSource.getHomeSummary();
    return HomeSummaryEntity(
      trainingId: model.trainingId,
      trainingName: model.trainingName,
      trainingType: model.trainingType,
      trainingDurationMin: model.trainingDurationMin,
      trainingCompleted: model.trainingCompleted,
      dietId: model.dietId,
      dietName: model.dietName,
      totalCalories: model.totalCalories,
      isRestDay: model.isRestDay,
      streakDays: model.streakDays,
      clientName: model.clientName,
      avatarUrl: model.avatarUrl,
    );
  }
}
