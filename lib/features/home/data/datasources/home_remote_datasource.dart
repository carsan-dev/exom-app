import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/home/data/models/home_summary_model.dart';

abstract class HomeRemoteDataSource {
  Future<HomeSummaryModel> getHomeSummary();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _apiClient;

  const HomeRemoteDataSourceImpl(this._apiClient);

  @override
  Future<HomeSummaryModel> getHomeSummary() async {
    final results = await Future.wait([
      _getTrainingToday(),
      _getDietToday(),
      _getStreak(),
    ]);

    return HomeSummaryModel.fromParts(
      training: results[0] as Map<String, dynamic>?,
      diet: results[1] as Map<String, dynamic>?,
      streak: results[2] as Map<String, dynamic>?,
    );
  }

  Future<Map<String, dynamic>?> _getTrainingToday() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/trainings/today');
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

  Future<Map<String, dynamic>?> _getDietToday() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/diets/today');
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
}
