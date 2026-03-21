import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';

class SaveMetricUseCase {
  final MetricsRepository _repository;

  const SaveMetricUseCase(this._repository);

  Future<BodyMetricEntity> call(Map<String, dynamic> data) =>
      _repository.saveMetric(data);
}
