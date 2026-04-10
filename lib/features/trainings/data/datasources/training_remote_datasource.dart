import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/data/models/training_model.dart';

abstract class TrainingRemoteDataSource {
  Future<TrainingModel?> getTodayTraining({String? date});
  Future<List<TrainingHistoryModel>> getTrainings({String? date});
  Future<TrainingModel> getTraining(String id);
  Future<void> markExerciseCompleted(
    String exerciseId,
    String date, {
    double? weightUsed,
  });
  Future<void> unmarkExerciseCompleted(String exerciseId, String date);
  Future<void> completeTraining(String date, {String? notes});
  Future<({Set<String> ids, Map<String, double> weights})>
  getCompletedExerciseIds({String? date});
}

class TrainingRemoteDataSourceImpl implements TrainingRemoteDataSource {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;
  final OfflineSyncService _offlineSyncService;

  static const _emptyMarker = '__empty__';
  static const _authMeCacheKey = 'auth_me';

  const TrainingRemoteDataSourceImpl(
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

  List<Map<String, dynamic>>? _getCachedMapList(String key) {
    final cached = _localStorage.getCachedList(key);
    if (cached == null) {
      return null;
    }

    return cached
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _extractAssignmentDays(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) {
      return const [];
    }

    final payload = responseData['data'];
    final rawDays = switch (payload) {
      Map<String, dynamic> map when map['days'] is List<dynamic> =>
        map['days'] as List<dynamic>,
      _ => const <dynamic>[],
    };

    return rawDays
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _extractCalendarDays(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) {
      return const [];
    }

    final payload = responseData['data'];
    if (payload is! List<dynamic>) {
      return const [];
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  Map<String, bool> _trainingCompletionByDate(List<Map<String, dynamic>> days) {
    return {
      for (final day in days)
        if (day['date'] is String)
          day['date'] as String: day['training_completed'] as bool? ?? false,
    };
  }

  Future<String> _getCurrentUserId() async {
    final cachedUser = _localStorage.getCachedMap(_authMeCacheKey);
    final cachedId = cachedUser?['id'] as String?;

    try {
      final response = await _apiClient.dio.get<dynamic>('/auth/me');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          await _localStorage.cacheData(_authMeCacheKey, inner);
          final id = inner['id'] as String?;
          if (id != null && id.isNotEmpty) {
            return id;
          }
        }
      }

      if (cachedId != null && cachedId.isNotEmpty) {
        return cachedId;
      }

      throw Exception('Invalid current user response');
    } catch (error) {
      if (cachedId != null && cachedId.isNotEmpty && isOfflineError(error)) {
        return cachedId;
      }
      rethrow;
    }
  }

  List<TrainingHistoryModel> _buildTrainingHistory(
    List<Map<String, dynamic>> assignmentDays,
    List<Map<String, dynamic>> calendarDays,
  ) {
    final completionByDate = _trainingCompletionByDate(calendarDays);
    final history = assignmentDays
        .where((day) => day['training'] is Map<String, dynamic>)
        .map(
          (day) => TrainingHistoryModel.fromAssignmentJson(
            day,
            isCompleted:
                completionByDate[day['date'] as String? ?? ''] ?? false,
          ),
        )
        .where((entry) => entry.id.isNotEmpty)
        .toList();

    history.sort((left, right) => right.date.compareTo(left.date));
    return List<TrainingHistoryModel>.unmodifiable(history);
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
        'completed_exercises_$date',
        (inner['exercises_completed'] as List? ?? [])
            .map(
              (entry) =>
                  (entry as Map<String, dynamic>)['exercise_id'] as String,
            )
            .toList(growable: false),
      );
    }
  }

  @override
  Future<TrainingModel?> getTodayTraining({String? date}) async {
    final targetDate = _resolvedDate(date);
    final cacheKey = 'training_today_$targetDate';

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/trainings/today',
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
          return TrainingModel.fromJson(inner);
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
          return TrainingModel.fromJson(cached);
        }
      }

      rethrow;
    }
  }

  @override
  Future<List<TrainingHistoryModel>> getTrainings({String? date}) async {
    final targetDate = _resolvedDate(date);
    final monthDate = DateTime.tryParse(targetDate) ?? DateTime.now();
    final userId = await _getCurrentUserId();
    final assignmentsCacheKey =
        'trainings_history_assignments_${userId}_${monthDate.year}_${monthDate.month}';
    final calendarCacheKey =
        'trainings_history_calendar_${monthDate.year}_${monthDate.month}';

    try {
      final responses = await Future.wait([
        _apiClient.dio.get<dynamic>(
          '/assignments/month',
          queryParameters: {
            'client_id': userId,
            'year': monthDate.year,
            'month': monthDate.month,
          },
        ),
        _apiClient.dio.get<dynamic>(
          '/calendar/month',
          queryParameters: {'year': monthDate.year, 'month': monthDate.month},
        ),
      ]);

      final assignmentDays = _extractAssignmentDays(responses[0].data);
      final calendarDays = _extractCalendarDays(responses[1].data);

      await _localStorage.cacheData(assignmentsCacheKey, assignmentDays);
      await _localStorage.cacheData(calendarCacheKey, calendarDays);

      return _buildTrainingHistory(assignmentDays, calendarDays);
    } catch (error) {
      if (isOfflineError(error)) {
        final cachedAssignments =
            _getCachedMapList(assignmentsCacheKey) ?? const [];
        final cachedCalendar = _getCachedMapList(calendarCacheKey) ?? const [];

        if (cachedAssignments.isNotEmpty || cachedCalendar.isNotEmpty) {
          return _buildTrainingHistory(cachedAssignments, cachedCalendar);
        }
      }
      rethrow;
    }
  }

  @override
  Future<TrainingModel> getTraining(String id) async {
    final cacheKey = 'training_detail_$id';

    try {
      final response = await _apiClient.dio.get<dynamic>('/trainings/$id');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          await _localStorage.cacheData(cacheKey, inner);
          return TrainingModel.fromJson(inner);
        }
      }
      throw Exception('Invalid response');
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedMap(cacheKey);
        if (cached != null) {
          return TrainingModel.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> markExerciseCompleted(
    String exerciseId,
    String date, {
    double? weightUsed,
  }) async {
    try {
      final payload = <String, dynamic>{
        'exercise_id': exerciseId,
        'date': date,
      };
      if (weightUsed != null) {
        payload['weight_used'] = weightUsed;
      }

      final response = await _apiClient.dio.post<dynamic>(
        '/progress/exercises/complete',
        data: payload,
      );
      await _cacheProgressResponse(response, date);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _offlineSyncService.queueExerciseCompletion(
        exerciseId,
        date,
        completed: true,
      );
    }
  }

  @override
  Future<void> unmarkExerciseCompleted(String exerciseId, String date) async {
    try {
      final response = await _apiClient.dio.delete<dynamic>(
        '/progress/exercises/$exerciseId',
        queryParameters: {'date': date},
      );
      await _cacheProgressResponse(response, date);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _offlineSyncService.queueExerciseCompletion(
        exerciseId,
        date,
        completed: false,
      );
    }
  }

  @override
  Future<void> completeTraining(String date, {String? notes}) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/progress/trainings/complete',
        data: {
          'date': date,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      await _cacheProgressResponse(response, date);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _offlineSyncService.queueTrainingCompletion(date, notes: notes);
    }
  }

  @override
  Future<({Set<String> ids, Map<String, double> weights})>
  getCompletedExerciseIds({String? date}) async {
    final targetDate = _resolvedDate(date);
    final cacheKey = 'completed_exercises_$targetDate';

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/progress',
        queryParameters: {'date': targetDate},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = (data['data'] as Map<String, dynamic>?) ?? data;
        final list = inner['exercises_completed'] as List? ?? [];
        final ids = <String>{};
        final weights = <String, double>{};
        for (final entry in list) {
          final map = entry as Map<String, dynamic>;
          final id = map['exercise_id'] as String;
          ids.add(id);
          final w = map['weight_used'];
          if (w != null) {
            weights[id] = (w as num).toDouble();
          }
        }
        await _localStorage.cacheData(cacheKey, ids.toList());
        await _localStorage.cacheData('day_progress_$targetDate', inner);
        await _localStorage.cacheData('home_progress_$targetDate', inner);
        return (ids: ids, weights: weights);
      }
      return (ids: <String>{}, weights: <String, double>{});
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedList(cacheKey);
        if (cached != null) {
          return (
            ids: cached.map((item) => item.toString()).toSet(),
            weights: <String, double>{},
          );
        }
      }
      return (ids: <String>{}, weights: <String, double>{});
    }
  }
}
