import 'package:exom_app/core/utils/operation_id.dart';
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/services/pending_progress_overlay.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/core/utils/async_mutex.dart';

class _FeedbackDependencyPending implements Exception {
  const _FeedbackDependencyPending();
}

class OfflineSyncService {
  static const _markExerciseCompleted = 'mark_exercise_completed';
  static const _unmarkExerciseCompleted = 'unmark_exercise_completed';
  static const _completeTraining = 'complete_training';
  static const _markMealCompleted = 'mark_meal_completed';
  static const _unmarkMealCompleted = 'unmark_meal_completed';

  final ApiClient _apiClient;
  final LocalStorage _localStorage;
  final bool Function() _isAuthenticated;
  final Stream<bool> Function() _authenticationChanges;
  final Stream<bool> _connectivityChanges;
  static final AsyncMutex _queueMutex = AsyncMutex();
  static final AsyncMutex _syncMutex = AsyncMutex();
  final StreamController<void> _changes = StreamController<void>.broadcast();

  StreamSubscription<bool>? _authSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _initialized = false;

  Stream<void> get changes => _changes.stream;

  OfflineSyncService(
    this._apiClient,
    this._localStorage, {
    bool Function()? isAuthenticated,
    Stream<bool>? authenticationChanges,
    Stream<bool>? connectivityChanges,
  }) : _isAuthenticated =
           isAuthenticated ?? (() => FirebaseAuth.instance.currentUser != null),
       _authenticationChanges = authenticationChanges != null
           ? (() => authenticationChanges)
           : (() => FirebaseAuth.instance.authStateChanges().map(
               (user) => user != null,
             )),
       _connectivityChanges =
           connectivityChanges ??
           Connectivity().onConnectivityChanged
               .map(
                 (results) =>
                     results.any((result) => result != ConnectivityResult.none),
               )
               .distinct();

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    await _rebuildFailedActionProgressCaches();

    _authSubscription ??= _authenticationChanges().listen((authenticated) {
      if (authenticated) {
        unawaited(syncPendingActions());
      }
    });
    _connectivitySubscription ??= _connectivityChanges.listen((connected) {
      if (connected) {
        unawaited(_syncAfterReconnect());
      }
    });

