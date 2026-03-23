import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/diets/data/models/diet_model.dart';

abstract class DietRemoteDataSource {
  Future<DietModel?> getTodayDiet();
  Future<MealModel> getMeal(String mealId);
  Future<void> markMealCompleted(String mealId, String date);
  Future<void> unmarkMealCompleted(String mealId, String date);
  Future<Set<String>> getCompletedMealIds();
}

class DietRemoteDataSourceImpl implements DietRemoteDataSource {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  static const _emptyMarker = '__empty__';

  const DietRemoteDataSourceImpl(this._apiClient, this._localStorage);

  String _todayDate() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  Future<void> _cacheNullableMap(
    String key,
    Map<String, dynamic>? value,
  ) async {
    await _localStorage.cacheData(key, value ?? {_emptyMarker: true});
  }

  Map<String, dynamic>? _getCachedNullableMap(String key) {
    final cached = _localStorage.getCachedMap(key);
    if (cached == null) {
      return null;
    }
    if (cached[_emptyMarker] == true) {
      return null;
    }
    return cached;
  }

  Future<void> _cacheProgressResponse(
    Response<dynamic> response,
    String date,
  ) async {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final inner = (data['data'] as Map<String, dynamic>?) ?? data;
      await _localStorage.cacheData('day_progress_$date', inner);
      await _localStorage.cacheData('home_progress_$date', inner);
      await _localStorage.cacheData(
        'completed_meals_$date',
        (inner['meals_completed'] as List? ?? [])
            .map((entry) => entry.toString())
            .toList(growable: false),
      );
    }
  }

  @override
  Future<DietModel?> getTodayDiet() async {
    final cacheKey = 'diet_today_${_todayDate()}';

    try {
      final response = await _apiClient.dio.get<dynamic>('/diets/today');
      if (response.statusCode == 204 || response.data == null) {
        await _cacheNullableMap(cacheKey, null);
        return null;
      }
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          await _cacheNullableMap(cacheKey, inner);
          return DietModel.fromJson(inner);
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204 || e.response?.statusCode == 404) {
        await _cacheNullableMap(cacheKey, null);
        return null;
      }

      if (isOfflineError(e)) {
        final cached = _getCachedNullableMap(cacheKey);
        if (cached != null) {
          return DietModel.fromJson(cached);
        }
      }

      rethrow;
    }
  }

  @override
  Future<MealModel> getMeal(String mealId) async {
    final cacheKey = 'meal_detail_$mealId';

    try {
      final response = await _apiClient.dio.get<dynamic>('/meals/$mealId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          await _localStorage.cacheData(cacheKey, inner);
          return MealModel.fromJson(inner);
        }
      }
      throw Exception('Invalid response');
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedMap(cacheKey);
        if (cached != null) {
          return MealModel.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> markMealCompleted(String mealId, String date) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/progress/meals/complete',
      data: {'meal_id': mealId, 'date': date},
    );
    await _cacheProgressResponse(response, date);
  }

  @override
  Future<void> unmarkMealCompleted(String mealId, String date) async {
    final response = await _apiClient.dio.delete<dynamic>(
      '/progress/meals/$mealId',
      queryParameters: {'date': date},
    );
    await _cacheProgressResponse(response, date);
  }

  @override
  Future<Set<String>> getCompletedMealIds() async {
    final date = _todayDate();
    final cacheKey = 'completed_meals_$date';

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/progress',
        queryParameters: {'date': date},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = (data['data'] as Map<String, dynamic>?) ?? data;
        final list = inner['meals_completed'] as List? ?? [];
        final completedIds = list
            .map((entry) => entry.toString())
            .toList(growable: false);
        await _localStorage.cacheData(cacheKey, completedIds);
        await _localStorage.cacheData('day_progress_$date', inner);
        await _localStorage.cacheData('home_progress_$date', inner);
        return completedIds.toSet();
      }
      return {};
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedList(cacheKey);
        if (cached != null) {
          return cached.map((entry) => entry.toString()).toSet();
        }
      }
      return {};
    }
  }
}
