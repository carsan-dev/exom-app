import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/data/models/training_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

abstract class TrainingRemoteDataSource {
  Future<TrainingModel?> getTodayTraining({String? date});
  Future<List<TrainingModel>> getDayTrainings({String? date});
  Future<List<TrainingHistoryModel>> getTrainings({String? date});
  Future<TrainingModel> getTraining(String id);
  Future<void> markExerciseCompleted(
    String trainingExerciseId,
    String exerciseId,
    String date, {
    double? weightUsed,
    List<SetPerformance>? sets,
  });
  Future<void> unmarkExerciseCompleted(String trainingExerciseId, String date);
  Future<void> completeTraining(
    String date, {
    required String trainingId,
    String? notes,
  });
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date});
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  );
}

List<TrainingHistoryModel> buildTrainingHistory(
  List<Map<String, dynamic>> assignmentDays,
  List<Map<String, dynamic>> calendarDays, {
  required DateTime today,
}) {
  final cutoff = DateTime(today.year, today.month, today.day);
  final completionByDate = {
    for (final day in calendarDays)
      if (day['date'] is String)
        day['date'] as String: day['training_completed'] as bool? ?? false,
  };
  final history = assignmentDays
      .where((day) {
        final date = DateTime.tryParse(day['date'] as String? ?? '');
        if (date == null) return false;
        return DateTime(date.year, date.month, date.day).isBefore(cutoff);
      })
      .expand((day) {
        final plural = day['trainings'];
        final trainings = plural is List
            ? plural.whereType<Map<String, dynamic>>().toList(growable: false)
            : day['training'] is Map<String, dynamic>
            ? [day['training'] as Map<String, dynamic>]
            : const <Map<String, dynamic>>[];
        return trainings.map(
          (training) => TrainingHistoryModel.fromAssignmentJson(
            {...day, 'training': training},
            isCompleted:
                completionByDate[day['date'] as String? ?? ''] ?? false,
          ),
        );
      })
      .where((entry) => entry.id.isNotEmpty)
      .toList();

  history.sort((left, right) => right.date.compareTo(left.date));
  return List<TrainingHistoryModel>.unmodifiable(history);
}

