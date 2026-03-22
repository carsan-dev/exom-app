import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/home/data/models/home_summary_model.dart';

abstract class HomeRemoteDataSource {
  Future<HomeSummaryModel> getHomeSummary({DateTime? date});
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _apiClient;

  const HomeRemoteDataSourceImpl(this._apiClient);

  @override
  Future<HomeSummaryModel> getHomeSummary({DateTime? date}) async {
    final results = await Future.wait([
      _getTrainingToday(date: date),
      _getDietToday(date: date),
      _getStreak(),
      _getProfile(),
      _getLatestMetric(),
      _getDayProgress(date: date),
    ]);

    return HomeSummaryModel.fromParts(
      training: results[0] as Map<String, dynamic>?,
      diet: results[1] as Map<String, dynamic>?,
      streak: results[2] as Map<String, dynamic>?,
      profile: results[3] as Map<String, dynamic>?,
      latestMetric: results[4] as Map<String, dynamic>?,
      progress: results[5] as Map<String, dynamic>?,
    );
  }

  Future<Map<String, dynamic>?> _getTrainingToday({DateTime? date}) async {
    try {
      final queryParams = date != null
          ? {'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'}
          : null;
      final response = await _apiClient.dio.get<dynamic>(
        '/trainings/today',
        queryParameters: queryParams,
      );
      if (response.statusCode == 204 || response.data == null) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204 || e.response?.statusCode == 404) {
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getDietToday({DateTime? date}) async {
    try {
      final queryParams = date != null
          ? {'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'}
          : null;
      final response = await _apiClient.dio.get<dynamic>(
        '/diets/today',
        queryParameters: queryParams,
      );
      if (response.statusCode == 204 || response.data == null) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204 || e.response?.statusCode == 404) {
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getStreak() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/streaks/me');
      if (response.data == null) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getProfile() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/profile/me');
      if (response.data == null) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getLatestMetric() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/metrics/latest');
      if (response.data == null) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getDayProgress({DateTime? date}) async {
    try {
      final target = date ?? DateTime.now();
      final dateStr =
          '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
      final response = await _apiClient.dio.get<dynamic>(
        '/progress',
        queryParameters: {'date': dateStr},
      );
      if (response.data == null) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return (data['data'] as Map<String, dynamic>?) ?? data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
