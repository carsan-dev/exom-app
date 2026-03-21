import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';

abstract class MetricsRepository {
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data);
  Future<BodyMetricEntity?> getLatestMetric();
  Future<List<BodyMetricEntity>> getWeightHistory();
}
