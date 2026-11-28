import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';

abstract class MetricsRepository {
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data);
  Future<BodyMetricEntity?> getLatestMetric({String? date});
  Future<List<BodyMetricEntity>> getWeightHistory();
}

/// A value read for the «Progreso» view and where it came from.
class MetricsRead<T> {
  final T value;

  /// True when the network was unreachable and [value] is the offline cache
  /// copy; false when it is the server's answer.
  final bool fromCache;

  const MetricsRead(this.value, {this.fromCache = false});
}

/// The «Progreso» reads with their origin. Same answers, caching and errors as
/// [MetricsRepository.getWeightHistory] and [MetricsRepository.getLatestMetric]
/// (latest of all time, no date); they only add [MetricsRead.fromCache].
///
/// Separate from [MetricsRepository] so that its other implementations keep
/// compiling and behaving as before: a repository without this capability is
/// read as the network.
abstract interface class MetricsHistorySource {
  Future<MetricsRead<List<BodyMetricEntity>>> getWeightHistoryWithSource();
  Future<MetricsRead<BodyMetricEntity?>> getLatestMetricWithSource();
}