    _syncTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(syncPendingActions());
    });

    await syncPendingActions();
  }

  Future<void> dispose() async {
    _syncTimer?.cancel();
    await _authSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _changes.close();
  }

  Future<void> queueExerciseCompletion(
    String trainingExerciseId,
    String date, {
    required bool completed,
    String? exerciseId,
    double? weightUsed,
    List<SetPerformance>? sets,
    String? lastSetFeedbackClientUploadId,
    String? trainingId,
  }) async {
    await _enqueueAction({
      'type': completed ? _markExerciseCompleted : _unmarkExerciseCompleted,
      'training_exercise_id': trainingExerciseId,
      'exercise_id': ?exerciseId,
      'date': date,
      'weight_used': ?weightUsed,
      'sets': ?sets?.map((set) => set.toJson()).toList(),
      'last_set_feedback_client_upload_id': ?lastSetFeedbackClientUploadId,
      'training_id': ?trainingId,
    });
    await _updateExerciseProgressCache(
      trainingExerciseId,
      date,
      completed: completed,
      exerciseId: exerciseId,
    );
    if (lastSetFeedbackClientUploadId != null &&
        _localStorage.getFeedbackUploadQueue().any(
          (item) =>
              item['id'] == lastSetFeedbackClientUploadId &&
              item['status'] == 'completed',
        )) {
      unawaited(syncPendingActions());
    }
  }

  Future<void> queueTrainingCompletion(
    String date, {
    required String trainingId,
    String? notes,
  }) async {
    final dependencies = _localStorage
        .getFeedbackUploadQueue()
        .where(
          (item) =>
              item['training_id'] == trainingId &&
              item['assignment_date'] == date &&
              item['status'] != 'completed',
        )
        .map((item) => item['id'])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    await _enqueueAction(
      {
        'type': _completeTraining,
        'date': date,
        'training_id': trainingId,
        if (dependencies.isNotEmpty) 'depends_on_feedback_ids': dependencies,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
      isDuplicate: (action) =>
          action['type'] == _completeTraining &&
          action['date'] == date &&
          action['training_id'] == trainingId &&
          action['status'] != 'failed' &&
          action['notes'] ==
              (notes?.trim().isEmpty == false ? notes!.trim() : null),
    );
    await _updateTrainingCompletionCache(
      date,
      trainingId: trainingId,
      notes: notes,
    );
    if (dependencies.isNotEmpty &&
        dependencies.every(
          (id) => _localStorage.getFeedbackUploadQueue().any(
            (item) => item['id'] == id && item['status'] == 'completed',
          ),
        )) {
      unawaited(syncPendingActions());
    }
  }

  Future<void> queueMealCompletion(
    String mealId,
    String date, {
    required bool completed,
  }) async {
    await _enqueueAction({
      'type': completed ? _markMealCompleted : _unmarkMealCompleted,
      'meal_id': mealId,
      'date': date,
    });
    await _updateMealProgressCache(mealId, date, completed: completed);
  }

  Future<void> syncPendingActions() {
    return _localStorage.withSession(
      () => _syncMutex.protect(_syncPendingActionsLocked),
    );
  }

  Future<void> _syncAfterReconnect() {
    return _localStorage.withSession(
      () => _syncMutex.protect(() async {
        await _makeQueuedActionsEligibleNow();
        await _syncPendingActionsLocked();
      }),
    );
  }

  Future<void> _syncPendingActionsLocked() async {
    if (!_isAuthenticated()) {
      return;
    }

    await _recoverInterruptedActions();
    final session = _localStorage.sessionStamp;
    bool current() =>
        session != null &&
        _localStorage.sessionStamp == session &&
        _isAuthenticated();
    if (_localStorage.getPendingSyncActions().isEmpty) {
      return;
    }

    final visitedIds = <String>{};
    while (true) {
      if (!current()) break;
      final action = await _claimNextAction(visitedIds);
      if (action == null) break;
      final id = action['id'] as String;
      visitedIds.add(id);
      try {
        if (_localStorage.sessionStamp != session) break;
        if (!current()) {
          await _mutateById(id, (current) => {...current, 'status': 'queued'});
          break;
        }
        final acknowledgedRevision = await _replayAction(action);
        if (!_isAuthenticated()) {
          await _mutateById(id, (current) => {...current, 'status': 'queued'});
          break;
        }
        await _acknowledgeAction(id, acknowledgedRevision);
      } on _FeedbackDependencyPending {
        await _mutateById(id, (current) => {...current, 'status': 'queued'});
      } on DioException catch (error) {
        if (!_isAuthenticated()) {
          await _mutateById(id, (current) => {...current, 'status': 'queued'});
          break;
        }
        final statusCode = error.response?.statusCode;
        final offline = isOfflineError(error);
        final errorData = error.response?.data;
        final conflict =
            errorData is Map &&
            (errorData['code'] == 'PROGRESS_VERSION_CONFLICT' ||
                errorData['code'] == 'PROGRESS_OPERATION_CONFLICT');
        final retryable =
            !conflict &&
            (offline ||
                statusCode == 401 ||
                statusCode == 409 ||
                statusCode == 429 ||
                (statusCode != null && statusCode >= 500));
        if (conflict && errorData['current_progress'] is Map<String, dynamic>) {
          await _cacheProgressResponse(
            Response(
              requestOptions: error.requestOptions,
              data: errorData['current_progress'],
            ),
            action['date'] as String,
          );
        }
        await _recordReplayFailure(
          id,
          action,
          conflict
              ? 'progress_conflict_review_required'
              : (errorData is Map && errorData['code'] is String
                    ? errorData['code'] as String
                    : 'sync_request_failed'),
          retryable: retryable,
          retryIndefinitely: offline,
        );
      } catch (error) {
        if (_localStorage.sessionStamp != session) break;
        debugPrint(
          '[SYNC] Invalid action type=${action['type']} cause=${error.runtimeType}',
        );
        await _recordReplayFailure(
          id,
          action,
          error.toString(),
          retryable: false,
        );
      }
    }
  }

  Future<void> _recoverInterruptedActions() async {
    var changed = false;
    await _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      for (var index = 0; index < queue.length; index++) {
        if (queue[index]['status'] != 'uploading') continue;
        final recovered = <String, dynamic>{...queue[index], 'status': 'queued'}
          ..remove('next_attempt_at');
        queue[index] = recovered;
        changed = true;
      }
      if (changed) await _persistQueue(queue);
    });
    if (changed) _changes.add(null);
  }

  Future<void> _makeQueuedActionsEligibleNow() async {
    var changed = false;
    await _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      for (var index = 0; index < queue.length; index++) {
        if (queue[index]['status'] != 'queued' ||
            !queue[index].containsKey('next_attempt_at')) {
          continue;
        }
        queue[index] = Map<String, dynamic>.from(queue[index])
          ..remove('next_attempt_at');
        changed = true;
      }
      if (changed) await _persistQueue(queue);
    });
    if (changed) _changes.add(null);
  }

  Future<void> _recordReplayFailure(
    String id,
    Map<String, dynamic> action,
    String error, {
    required bool retryable,
    bool retryIndefinitely = false,
  }) async {
    var failedPermanently = false;
    await _mutateById(id, (current) {
      final updated = _failedOrRetriedAction(
        current,
        error,
        retryable: retryable,
        retryIndefinitely: retryIndefinitely,
      );
      failedPermanently = updated['status'] == 'failed';
      return updated;
    });
    if (failedPermanently) {
      await _rebuildProgressCachesAfterFailure(action['date'] as String?);
    }
  }

  Future<void> _rebuildFailedActionProgressCaches() async {
    final failedDates = _localStorage
        .getPendingSyncActions()
        .where((action) => action['status'] == 'failed')
        .map((action) => action['date'])
        .whereType<String>()
        .toSet();
    for (final date in failedDates) {
      await _rebuildProgressCachesAfterFailure(date);
    }
  }

  Future<void> _rebuildProgressCachesAfterFailure(String? date) async {
    if (date == null) return;
    await _saveProgressCache(
      date,
      _localStorage.getCachedMap('server_progress_$date') ??
          {
            'date': date,
            'training_completed': false,
            'trainings_completed': <String>[],
            'exercises_completed': <Map<String, dynamic>>[],
            'meals_completed': <String>[],
            'notes': null,
          },
    );
  }

  Future<bool> _enqueueAction(
    Map<String, dynamic> action, {
    bool Function(Map<String, dynamic> action)? isDuplicate,
  }) async {
    var enqueued = false;
    await _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      final existingForDate = queue
          .where((entry) => entry['date'] == action['date'])
          .toList();
      if (isDuplicate != null &&
          existingForDate.isNotEmpty &&
          isDuplicate(existingForDate.last)) {
        return;
      }
      final sameDate = queue
          .where(
            (entry) =>
                entry['date'] == action['date'] && entry['format_version'] == 2,
          )
          .toList();
      if (existingForDate.isEmpty) {
        final canonical = _localStorage.getCachedMap(
          'day_progress_${action['date']}',
        );
        if (canonical != null) {
          await _localStorage.cacheData(
            'server_progress_${action['date']}',
            canonical,
          );
        }
      }
      queue.add({
        ...action,
        'expected_revision':
            _localStorage.getCachedMap(
              'day_progress_${action['date']}',
            )?['sync_revision'] ??
            0,
        if (sameDate.isNotEmpty) 'predecessor_id': sameDate.last['id'],
        ..._localStorage.queueIdentity,
        'id': newOperationId(),
        'status': 'queued',
        'attempts': 0,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _persistQueue(queue);
      enqueued = true;
    });
    if (enqueued) _changes.add(null);
    return enqueued;
  }

  Map<String, dynamic> _failedOrRetriedAction(
    Map<String, dynamic> action,
    String error, {
    required bool retryable,
    bool retryIndefinitely = false,
  }) {
    final attempts = (action['attempts'] as int? ?? 0) + 1;
    if (!retryable || (!retryIndefinitely && attempts >= 5)) {
      return {
        ...action,
        'status': 'failed',
        'attempts': attempts,
        'last_error': error,
      };
    }
    const delays = [30, 120, 600, 3600];
    final delayIndex = attempts <= delays.length
        ? attempts - 1
        : delays.length - 1;
    return {
      ...action,
      'status': 'queued',
      'attempts': attempts,
      'last_error': error,
      'next_attempt_at': DateTime.now()
          .toUtc()
          .add(Duration(seconds: delays[delayIndex]))
          .toIso8601String(),
    };
  }

  Future<void> removeActionsDependingOnFeedback(String feedbackId) async {
    await _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      for (var index = 0; index < queue.length; index++) {
        final action = Map<String, dynamic>.from(queue[index]);
        final dependencies =
            ((action['depends_on_feedback_ids'] as List?) ?? const [])
                .whereType<String>()
                .toList(growable: true);
        final directlyDepends =
            action['last_set_feedback_client_upload_id'] == feedbackId;
        final transitivelyDepends = dependencies.remove(feedbackId);
        if (!directlyDepends && !transitivelyDepends) continue;
        action.remove('last_set_feedback_client_upload_id');
        action['depends_on_feedback_ids'] = dependencies;
        action['status'] = 'failed';
        action['last_error'] = 'feedback_discarded';
        queue[index] = action;
      }
      await _persistQueue(queue);
    });
    _changes.add(null);
  }

  Future<void> retryAction(String id) async {
    await _mutateById(id, (action) {
      if (action['status'] != 'failed' ||
          action['last_error'] == 'progress_conflict_review_required') {
        return action;
      }
      return {
        ...action,
        'status': 'queued',
        'attempts': 0,
        'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null,
      };
    });
    await syncPendingActions();
  }

  Future<void> discardAction(String id) => _localStorage.withSession(() async {
    String? date;
    await _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      final index = queue.indexWhere((entry) => entry['id'] == id);
      if (index < 0 || queue[index]['status'] == 'uploading') return;
      date = queue[index]['date'] as String?;
      queue.removeAt(index);
      for (var i = index; i < queue.length; i++) {
        if (queue[i]['date'] == date) {
          queue[i] = {
            ...queue[i],
            'status': 'failed',
            'last_error': 'progress_conflict_review_required',
          };
        }
      }
      await _persistQueue(queue);
    });
    if (date != null) await _rebuildProgressCachesAfterFailure(date);
    _changes.add(null);
  });

  List<Map<String, dynamic>> get pendingActions =>
      _localStorage.getPendingSyncActions();

  Future<void> _persistQueue(List<Map<String, dynamic>> queue) async {
    if (queue.isEmpty) {
      await _localStorage.clearPendingSyncActions();
      return;
    }

    await _localStorage.savePendingSyncActions(queue);
  }

  Future<int?> _replayAction(Map<String, dynamic> action) async {
    _localStorage.guardSession();
    final options = action['format_version'] == 2
        ? Options(
            headers: {
              'x-exom-operation-id': action['id'],
              'x-exom-revision': action['expected_revision'],
            },
            extra: {'exom.auth.expectedOwner': action['owner_id']},
          )
        : null;
    final type = action['type'] as String?;
    final date = action['date'] as String?;

    if (type == null || date == null) {
      throw StateError('Pending sync action is missing required fields');
    }

    final dependencies =
        ((action['depends_on_feedback_ids'] as List?) ?? const [])
            .whereType<String>();
    final feedbackQueue = _localStorage.getFeedbackUploadQueue();
    if (dependencies.any((id) {
      final matches = feedbackQueue.where((item) => item['id'] == id);
      return matches.isEmpty || matches.first['status'] != 'completed';
    })) {
      throw const _FeedbackDependencyPending();
    }

    switch (type) {
      case _markExerciseCompleted:
        final exerciseId = action['exercise_id'] as String?;
        final trainingExerciseId =
            action['training_exercise_id'] as String? ?? exerciseId;
        if (trainingExerciseId == null || exerciseId == null) {
          throw StateError('Pending sync action is missing exercise ids');
        }
        final feedbackId =
            action['last_set_feedback_client_upload_id'] as String?;
        if (feedbackId != null &&
            !_localStorage.getFeedbackUploadQueue().any(
              (item) =>
                  item['id'] == feedbackId && item['status'] == 'completed',
            )) {
          throw const _FeedbackDependencyPending();
        }
        final sets = _setPerformancesForReplay(action['sets']);
        final response = await _apiClient.dio.post<dynamic>(
          '/progress/exercises/complete',
          options: options,
          data: {
            'exercise_id': exerciseId,
            'training_exercise_id': trainingExerciseId,
            'date': date,
            if (action['weight_used'] != null)
              'weight_used': action['weight_used'],
            'sets': ?sets,
            'last_set_feedback_client_upload_id': ?feedbackId,
          },
        );
        return _cacheProgressResponse(
          response,
          date,
          acknowledgedId: action['format_version'] == 2
              ? action['id'] as String
              : null,
        );
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
          options: options,
          queryParameters: {'date': date},
        );
        return _cacheProgressResponse(
          response,
          date,
          acknowledgedId: action['format_version'] == 2
              ? action['id'] as String
              : null,
        );
      case _completeTraining:
        final response = await _apiClient.dio.post<dynamic>(
          '/progress/trainings/complete',
          options: options,
          data: {
            'date': date,
            if (action['training_id'] != null)
              'training_id': action['training_id'],
            if (action['notes'] != null) 'notes': action['notes'],
          },
        );
        return _cacheProgressResponse(
          response,
          date,
          acknowledgedId: action['format_version'] == 2
              ? action['id'] as String
              : null,
        );
      case _markMealCompleted:
        final mealId = action['meal_id'] as String?;
        if (mealId == null) {
          throw StateError('Pending sync action is missing meal_id');
        }
        final response = await _apiClient.dio.post<dynamic>(
          '/progress/meals/complete',
          options: options,
          data: {'meal_id': mealId, 'date': date},
        );
        return _cacheProgressResponse(
          response,
          date,
          acknowledgedId: action['format_version'] == 2
              ? action['id'] as String
              : null,
        );
      case _unmarkMealCompleted:
        final mealId = action['meal_id'] as String?;
        if (mealId == null) {
          throw StateError('Pending sync action is missing meal_id');
        }
        final response = await _apiClient.dio.delete<dynamic>(
          '/progress/meals/$mealId',
          options: options,
          queryParameters: {'date': date},
        );
        return _cacheProgressResponse(
          response,
          date,
          acknowledgedId: action['format_version'] == 2
              ? action['id'] as String
              : null,
        );
      default:
        throw StateError('Unsupported pending sync action type: $type');
    }
  }

  List<Map<String, dynamic>>? _setPerformancesForReplay(Object? value) {
    if (value == null) return null;
    if (value is! List) {
      throw StateError('Pending sync action has invalid set performances');
    }
    return value
        .map((set) {
          if (set is! Map) {
            throw StateError(
              'Pending sync action has an invalid set performance',
            );
          }
          final normalized = Map<String, dynamic>.from(set);
          if (normalized['rir'] == null) normalized.remove('rir');
          return normalized;
        })
        .toList(growable: false);
  }

  bool hasPendingFeedbackForTraining(String trainingId, String date) {
    return _localStorage.getFeedbackUploadQueue().any(
      (item) =>
          item['training_id'] == trainingId &&
          item['assignment_date'] == date &&
          item['status'] != 'completed',
    );
  }

  Future<Map<String, dynamic>?> _claimNextAction(Set<String> excludedIds) {
    return _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      final index = queue.indexWhere((action) {
        if (!_localStorage.ownsEntry(action)) return false;
        if (excludedIds.contains(action['id'])) return false;
        if (action['status'] != 'queued') return false;
        if (action['format_version'] == 2 &&
            queue
                .takeWhile((entry) => entry['id'] != action['id'])
                .any((entry) => entry['date'] == action['date'])) {
          return false;
        }
        final next = DateTime.tryParse(
          action['next_attempt_at'] as String? ?? '',
        );
        return next == null || !next.isAfter(DateTime.now());
      });
      if (index < 0) return null;
      final claimed = {
        ...queue[index],
        'status': 'uploading',
        'claimed_at': DateTime.now().toUtc().toIso8601String(),
      };
      queue[index] = claimed;
      await _persistQueue(queue);
      _changes.add(null);
      return Map<String, dynamic>.from(claimed);
    });
  }

  Future<void> _mutateById(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) mutate,
  ) {
    return _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      final index = queue.indexWhere((action) => action['id'] == id);
      if (index < 0) return;
      queue[index] = mutate(Map<String, dynamic>.from(queue[index]));
      await _persistQueue(queue);
      _changes.add(null);
    });
  }

  Future<void> _acknowledgeAction(String id, int? revision) {
    return _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions()
        ..removeWhere((entry) => entry['id'] == id);
      for (var index = 0; index < queue.length; index++) {
        if (queue[index]['predecessor_id'] != id) continue;
        queue[index] = {
          ...queue[index],
          if (revision is int) 'expected_revision': revision,
        }..remove('predecessor_id');
      }
      await _persistQueue(queue);
      _changes.add(null);
    });
  }

  Future<void> syncForDate(String date) async {
    await syncPendingActions();
    final failures = pendingActions.where(
      (action) => action['date'] == date && action['status'] == 'failed',
    );
    if (failures.isNotEmpty) {
      throw ApiException(
        statusCode: 409,
        message: failures.first['last_error'] as String? ?? 'sync_failed',
      );
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
    Map<String, dynamic> progress, {
    String? acknowledgedId,
  }) async {
    final normalizedExercises = _getExerciseEntries(progress);
    final normalizedMeals = _getMealIds(
      progress,
    ).toSet().toList(growable: false);

    final normalized = overlayPendingProgressActions(
      progress: {
        ...progress,
        'exercises_completed': normalizedExercises,
        'meals_completed': normalizedMeals,
      },
      actions: _localStorage
          .getPendingSyncActions()
          .where((entry) => entry['id'] != acknowledgedId)
          .toList(),
      date: date,
    );
    final persistedExercises = _getExerciseEntries(normalized);
    final persistedMeals = _getMealIds(
      normalized,
    ).toSet().toList(growable: false);

    await _localStorage.cacheData('day_progress_$date', normalized);
    await _localStorage.cacheData('home_progress_$date', normalized);
    await _localStorage.cacheData(
      'completed_exercises_$date',
      persistedExercises
          .map((entry) => entry['training_exercise_id'] ?? entry['exercise_id'])
          .whereType<String>()
          .toList(growable: false),
    );
    await _localStorage.cacheData('completed_meals_$date', persistedMeals);
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

  Future<int?> _cacheProgressResponse(
    Response<dynamic> response,
    String date, {
    String? acknowledgedId,
  }) async {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      if (acknowledgedId != null) {
        throw StateError('progress_receipt_missing');
      }
      return null;
    }

    final inner = (data['data'] as Map<String, dynamic>?) ?? data;
    final revision = inner['operation_revision'] ?? inner['sync_revision'];
    if (acknowledgedId != null && revision is! int) {
      throw StateError('progress_receipt_missing');
    }
    await _localStorage.cacheData('server_progress_$date', inner);
    await _saveProgressCache(date, inner, acknowledgedId: acknowledgedId);
    return revision is int ? revision : null;
  }
}
