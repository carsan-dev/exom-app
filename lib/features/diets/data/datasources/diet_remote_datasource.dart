import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/services/pending_progress_overlay.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/diets/data/models/diet_model.dart';
import 'package:exom_app/features/diets/data/models/weekly_diet_model.dart';
import 'package:exom_app/features/diets/data/models/monthly_diet_model.dart';

abstract class DietRemoteDataSource {
  Future<DietModel?> getTodayDiet({String? date});
  Future<WeeklyDietModel> getWeeklyDiet(String weekStart);
  Future<MonthlyDietModel> getMonthlyDiet(int year, int month);
  Future<MealModel> getMeal(String mealId);
  Future<void> markMealCompleted(String mealId, String date);
  Future<void> unmarkMealCompleted(String mealId, String date);
  Future<Set<String>> getCompletedMealIds({String? date});
}

class DietRemoteDataSourceImpl implements DietRemoteDataSource {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;
  final OfflineSyncService _offlineSyncService;

  static const _emptyMarker = '__empty__';

  const DietRemoteDataSourceImpl(
    this._apiClient,
    this._localStorage,
    this._offlineSyncService,
  );

  String _todayDate() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  String _resolvedDate(String? date) => date ?? _todayDate();

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
      final merged = overlayPendingProgressActions(
        progress: inner,
        actions: _localStorage.getPendingSyncActions(),
        date: date,
      );
      await _localStorage.cacheData('day_progress_$date', merged);
      await _localStorage.cacheData('home_progress_$date', merged);
      await _localStorage.cacheData(
        'completed_meals_$date',
        (merged['meals_completed'] as List? ?? [])
            .map((entry) => entry.toString())
            .toList(growable: false),
      );
    }
  }

  @override
  Future<DietModel?> getTodayDiet({String? date}) async {
    final targetDate = _resolvedDate(date);
    final cacheKey = 'diet_today_$targetDate';

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/diets/today',
        queryParameters: date != null ? {'date': date} : null,
      );
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
  Future<WeeklyDietModel> getWeeklyDiet(String weekStart) async {
    final cacheKey = 'diet_week_$weekStart';
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/diets/week',
        queryParameters: {'week_start': weekStart},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map) {
          final normalized = Map<String, dynamic>.from(inner);
          await _localStorage.cacheData(cacheKey, normalized);
          return WeeklyDietModel.fromJson(normalized);
        }
      }
      throw Exception('Invalid weekly diet response');
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedMap(cacheKey);
        if (cached != null) return WeeklyDietModel.fromJson(cached);
      }
      rethrow;
    }
  }

  @override
  Future<MonthlyDietModel> getMonthlyDiet(int year, int month) async {
    final cacheKey = 'diet_month_${year}_${month.toString().padLeft(2, '0')}';
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/diets/month',
        queryParameters: {'year': year, 'month': month},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map) {
          final normalized = Map<String, dynamic>.from(inner);
          await _localStorage.cacheData(cacheKey, normalized);
          return MonthlyDietModel.fromJson(normalized);
        }
      }
      throw Exception('Invalid monthly diet response');
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedMap(cacheKey);
        if (cached != null) return MonthlyDietModel.fromJson(cached);
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
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/progress/meals/complete',
        data: {'meal_id': mealId, 'date': date},
      );
      await _cacheProgressResponse(response, date);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _offlineSyncService.queueMealCompletion(
        mealId,
        date,
        completed: true,
      );
    }
  }

  @override
  Future<void> unmarkMealCompleted(String mealId, String date) async {
    try {
      final response = await _apiClient.dio.delete<dynamic>(
        '/progress/meals/$mealId',
        queryParameters: {'date': date},
      );
      await _cacheProgressResponse(response, date);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _offlineSyncService.queueMealCompletion(
        mealId,
        date,
        completed: false,
      );
    }
  }

  @override
  Future<Set<String>> getCompletedMealIds({String? date}) async {
    final targetDate = _resolvedDate(date);
    final cacheKey = 'completed_meals_$targetDate';

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/progress',
        queryParameters: {'date': targetDate},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = (data['data'] as Map<String, dynamic>?) ?? data;
        final merged = overlayPendingProgressActions(
          progress: inner,
          actions: _localStorage.getPendingSyncActions(),
          date: targetDate,
        );
        final list = merged['meals_completed'] as List? ?? [];
        final completedIds = list
            .map((entry) => entry.toString())
            .toList(growable: false);
        await _localStorage.cacheData(cacheKey, completedIds);
        await _localStorage.cacheData('day_progress_$targetDate', merged);
        await _localStorage.cacheData('home_progress_$targetDate', merged);
        return completedIds.toSet();
      }
      return {};
    } catch (error) {
      if (isOfflineError(error)) {
        final cachedProgress = _localStorage.getCachedMap(
          'day_progress_$targetDate',
        );
        if (cachedProgress != null) {
          final merged = overlayPendingProgressActions(
            progress: cachedProgress,
            actions: _localStorage.getPendingSyncActions(),
            date: targetDate,
          );
          return (merged['meals_completed'] as List? ?? const [])
              .map((entry) => entry.toString())
              .toSet();
        }
        final cached = _localStorage.getCachedList(cacheKey);
        if (cached != null) {
          final merged = overlayPendingProgressActions(
            progress: {'meals_completed': cached},
            actions: _localStorage.getPendingSyncActions(),
            date: targetDate,
          );
          return (merged['meals_completed'] as List? ?? const [])
              .map((entry) => entry.toString())
              .toSet();
        }
      }
      return {};
    }
  }
}
