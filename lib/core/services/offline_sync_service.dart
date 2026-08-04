import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

class OfflineSyncService {
  static const _markExerciseCompleted = 'mark_exercise_completed';
  static const _unmarkExerciseCompleted = 'unmark_exercise_completed';
  static const _completeTraining = 'complete_training';
  static const _markMealCompleted = 'mark_meal_completed';
  static const _unmarkMealCompleted = 'unmark_meal_completed';

  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  StreamSubscription<User?>? _authSubscription;
  Timer? _syncTimer;
  bool _initialized = false;
  bool _syncInProgress = false;

  OfflineSyncService(this._apiClient, this._localStorage);

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (user != null) {
        unawaited(syncPendingActions());
      }
    });

    _syncTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(syncPendingActions());
    });

    await syncPendingActions();
  }

  Future<void> queueExerciseCompletion(
    String trainingExerciseId,
    String date, {
    required bool completed,
    String? exerciseId,
    double? weightUsed,
    List<SetPerformance>? sets,
  }) async {
    await _updateExerciseProgressCache(
      trainingExerciseId,
      date,
      completed: completed,
      exerciseId: exerciseId,
    );
    await _enqueueAction({
      'type': completed ? _markExerciseCompleted : _unmarkExerciseCompleted,
      'training_exercise_id': trainingExerciseId,
      'exercise_id': ?exerciseId,
      'date': date,
      'weight_used': ?weightUsed,
      'sets': ?sets?.map((set) => set.toJson()).toList(),
    });
  }

  Future<void> queueTrainingCompletion(
    String date, {
    required String trainingId,
    String? notes,
  }) async {
    await _updateTrainingCompletionCache(
      date,
      trainingId: trainingId,
      notes: notes,
    );
    await _enqueueAction({
      'type': _completeTraining,
      'date': date,
      'training_id': trainingId,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<void> queueMealCompletion(
    String mealId,
    String date, {
    required bool completed,
  }) async {
    await _updateMealProgressCache(mealId, date, completed: completed);
    await _enqueueAction({
      'type': completed ? _markMealCompleted : _unmarkMealCompleted,
      'meal_id': mealId,
      'date': date,
    });
  }

  Future<void> syncPendingActions() async {
    if (_syncInProgress || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final queue = _localStorage.getPendingSyncActions();
    if (queue.isEmpty) {
      return;
    }

    _syncInProgress = true;

    try {
      final pending = List<Map<String, dynamic>>.from(queue);

      while (pending.isNotEmpty) {
        final action = Map<String, dynamic>.from(pending.first);

        try {
          await _replayAction(action);
          pending.removeAt(0);
          await _persistQueue(pending);
        } on DioException catch (error) {
          final statusCode = error.response?.statusCode;

          if (isOfflineError(error) ||
              statusCode == 401 ||
              statusCode == 403 ||
              (statusCode != null && statusCode >= 500)) {
            debugPrint('[SYNC] Replay paused: ${error.message}');
            break;
          }

          debugPrint('[SYNC] Dropping unrecoverable action: $action');
          pending.removeAt(0);
          await _persistQueue(pending);
        } catch (error) {
          debugPrint('[SYNC] Dropping invalid action: $action ($error)');
          pending.removeAt(0);
          await _persistQueue(pending);
        }
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _enqueueAction(Map<String, dynamic> action) async {
    final queue = _localStorage.getPendingSyncActions();
    queue.add({
      ...action,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _persistQueue(queue);
  }

  Future<void> _persistQueue(List<Map<String, dynamic>> queue) async {
    if (queue.isEmpty) {
      await _localStorage.clearPendingSyncActions();
      return;
    }

    await _localStorage.savePendingSyncActions(queue);
  }

  Future<void> _replayAction(Map<String, dynamic> action) async {
    final type = action['type'] as String?;
    final date = action['date'] as String?;

    if (type == null || date == null) {
      throw StateError('Pending sync action is missing required fields');
    }

    switch (type) {
      case _markExerciseCompleted:
        final exerciseId = action['exercise_id'] as String?;
        final trainingExerciseId =
            action['training_exercise_id'] as String? ?? exerciseId;
        if (trainingExerciseId == null || exerciseId == null) {
          throw StateError('Pending sync action is missing exercise ids');
        }
        final response = await _apiClient.dio.post<dynamic>(
          '/progress/exercises/complete',
          data: {
            'exercise_id': exerciseId,
            'training_exercise_id': trainingExerciseId,
            'date': date,
            if (action['training_id'] != null)
              'training_id': action['training_id'],
            if (action['weight_used'] != null)
              'weight_used': action['weight_used'],
            if (action['sets'] != null) 'sets': action['sets'],
          },
        );
        await _cacheProgressResponse(response, date);
        return;
      case _unmarkExerciseCompleted:
        final trainingExerciseId =
            action['training_exercise_id'] as String? ??
            action['exercise_id'] as String?;
        if (trainingExerciseId == null) {
          throw StateError(
            'Pending sync action is missing training_exercise_id',
          );
        }
        final response = await _apiClient.dio.delete<dynamic>(
          '/progress/exercises/$trainingExerciseId',
          queryParameters: {'date': date},
        );
        await _cacheProgressResponse(response, date);
        return;
      case _completeTraining:
        final response = await _apiClient.dio.post<dynamic>(
          '/progress/trainings/complete',
          data: {
            'date': date,
            if (action['notes'] != null) 'notes': action['notes'],
          },
        );
        await _cacheProgressResponse(response, date);
        return;
      case _markMealCompleted:
        final mealId = action['meal_id'] as String?;
        if (mealId == null) {
          throw StateError('Pending sync action is missing meal_id');
        }
        final response = await _apiClient.dio.post<dynamic>(
          '/progress/meals/complete',
          data: {'meal_id': mealId, 'date': date},
        );
        await _cacheProgressResponse(response, date);
        return;
      case _unmarkMealCompleted:
        final mealId = action['meal_id'] as String?;
        if (mealId == null) {
          throw StateError('Pending sync action is missing meal_id');
        }
        final response = await _apiClient.dio.delete<dynamic>(
          '/progress/meals/$mealId',
          queryParameters: {'date': date},
        );
        await _cacheProgressResponse(response, date);
        return;
      default:
        throw StateError('Unsupported pending sync action type: $type');
    }
  }

  Future<void> _updateExerciseProgressCache(
    String trainingExerciseId,
    String date, {
    required bool completed,
    String? exerciseId,
  }) async {
    final progress = _getProgressCache(date);
    final currentExercises = _getExerciseEntries(progress);

    currentExercises.removeWhere(
      (entry) =>
          entry['training_exercise_id'] == trainingExerciseId ||
          entry['exercise_id'] == trainingExerciseId,
    );

    if (completed) {
      currentExercises.add({
        'training_exercise_id': trainingExerciseId,
        'exercise_id': exerciseId ?? trainingExerciseId,
        'completed_at': DateTime.now().toIso8601String(),
      });
    }

    final completedIds = currentExercises
        .map((entry) => entry['training_exercise_id'] ?? entry['exercise_id'])
        .whereType<String>()
        .toSet();
    final assignedIds = _getAssignedExerciseIds(date);

    progress['exercises_completed'] = currentExercises;
    progress['training_completed'] = assignedIds.isNotEmpty
        ? assignedIds.every(completedIds.contains)
        : false;

    await _saveProgressCache(date, progress);
  }

  Future<void> _updateTrainingCompletionCache(
    String date, {
    required String trainingId,
    String? notes,
  }) async {
    final progress = _getProgressCache(date);
    final currentExercises = _getExerciseEntries(progress);
    final currentById = <String, Map<String, dynamic>>{
      for (final entry in currentExercises)
        if (entry['exercise_id'] is String)
          (entry['training_exercise_id'] ?? entry['exercise_id']) as String:
              entry,
    };

    final training = _localStorage.getCachedMap('training_detail_$trainingId');
    final rawExercises = training?['exercises'];
    final assignedIds = rawExercises is List
        ? rawExercises
              .whereType<Map<String, dynamic>>()
              .map((exercise) => exercise['id'])
              .whereType<String>()
              .toSet()
        : <String>{};
    if (assignedIds.isNotEmpty) {
      progress['exercises_completed'] = [
        ...currentExercises.where(
          (entry) => !assignedIds.contains(entry['training_exercise_id']),
        ),
        ...assignedIds.map(
          (exerciseId) =>
              currentById[exerciseId] ??
              {
                'exercise_id': exerciseId,
                'training_exercise_id': exerciseId,
                'completed_at': DateTime.now().toIso8601String(),
              },
        ),
      ];
    }

    final completedTrainings = <String>{
      ...((progress['trainings_completed'] as List?) ?? const [])
          .whereType<String>(),
      trainingId,
    };
    progress['trainings_completed'] = completedTrainings.toList(
      growable: false,
    );
    final dayTrainings = _localStorage.getCachedList('training_day_$date');
    final assignedTrainingIds =
        dayTrainings
            ?.whereType<Map<String, dynamic>>()
            .map((training) => training['id'])
            .whereType<String>()
            .toSet() ??
        <String>{};
    progress['training_completed'] =
        assignedTrainingIds.isNotEmpty &&
        assignedTrainingIds.every(completedTrainings.contains);
    if (notes != null && notes.trim().isNotEmpty) {
      progress['notes'] = notes.trim();
    }

    await _saveProgressCache(date, progress);
  }

  Future<void> _updateMealProgressCache(
    String mealId,
    String date, {
    required bool completed,
  }) async {
    final progress = _getProgressCache(date);
    final meals = _getMealIds(progress);

    meals.removeWhere((entry) => entry == mealId);
    if (completed) {
      meals.add(mealId);
    }

    progress['meals_completed'] = meals.toSet().toList(growable: false);
    await _saveProgressCache(date, progress);
  }

  Map<String, dynamic> _getProgressCache(String date) {
    return Map<String, dynamic>.from(
      _localStorage.getCachedMap('day_progress_$date') ??
          {
            'date': date,
            'training_completed': false,
            'exercises_completed': <Map<String, dynamic>>[],
            'meals_completed': <String>[],
            'notes': null,
          },
    );
  }

  Future<void> _saveProgressCache(
    String date,
    Map<String, dynamic> progress,
  ) async {
    final normalizedExercises = _getExerciseEntries(progress);
    final normalizedMeals = _getMealIds(
      progress,
    ).toSet().toList(growable: false);

    final normalized = {
      ...progress,
      'exercises_completed': normalizedExercises,
      'meals_completed': normalizedMeals,
    };

    await _localStorage.cacheData('day_progress_$date', normalized);
    await _localStorage.cacheData('home_progress_$date', normalized);
    await _localStorage.cacheData(
      'completed_exercises_$date',
      normalizedExercises
          .map((entry) => entry['training_exercise_id'] ?? entry['exercise_id'])
          .whereType<String>()
          .toList(growable: false),
    );
    await _localStorage.cacheData('completed_meals_$date', normalizedMeals);
  }

  Set<String> _getAssignedExerciseIds(String date) {
    final training =
        _localStorage.getCachedMap('home_training_$date') ??
        _localStorage.getCachedMap('training_today_$date');
    if (training == null) {
      return <String>{};
    }

    final rawExercises =
        (training['exercises'] as List?) ??
        (training['training_exercises'] as List?) ??
        [];

    return rawExercises
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .map((entry) {
          final directId = entry['id'] ?? entry['training_exercise_id'];
          if (directId is String) {
            return directId;
          }

          final exercise = entry['exercise'];
          if (exercise is Map) {
            final nestedId = exercise['id'];
            if (nestedId is String) {
              return nestedId;
            }
          }

          return null;
        })
        .whereType<String>()
        .toSet();
  }

  List<Map<String, dynamic>> _getExerciseEntries(
    Map<String, dynamic> progress,
  ) {
    final rawExercises = progress['exercises_completed'] as List? ?? const [];
    return rawExercises
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: true);
  }

  List<String> _getMealIds(Map<String, dynamic> progress) {
    final rawMeals = progress['meals_completed'] as List? ?? const [];
    return rawMeals.map((entry) => entry.toString()).toList(growable: true);
  }

  Future<void> _cacheProgressResponse(
    Response<dynamic> response,
    String date,
  ) async {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      return;
    }

    final inner = (data['data'] as Map<String, dynamic>?) ?? data;
    await _saveProgressCache(date, inner);
  }
}
