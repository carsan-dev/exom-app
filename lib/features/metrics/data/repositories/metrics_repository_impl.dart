import 'package:exom_app/features/metrics/data/datasources/metrics_remote_datasource.dart';
import 'package:exom_app/features/metrics/data/models/body_metric_model.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';

class MetricsRepositoryImpl implements MetricsRepository {
  final MetricsRemoteDataSource _remoteDataSource;

  const MetricsRepositoryImpl(this._remoteDataSource);

  @override
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data) async {
    final model = await _remoteDataSource.saveMetric(data);
    return _mapToEntity(model);
  }

  @override
  Future<BodyMetricEntity?> getLatestMetric() async {
    final model = await _remoteDataSource.getLatestMetric();
    if (model == null) return null;
    return _mapToEntity(model);
  }

  @override
  Future<List<BodyMetricEntity>> getWeightHistory() async {
    final models = await _remoteDataSource.getWeightHistory();
    return models.map(_mapToEntity).toList();
  }

  BodyMetricEntity _mapToEntity(BodyMetricModel model) {
    return BodyMetricEntity(
      id: model.id,
      date: model.date,
      weightKg: model.weightKg,
      muscleMassKg: model.muscleMassKg,
      sleepHours: model.sleepHours,
      neckCm: model.neckCm,
      shouldersCm: model.shouldersCm,
      chestCm: model.chestCm,
      armCm: model.armCm,
      forearmCm: model.forearmCm,
      waistCm: model.waistCm,
      hipsCm: model.hipsCm,
      thighCm: model.thighCm,
      calfCm: model.calfCm,
    );
  }
}
