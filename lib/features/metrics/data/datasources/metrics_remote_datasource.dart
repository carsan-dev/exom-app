import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/metrics/data/models/body_metric_model.dart';

abstract class MetricsRemoteDataSource {
  Future<BodyMetricModel> saveMetric(Map<String, dynamic> data);
  Future<BodyMetricModel?> getLatestMetric();
  Future<List<BodyMetricModel>> getWeightHistory();
}

class MetricsRemoteDataSourceImpl implements MetricsRemoteDataSource {
  final ApiClient _apiClient;

  const MetricsRemoteDataSourceImpl(this._apiClient);

  @override
  Future<BodyMetricModel> saveMetric(Map<String, dynamic> data) async {
    return await _apiClient.post<BodyMetricModel>(
      '/metrics',
      data: data,
      fromJson: BodyMetricModel.fromJson,
    );
  }

  @override
  Future<BodyMetricModel?> getLatestMetric() async {
    try {
      return await _apiClient.get<BodyMetricModel>(
        '/metrics/latest',
        fromJson: BodyMetricModel.fromJson,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BodyMetricModel>> getWeightHistory() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/metrics/weight-history');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['data'];
        if (items is List) {
          return items
              .map((e) => BodyMetricModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
