import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/trainings/data/models/training_model.dart';

abstract class TrainingRemoteDataSource {
  Future<TrainingModel?> getTodayTraining();
  Future<List<TrainingModel>> getTrainings({int page = 1, int limit = 20});
  Future<TrainingModel> getTraining(String id);
  Future<void> markExerciseCompleted(String exerciseId, String date);
  Future<Set<String>> getCompletedExerciseIds();
}

class TrainingRemoteDataSourceImpl implements TrainingRemoteDataSource {
  final ApiClient _apiClient;

  const TrainingRemoteDataSourceImpl(this._apiClient);

  @override
  Future<TrainingModel?> getTodayTraining() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/trainings/today');
      if (response.statusCode == 204 || response.data == null) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          return TrainingModel.fromJson(inner);
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204 || e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<List<TrainingModel>> getTrainings({int page = 1, int limit = 20}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/trainings',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final items = data['data'];
      if (items is List) {
        return items
            .map((e) => TrainingModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<TrainingModel> getTraining(String id) async {
    final response = await _apiClient.dio.get<dynamic>('/trainings/$id');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return TrainingModel.fromJson(inner);
      }
    }
    throw Exception('Invalid response');
  }

  @override
  Future<void> markExerciseCompleted(String exerciseId, String date) async {
    await _apiClient.dio.post<dynamic>(
      '/progress/exercises/complete',
      data: {'exercise_id': exerciseId, 'date': date},
    );
  }

  @override
  Future<Set<String>> getCompletedExerciseIds() async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final response = await _apiClient.dio.get<dynamic>(
        '/progress',
        queryParameters: {'date': dateStr},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = (data['data'] as Map<String, dynamic>?) ?? data;
        final list = inner['exercises_completed'] as List? ?? [];
        return list
            .map((e) => (e as Map<String, dynamic>)['exercise_id'] as String)
            .toSet();
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}