TrainingDayProgress parseTrainingDayProgress(Map<String, dynamic> json) {
  final list = json['exercises_completed'] as List? ?? [];
  final ids = <String>{};
  final weights = <String, double>{};
  final performances = <String, List<SetPerformance>>{};

  for (final entry in list.whereType<Map>()) {
    final id = (entry['training_exercise_id'] ?? entry['exercise_id'])
        ?.toString();
    if (id == null || id.isEmpty) continue;
    ids.add(id);

    final weight = entry['weight_used'];
    if (weight is num) {
      weights[id] = weight.toDouble();
    }

    final sets = entry['sets'];
    if (sets is List) {
      performances[id] = sets
          .whereType<Map>()
          .map(
            (set) => SetPerformance(
              setNumber: set['set_number'] as int? ?? 1,
              reps: set['reps'] as int?,
              seconds: set['seconds'] as int?,
              weightKg: (set['weight_kg'] as num?)?.toDouble(),
            ),
          )
          .where(
            (set) =>
                set.reps != null || set.seconds != null || set.weightKg != null,
          )
          .toList(growable: false);
    }
  }

  return TrainingDayProgress(
    ids: ids,
    weights: weights,
    performances: performances,
    note: json['notes'] as String?,
    adminReplyText: json['admin_reply_text'] as String?,
    adminReplySentAt: DateTime.tryParse(
      json['admin_reply_sent_at'] as String? ?? '',
    ),
  );
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
                  ((entry as Map<String, dynamic>)['training_exercise_id'] ??
                          entry['exercise_id'])
                      as String,
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
  Future<List<TrainingModel>> getDayTrainings({String? date}) async {
    final targetDate = _resolvedDate(date);
    final cacheKey = 'training_day_$targetDate';
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/trainings/day',
        queryParameters: {'date': targetDate},
      );
      final envelope = response.data;
      final payload = envelope is Map<String, dynamic>
          ? envelope['data']
          : null;
      final rawTrainings =
          payload is Map<String, dynamic> && payload['trainings'] is List
          ? payload['trainings'] as List
          : const <dynamic>[];
      final maps = rawTrainings
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
      await _localStorage.cacheData(cacheKey, maps);
      return maps.map(TrainingModel.fromJson).toList(growable: false);
    } on DioException catch (error) {
      if (isOfflineError(error)) {
        final cached = _getCachedMapList(cacheKey);
        if (cached != null) {
          return cached.map(TrainingModel.fromJson).toList(growable: false);
        }
      }
      // Transitional fallback for servers that still only expose /today.
      if (error.response?.statusCode == 404) {
        final first = await getTodayTraining(date: targetDate);
        return first == null ? const [] : [first];
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

      return buildTrainingHistory(
        assignmentDays,
        calendarDays,
        today: DateTime.now(),
      );
    } catch (error) {
      if (isOfflineError(error)) {
        final cachedAssignments =
            _getCachedMapList(assignmentsCacheKey) ?? const [];
        final cachedCalendar = _getCachedMapList(calendarCacheKey) ?? const [];

        if (cachedAssignments.isNotEmpty || cachedCalendar.isNotEmpty) {
          return buildTrainingHistory(
            cachedAssignments,
            cachedCalendar,
            today: DateTime.now(),
          );
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
    String trainingExerciseId,
    String exerciseId,
    String date, {
    double? weightUsed,
    List<SetPerformance>? sets,
  }) async {
    try {
      final payload = <String, dynamic>{
        'exercise_id': exerciseId,
        'training_exercise_id': trainingExerciseId,
        'date': date,
      };
      if (weightUsed != null) {
        payload['weight_used'] = weightUsed;
      }
      if (sets != null) {
        payload['sets'] = sets.map((set) => set.toJson()).toList();
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
        trainingExerciseId,
        date,
        completed: true,
        exerciseId: exerciseId,
        weightUsed: weightUsed,
        sets: sets,
      );
    }
  }

  @override
  Future<void> unmarkExerciseCompleted(
    String trainingExerciseId,
    String date,
  ) async {
    try {
      final response = await _apiClient.dio.delete<dynamic>(
        '/progress/exercises/$trainingExerciseId',
        queryParameters: {'date': date},
      );
      await _cacheProgressResponse(response, date);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _offlineSyncService.queueExerciseCompletion(
        trainingExerciseId,
        date,
        completed: false,
      );
    }
  }

  @override
  Future<void> completeTraining(
    String date, {
    required String trainingId,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/progress/trainings/complete',
        data: {
          'date': date,
          'training_id': trainingId,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      await _cacheProgressResponse(response, date);
    } on DioException catch (error) {
      if (!isOfflineError(error)) {
        rethrow;
      }

      await _offlineSyncService.queueTrainingCompletion(
        date,
        trainingId: trainingId,
        notes: notes,
      );
    }
  }

  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async {
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
        final progress = parseTrainingDayProgress(inner);
        await _localStorage.cacheData(cacheKey, progress.ids.toList());
        await _localStorage.cacheData('day_progress_$targetDate', inner);
        await _localStorage.cacheData('home_progress_$targetDate', inner);
        return progress;
      }
      return const TrainingDayProgress();
    } catch (error) {
      if (isOfflineError(error)) {
        final cachedProgress = _localStorage.getCachedMap(
          'day_progress_$targetDate',
        );
        if (cachedProgress != null) {
          return parseTrainingDayProgress(cachedProgress);
        }
        final cached = _localStorage.getCachedList(cacheKey);
        if (cached != null) {
          return TrainingDayProgress(
            ids: cached.map((item) => item.toString()).toSet(),
          );
        }
      }
      return const TrainingDayProgress();
    }
  }

  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async {
    final uniqueIds = exerciseIds.toSet().where((id) => id.isNotEmpty).toList();
    if (uniqueIds.isEmpty) return const {};

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/progress/exercises/previous',
        queryParameters: {
          'exercise_ids': uniqueIds.join(','),
          'before': beforeDate,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return const {};

      final inner = (data['data'] as Map<String, dynamic>?) ?? data;
      final result = <String, List<SetPerformance>>{};
      for (final entry in inner.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        final sets = value['sets'];
        if (sets is! List) continue;
        result[entry.key] = sets
            .whereType<Map<String, dynamic>>()
            .map(
              (set) => SetPerformance(
                setNumber: set['set_number'] as int? ?? 1,
                reps: set['reps'] as int?,
                seconds: set['seconds'] as int?,
                weightKg: (set['weight_kg'] as num?)?.toDouble(),
              ),
            )
            .where(
              (set) =>
                  set.reps != null ||
                  set.seconds != null ||
                  set.weightKg != null,
            )
            .toList(growable: false);
      }
      return result;
    } catch (_) {
      return const {};
    }
  }
}
