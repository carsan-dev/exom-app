import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/metrics/data/models/body_metric_model.dart';

abstract class MetricsRemoteDataSource {
  Future<BodyMetricModel> saveMetric(Map<String, dynamic> data);
  Future<BodyMetricModel?> getLatestMetric();
  Future<List<BodyMetricModel>> getWeightHistory();
}

class MetricsRemoteDataSourceImpl implements MetricsRemoteDataSource {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  const MetricsRemoteDataSourceImpl(this._apiClient, this._localStorage);

  @override
  Future<BodyMetricModel> saveMetric(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post<dynamic>('/metrics', data: data);
    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw Exception('Invalid metric response');
    }

    final inner = payload['data'];
    if (inner is! Map<String, dynamic>) {
      throw Exception('Invalid metric response');
    }

    await _localStorage.cacheData('metrics_latest', inner);
    await _localStorage.cacheData('home_latest_metric', inner);

    final history = _localStorage.getCachedList('metrics_weight_history') ?? [];
    final updatedHistory = [
      inner,
      ...history.whereType<Map<String, dynamic>>(),
    ].toList();
    await _localStorage.cacheData('metrics_weight_history', updatedHistory);

    return BodyMetricModel.fromJson(inner);
  }

  @override
  Future<BodyMetricModel?> getLatestMetric() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/metrics/latest');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          await _localStorage.cacheData('metrics_latest', inner);
          await _localStorage.cacheData('home_latest_metric', inner);
          return BodyMetricModel.fromJson(inner);
        }
      }
      return null;
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedMap('metrics_latest');
        if (cached != null) {
          return BodyMetricModel.fromJson(cached);
        }
      }
      return null;
    }
  }

  @override
  Future<List<BodyMetricModel>> getWeightHistory() async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/metrics/weight-history',
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['data'];
        if (items is List) {
          final normalized = items
              .whereType<Map<String, dynamic>>()
              .map(Map<String, dynamic>.from)
              .toList(growable: false);
          await _localStorage.cacheData('metrics_weight_history', normalized);
          return normalized
              .map(BodyMetricModel.fromJson)
              .toList(growable: false);
        }
      }
      return [];
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedList('metrics_weight_history');
        if (cached != null) {
          return cached
              .whereType<Map<String, dynamic>>()
              .map(BodyMetricModel.fromJson)
              .toList(growable: false);
        }
      }
      return [];
    }
  }
}
