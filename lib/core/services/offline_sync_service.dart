import 'package:exom_app/core/utils/operation_id.dart';
import 'dart:async';
import 'package:exom_app/core/models/training_execution_discard.dart';

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

enum SyncForDateResult { confirmed, pendingSync }

enum CompletionSyncBlockerKind { failed, conflict, receiptMissing, feedbackWaiting, feedbackMissing, feedbackFailed }

class CompletionSyncBlocker {
  const CompletionSyncBlocker(this.kind, {this.retryActionId});
  final CompletionSyncBlockerKind kind;
  final String? retryActionId;
}

/// COLA: why a queued progress action is not sent yet. [ownVideo]: it waits
/// for its own last-set video (or a video its training completion depends
/// on). [behindVideo]: it is ordered behind an exercise of its own training
/// that waits for its last-set video. [behindDayVideo]: it is ordered behind
/// other same-day work waiting for a video whose training is not known to be
/// its own (actions of earlier builds without a training, a training
/// completion).
enum ProgressFeedbackWait { ownVideo, behindVideo, behindDayVideo }

/// FB1: the upload that currently stands for the last-set video [id]. A
/// failed video replaced by a new recording keeps a `replaced_by` link in the
/// (owned) upload [queue]; any reference still naming the old id, written
/// before the replacement or restored afterwards, resolves to the new one.
/// The link is written in the same queue write that adds the replacement, so
/// it holds before the queued actions are rewritten.
String resolveFeedbackReplacement(
  Iterable<Map<String, dynamic>> queue,
  String id,
) {
  final byId = <String, Map<String, dynamic>>{
    for (final row in queue)
      if (row['id'] is String) row['id'] as String: row,
  };
  final seen = <String>{id};
  var current = id;
  while (true) {
    final next = byId[current]?['replaced_by'];
    if (next is! String || !seen.add(next)) return current;
    current = next;
  }
}

/// FB1: whether a queued [reference] to an upload stands for [feedbackId]:
/// it names it, or names a video that [feedbackId] replaced (resolved
/// through the owned upload [queue], see [resolveFeedbackReplacement]).
bool feedbackReferenceIs(
  Iterable<Map<String, dynamic>> queue,
  Object? reference,
  String feedbackId,
) =>
    reference is String &&
    (reference == feedbackId ||
        resolveFeedbackReplacement(queue, reference) == feedbackId);

/// FB1: whether the queued [action] waits for the upload [feedbackId]: the
/// exercise completion sent with it (`last_set_feedback_client_upload_id`)
/// or a completion depending on it (`depends_on_feedback_ids`), directly or
/// through a video [feedbackId] replaced ([feedbackReferenceIs]).
bool actionWaitsForFeedback(
  Map<String, dynamic> action,
  String feedbackId,
  Iterable<Map<String, dynamic>> queue,
) =>
    feedbackReferenceIs(
      queue,
      action['last_set_feedback_client_upload_id'],
      feedbackId,
    ) ||
    ((action['depends_on_feedback_ids'] as List?) ?? const []).any(
      (id) => feedbackReferenceIs(queue, id, feedbackId),
    );

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
  final DateTime Function() _now;
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
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _isAuthenticated =
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

  /// Wire form of a completion time (C-O1): UTC, millisecond precision, the
  /// same text `Date.toISOString()` produces. Drafts keep milliseconds only,
  /// so a restored draft yields exactly the value first queued.
  static String completionTime(DateTime value) =>
      DateTime.fromMillisecondsSinceEpoch(
        value.millisecondsSinceEpoch,
        isUtc: true,
      ).toIso8601String();

  /// [completedAt] is when the exercise's last set was logged (C-O1). It is
  /// stored in the queued action and sent unchanged on every retry. Without
  /// it, a completion with a fresh identity is dated now (it is being created
  /// now); one replaying a frozen [operationId] stays without the field, as
  /// earlier versions sent it, so an operation the API may already have
  /// accepted keeps its body.
  Future<void> queueExerciseCompletion(
    String trainingExerciseId,
    String date, {
    required bool completed,
    String? exerciseId,
    double? weightUsed,
    List<SetPerformance>? sets,
    String? lastSetFeedbackClientUploadId,
    String? trainingId,
    String? sessionId,
    String? operationId,
    DateTime? completedAt,
  }) => _localStorage.sessionTask(() async {
    final completionAt = !completed
        ? null
        : completedAt ?? (operationId == null ? _now() : null);
    await _enqueueAction({
      'training_session_id': ?sessionId,
      'type': completed ? _markExerciseCompleted : _unmarkExerciseCompleted,
      'training_exercise_id': trainingExerciseId,
      'exercise_id': ?exerciseId,
      'date': date,
      'weight_used': ?weightUsed,
      'sets': ?sets?.map((set) => set.toJson()).toList(),
      'last_set_feedback_client_upload_id': ?lastSetFeedbackClientUploadId,
      'training_id': ?trainingId,
      if (completionAt != null) 'completed_at': completionTime(completionAt),
    }, operationId: operationId,
       isDuplicate: operationId == null ? null : (entry) => entry['id'] == operationId,
       onRetryFailedDuplicate: operationId == null ? null : (_) {});
    await _updateExerciseProgressCache(
      trainingExerciseId,
      date,
      completed: completed,
      exerciseId: exerciseId,
    );
    final feedbackQueue = lastSetFeedbackClientUploadId == null
        ? const <Map<String, dynamic>>[]
        : _localStorage.getFeedbackUploadQueue();
    final currentFeedbackId = lastSetFeedbackClientUploadId == null
        ? null
        : resolveFeedbackReplacement(
            feedbackQueue, lastSetFeedbackClientUploadId);
    if (currentFeedbackId != null &&
        feedbackQueue.any(
          (item) =>
              item['id'] == currentFeedbackId &&
              item['status'] == 'completed',
        )) {
      unawaited(syncPendingActions());
    }
  });

  Future<void> queueTrainingCompletion(
    String date, {
    required String trainingId,
    String? sessionId,
    int? rpe,
    String? notes,
  }) => _localStorage.sessionTask(() async {
    final dependencies = _localStorage
        .getFeedbackUploadQueue()
        .where(
          (item) =>
              item['training_id'] == trainingId &&
              item['assignment_date'] == date &&
              item['training_session_id'] == sessionId &&
              item['status'] != 'completed' &&
              item['replaced_by'] == null,
        )
        .map((item) => item['id'])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    var cachedNotes = notes;
    final discarded = sessionId == null ? null :
        _localStorage.getTrainingCompletionDraft(trainingId, date, sessionId)?['discarded_action'];
    final restored = discarded is Map ? Map<String, dynamic>.from(discarded) : null;
    if (restored?['last_error'] == 'progress_conflict_review_required') {
      throw StateError('Training completion requires conflict review');
    }
    final enqueued = await _enqueueAction(
      {
        'type': _completeTraining,
        'date': date,
        'training_id': trainingId,
        'training_session_id': ?sessionId,
        'rpe': ?rpe,
        // C-O1: the training is completed now; the API dates with it the
        // exercises this completion records without their own entry.
        'completed_at': completionTime(_now()),
        if (dependencies.isNotEmpty) 'depends_on_feedback_ids': dependencies,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
      isDuplicate: (action) =>
          action['type'] == _completeTraining &&
          action['date'] == date &&
          action['training_id'] == trainingId &&
          (sessionId != null
              ? action['training_session_id'] == sessionId
              : action['training_session_id'] == null &&
                  action['status'] != 'failed' &&
                  action['notes'] ==
                      (notes?.trim().isEmpty == false ? notes!.trim() : null)),
      onRetryFailedDuplicate: (action) {
        cachedNotes = action['notes'] as String?;
      },
      restoredAction: restored,
    );
    if (enqueued) {
      await _updateTrainingCompletionCache(
        date,
        trainingId: trainingId,
        notes: sessionId == null ? cachedNotes : null,
      );
    }
    if (dependencies.isNotEmpty &&
        dependencies.every(
          (id) => _localStorage.getFeedbackUploadQueue().any(
            (item) => item['id'] == id && item['status'] == 'completed',
          ),
        )) {
      unawaited(syncPendingActions());
    }
  });

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
        await _returnUnsentToQueue(id);
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
                errorData['code'] == 'PROGRESS_OPERATION_CONFLICT' ||
                errorData['code'] == 'PROGRESS_HISTORY_AMBIGUOUS');
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
          failureCode: errorData is Map && errorData['code'] is String
              ? errorData['code'] as String
              : null,
        );
      } catch (error) {
        if (_localStorage.sessionStamp != session) break;
        debugPrint(
          '[SYNC] Invalid action type=${action['type']} cause=${error.runtimeType}',
        );
        await _recordReplayFailure(
          id,
          action,
          error is StateError && error.message == 'progress_receipt_missing'
              ? 'progress_receipt_missing' : error.toString(),
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
    String? failureCode,
  }) async {
    var failedPermanently = false;
    await _mutateById(id, (current) {
      final updated = _failedOrRetriedAction(
        current,
        error,
        retryable: retryable,
        retryIndefinitely: retryIndefinitely,
        failureCode: failureCode,
      );
      failedPermanently = updated['status'] == 'failed';
      return updated;
    });
    if (failedPermanently) {
      final sessionId = action['training_session_id'] as String?;
      if (action['type'] == _completeTraining && sessionId != null) {
        await _localStorage.setTrainingExecutionStatus(sessionId,
          error == 'progress_conflict_review_required' ? 'conflict' : 'failed');
      }
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
    String? operationId,
    bool Function(Map<String, dynamic> action)? isDuplicate,
    void Function(Map<String, dynamic> action)? onRetryFailedDuplicate,
    Map<String, dynamic>? restoredAction,
  }) async {
    var enqueued = false;
    await _queueMutex.protect(() async {
      _localStorage.guardTrainingExecution(action['training_session_id'] as String?);
      final queue = _localStorage.getPendingSyncActions();
      final existingForDate = queue
          .where((entry) => entry['date'] == action['date'])
          .toList();
      if (isDuplicate != null) {
        final duplicateIndex = queue.indexWhere(
          (entry) => entry['date'] == action['date'] && isDuplicate(entry),
        );
        if (duplicateIndex >= 0) {
          final duplicate = queue[duplicateIndex];
          if (operationId != null &&
              (duplicate['type'] != action['type'] ||
               duplicate['training_exercise_id'] != action['training_exercise_id'] ||
               duplicate['date'] != action['date'])) {
            throw StateError('Completion operation identity belongs to another action');
          }
          if (duplicate['status'] == 'failed' && onRetryFailedDuplicate != null) {
            if (duplicate['last_error'] == 'progress_conflict_review_required') {
              throw StateError('Training completion requires conflict review');
            }
            onRetryFailedDuplicate(duplicate);
            queue[duplicateIndex] = {...duplicate, 'status': 'queued',
              'attempts': 0, 'last_error': null}..remove('next_attempt_at');
            await _persistQueue(queue);
            enqueued = true;
          }
          return;
        }
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
      final queued = <String, dynamic>{
        ...action,
        'expected_revision':
            _localStorage.getCachedMap(
              'day_progress_${action['date']}',
            )?['sync_revision'] ??
            0,
        if (sameDate.isNotEmpty) 'predecessor_id': sameDate.last['id'],
        ..._localStorage.queueIdentity,
        'id': operationId ?? newOperationId(),
        'status': 'queued',
        'attempts': 0,
        'queued_at': _now().toUtc().toIso8601String(),
        // A restored action keeps its identity and revision, but it is
        // appended: it links to the current end of its day, never to where
        // it stood before (COLA: only a claim writes a forward link).
        if (restoredAction != null)
          ...(Map<String, dynamic>.from(restoredAction)
            ..remove('predecessor_id')),
        if (restoredAction != null) 'status': 'queued',
      };
      // Its body is the restored one: a completion time it was queued
      // without is never added (C-O1).
      if (restoredAction != null && !restoredAction.containsKey('completed_at')) {
        queued.remove('completed_at');
      }
      // An operation id queued again (restored completion, draft operation
      // id) may still be named by entries now ahead of it.
      _releaseLinksTo(queue, queued['id'] as String);
      queue.add(queued);
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
    String? failureCode,
  }) {
    action = {...action, 'retryable': retryable};
    final attempts = (action['attempts'] as int? ?? 0) + 1;
    if (!retryable || (!retryIndefinitely && attempts >= 5)) {
      return {
        ...action,
        'status': 'failed',
        'attempts': attempts,
        'last_error': error,
        'failure_code': failureCode,
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
      'failure_code': failureCode,
      'next_attempt_at': DateTime.now()
          .toUtc()
          .add(Duration(seconds: delays[delayIndex]))
          .toIso8601String(),
    };
  }

  Future<void> removeActionsDependingOnFeedback(String feedbackId) async {
    await _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      // FB1: an action that still names a video [feedbackId] replaced waits
      // for it too, and is released with it.
      final uploads = _localStorage.getFeedbackUploadQueue();
      bool isDiscarded(Object? id) =>
          feedbackReferenceIs(uploads, id, feedbackId);
      for (var index = 0; index < queue.length; index++) {
        final action = Map<String, dynamic>.from(queue[index]);
        final dependencies =
            ((action['depends_on_feedback_ids'] as List?) ?? const [])
                .whereType<String>()
                .toList(growable: true);
        final directlyDepends =
            isDiscarded(action['last_set_feedback_client_upload_id']);
        final before = dependencies.length;
        dependencies.removeWhere(isDiscarded);
        final transitivelyDepends = dependencies.length != before;
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

  /// FB1: hands every queued reference to the replaced last-set video [from]
  /// over to its replacement [to]: the exercise completion
  /// (`last_set_feedback_client_upload_id`), the training completion
  /// (`depends_on_feedback_ids`) and the drafts of this owner. Status, ids,
  /// order and revision of the actions are untouched; none of them was sent
  /// while it depended on [from]. Idempotent; other owners' records are not
  /// visible here and stay as they are.
  Future<void> redirectFeedbackDependency(String from, String to) =>
      _localStorage.sessionTask(() async {
    var changed = false;
    await _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      for (var index = 0; index < queue.length; index++) {
        final action = queue[index];
        final dependencies =
            ((action['depends_on_feedback_ids'] as List?) ?? const [])
                .whereType<String>()
                .toList(growable: false);
        final direct = action['last_set_feedback_client_upload_id'] == from;
        if (!direct && !dependencies.contains(from)) continue;
        queue[index] = {
          ...action,
          if (direct) 'last_set_feedback_client_upload_id': to,
          if (dependencies.contains(from))
            'depends_on_feedback_ids': {
              for (final id in dependencies) id == from ? to : id,
            }.toList(growable: false),
        };
        changed = true;
      }
      if (changed) await _persistQueue(queue);
    });
    await _localStorage.replaceDraftLastSetFeedback(from, to);
    if (changed) _changes.add(null);
  });

  bool _receiptMissing(Map<String, dynamic> action) =>
      const ['progress_receipt_missing', 'Bad state: progress_receipt_missing']
          .contains(action['last_error']);

  bool _canRetryFailure(Map<String, dynamic> action) =>
      action['status'] == 'failed' &&
      action['last_error'] != 'progress_conflict_review_required' &&
      (action['retryable'] == true || _receiptMissing(action));

  Future<void> retryAction(String id) => _localStorage.withSession(() async {
    if (!_isAuthenticated()) return;
    final session = _localStorage.sessionStamp;
    await _mutateById(id, (action) {
      if (_localStorage.sessionStamp != session || !_isAuthenticated() ||
          !_localStorage.ownsEntry(action) || !_canRetryFailure(action)) {
        return action;
      }
      return {
        ...action,
        'status': 'queued',
        'attempts': 0,
      }..remove('next_attempt_at')..remove('last_error')..remove('failure_code');
    });
    if (_localStorage.sessionStamp == session && _isAuthenticated()) {
      await syncPendingActions();
    }
  });

  /// Read-only explanation for an execution-specific confirmation UI. The
  /// command rechecks everything; an eligible inspection is not a reservation.
  TrainingExecutionDiscardResult inspectTrainingExecutionDiscard(
      TrainingExecutionDiscardRequest request) {
    TrainingExecutionDiscardResult result(TrainingExecutionDiscardReason reason) =>
        TrainingExecutionDiscardResult(reason);
    if (_localStorage.ownerId == null || request.ownerId.isEmpty ||
        _localStorage.ownerId != request.ownerId) {
      return result(TrainingExecutionDiscardReason.wrongOwner);
    }
    if (_localStorage.sessionStamp != request.sessionStamp) {
      return result(TrainingExecutionDiscardReason.staleSession);
    }
    if (request.executionId.isEmpty || request.trainingId.isEmpty || request.date.isEmpty) {
      return result(TrainingExecutionDiscardReason.identityMismatch);
    }
    if (_localStorage.isTrainingExecutionDiscarded(request.executionId)) {
      final marker = _localStorage.getCachedMap(
        'training_execution_discard:${request.executionId}')!;
      return result(marker['training_id'] == request.trainingId &&
          marker['assignment_date'] == request.date
          ? TrainingExecutionDiscardReason.alreadyDiscarded
          : TrainingExecutionDiscardReason.identityMismatch);
    }
    // Namespace ownership, not a guessed legacy owner, proves registry origin.
    final entries = (_localStorage.getCachedList('training_executions') ?? const [])
        .whereType<Map>().where((entry) => entry['id'] == request.executionId).toList();
    if (entries.isEmpty) return result(TrainingExecutionDiscardReason.notFound);
    if (entries.length != 1 || entries.single['training_id'] != request.trainingId ||
        entries.single['assignment_date'] != request.date) {
      return result(TrainingExecutionDiscardReason.identityMismatch);
    }
    if (const ['confirmed', 'completed'].contains(entries.single['status'])) {
      return result(TrainingExecutionDiscardReason.confirmed);
    }
    if (!const ['pending', 'pending-finalize', 'pending-sync', 'failed', 'conflict']
        .contains(entries.single['status'])) {
      return result(TrainingExecutionDiscardReason.identityMismatch);
    }
    final rawQueue = (_localStorage.getCachedList('offline_sync_actions') ?? const [])
        .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final target = rawQueue.where((e) => e['training_session_id'] == request.executionId);
    if (target.any((e) => !_localStorage.ownsEntry(e))) {
      return result(TrainingExecutionDiscardReason.unknownOwnership);
    }
    if (target.any((e) => e['status'] == 'uploading')) {
      return result(TrainingExecutionDiscardReason.inFlight);
    }
    if (target.any((e) => e['type'] == _completeTraining &&
        (e['training_id'] != request.trainingId || e['date'] != request.date))) {
      return result(TrainingExecutionDiscardReason.identityMismatch);
    }
    // Unbound same-day exercise work cannot safely be attributed to another
    // execution. Keep it (and every file) intact and explain the refusal.
    if (rawQueue.any((e) =>
        (e['training_session_id'] == request.executionId && e['type'] != _completeTraining) ||
        (e['training_session_id'] == null && e['date'] == request.date &&
         const [_markExerciseCompleted, _unmarkExerciseCompleted].contains(e['type'])))) {
      return result(TrainingExecutionDiscardReason.unsentDependencies);
    }
    // Draft set data has no durable server receipt here. Do not hide potentially
    // unsent performance/evidence merely because its queue entry is absent.
    if (_localStorage.getActiveWorkouts().any((draft) =>
        (draft.sessionId == request.executionId ||
         (draft.sessionId == null && draft.trainingId == request.trainingId &&
          draft.exerciseId.endsWith(':${request.date}'))) &&
        (draft.completedSets > 0 || draft.completedSetData.isNotEmpty ||
         draft.completionOperationId != null || draft.lastSetFeedbackClientUploadId != null))) {
      return result(TrainingExecutionDiscardReason.unsentDependencies);
    }
    final feedback = (_localStorage.getCachedList('feedback_upload_queue') ?? const [])
        .whereType<Map>().toList();
    final dependencyIds = target.expand((e) =>
        ((e['depends_on_feedback_ids'] as List?) ?? const []).whereType<String>()).toSet();
    if (feedback.any((e) => e['status'] != 'completed' &&
        (e['training_session_id'] == request.executionId ||
         dependencyIds.contains(e['id']) ||
         (e['training_session_id'] == null && e['assignment_date'] == request.date &&
          (e['training_id'] == request.trainingId || e['training_id'] == null)))) ||
        dependencyIds.any((id) => !feedback.any((e) => e['id'] == id &&
            e['status'] == 'completed' && _localStorage.ownsEntry(Map<String, dynamic>.from(e))))) {
      return result(TrainingExecutionDiscardReason.unsentDependencies);
    }
    return result(TrainingExecutionDiscardReason.eligible);
  }

  /// Explicit LOCAL discard only. Never calls HTTP, generic discardAction,
  /// cache rebasing, evidence cleanup or same-day invalidation.
  Future<TrainingExecutionDiscardResult> discardTrainingExecution(
      TrainingExecutionDiscardRequest request) async {
    final initial = inspectTrainingExecutionDiscard(request);
    if (!initial.canDiscard) return initial; // in-flight refusal must not wait
    try {
      return await _localStorage.sessionTask(() => _syncMutex.protect(() =>
          _queueMutex.protect(() async {
        final checked = inspectTrainingExecutionDiscard(request);
        if (!checked.canDiscard) return checked;
        await _localStorage.persistTrainingExecutionDiscard(request);
        _changes.add(null);
        return const TrainingExecutionDiscardResult(TrainingExecutionDiscardReason.discarded);
      })));
    } on LocalSessionChanged {
      return const TrainingExecutionDiscardResult(TrainingExecutionDiscardReason.staleSession);
    } catch (_) {
      return const TrainingExecutionDiscardResult(TrainingExecutionDiscardReason.storageFailure);
    }
  }

  Future<void> discardAction(String id) => _localStorage.withSession(() async {
    String? date;
    await _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      final index = queue.indexWhere((entry) => entry['id'] == id);
      if (index < 0 || queue[index]['status'] == 'uploading') return;
      date = queue[index]['date'] as String?;
      final discarded = queue[index];
      if (discarded['type'] == _completeTraining &&
          discarded['training_session_id'] is String) {
        await _localStorage.preserveDiscardedTrainingCompletion(discarded);
        await _localStorage.setTrainingExecutionStatus(
          discarded['training_session_id'] as String,
          discarded['last_error'] == 'progress_conflict_review_required'
              ? 'conflict' : 'failed');
      }
      // COLA (E): an action proven never sent (held by a video that was never
      // confirmed) left the server revision untouched; deleting it does not
      // turn the rest of the day into conflicts. The server still answers
      // 409 if that proof were wrong.
      final neverSent = _videoHeldOfDay(
        queue,
        discarded,
        _localStorage.getFeedbackUploadQueue(),
      ).contains(id);
      queue.removeAt(index);
      for (var i = index; i < queue.length && !neverSent; i++) {
        if (queue[i]['date'] == date &&
            !_isIndependentOfRejectedHistory(discarded, queue[i])) {
          queue[i] = {
            ...queue[i],
            'status': 'failed',
            'last_error': 'progress_conflict_review_required',
          };
        }
      }
      // COLA: no entry keeps naming the deleted action. Its id may be queued
      // again (restored completion), and a link to it would then read as an
      // overtaking record.
      _releaseLinksTo(queue, id);
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
    _localStorage.guardTrainingExecution(action['training_session_id'] as String?);
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
    // A replaced video counts through its replacement (FB1).
    bool confirmed(String id) {
      final current = resolveFeedbackReplacement(feedbackQueue, id);
      return feedbackQueue.any(
        (item) => item['id'] == current && item['status'] == 'completed',
      );
    }

    if (dependencies.any((id) => !confirmed(id))) {
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
        final queuedFeedbackId =
            action['last_set_feedback_client_upload_id'] as String?;
        final feedbackId = queuedFeedbackId == null
            ? null
            : resolveFeedbackReplacement(feedbackQueue, queuedFeedbackId);
        if (feedbackId != null && !confirmed(feedbackId)) {
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
            if (action['training_session_id'] != null)
              'training_session_id': action['training_session_id'],
            if (action['weight_used'] != null)
              'weight_used': action['weight_used'],
            'sets': ?sets,
            'last_set_feedback_client_upload_id': ?feedbackId,
            // Only an action queued with it (C-O1): never derived here.
            if (action['completed_at'] is String)
              'completed_at': action['completed_at'],
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
          queryParameters: {
            'date': date,
            if (action['training_session_id'] != null)
              'training_session_id': action['training_session_id'],
          },
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
            if (action['training_session_id'] != null)
              'training_session_id': action['training_session_id'],
            if (action['rpe'] != null) 'rpe': action['rpe'],
            if (action['notes'] != null)
              if (action['training_session_id'] != null)
                'session_note': action['notes']
              else
                'notes': action['notes'],
            if (action['completed_at'] is String)
              'completed_at': action['completed_at'],
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

  /// Every `/progress/exercises/complete` request is built here, so this is
  /// where legacy sets are repaired on read. A set that is not registered
  /// ([isRegisteredSetJson]: a RIR-only set from drafts of earlier versions)
  /// is rejected by the API with a non-retryable 400; it is left out of the
  /// request while the queued action keeps it as written.
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
        .where(isRegisteredSetJson)
        .toList(growable: false);
  }

  bool hasPendingFeedbackForTraining(String trainingId, String date) {
    return _localStorage.getFeedbackUploadQueue().any(
      (item) =>
          item['training_id'] == trainingId &&
          item['assignment_date'] == date &&
          item['status'] != 'completed' &&
          item['replaced_by'] == null,
    );
  }

  // A history-ambiguous rejection has no server write. It only releases an
  // operation for another known execution; the day-wide revision stays intact.
  bool _isIndependentOfRejectedHistory(
    Map<String, dynamic> prior,
    Map<String, dynamic> candidate,
  ) {
    final priorSession = prior['training_session_id'];
    final candidateSession = candidate['training_session_id'];
    return prior['status'] == 'failed' &&
        prior['failure_code'] == 'PROGRESS_HISTORY_AMBIGUOUS' &&
        prior['last_error'] == 'progress_conflict_review_required' &&
        priorSession is String && priorSession.isNotEmpty &&
        candidateSession is String && candidateSession.isNotEmpty &&
        priorSession != candidateSession;
  }

  Iterable<Map<String, dynamic>> _orderedPredecessors(
    List<Map<String, dynamic>> queue, Map<String, dynamic> candidate,
  ) => candidate['format_version'] != 2 ? const [] : queue
      .takeWhile((entry) => entry['id'] != candidate['id'])
      .where((entry) => _localStorage.ownsEntry(entry) &&
          entry['date'] == candidate['date'] &&
          !_isIndependentOfRejectedHistory(entry, candidate));

  // ---------------------------------------------------------------------------
  // COLA: same-day work held by a video does not hold independent work.
  //
  // The API keeps one revision per (client, date), so the actions of a day are
  // replayed as a chain. An action waiting for an unconfirmed last-set video
  // (or a training completion depending on one) is refused by the replay
  // before any HTTP, and feedback confirmation is terminal, so while the
  // reference is unconfirmed the action provably never reached the server.
  // A later, independent action of the same day may then overtake it. The
  // overtaking is recorded durably, in the same queue write as the claim, by
  // pointing the `predecessor_id` of every passed action to the overtaker
  // (an existing field; an "inverted" link names a later queue entry). Passed
  // actions wait for the overtaker until it is acknowledged, whatever happens
  // to their video meanwhile (lost response, crash, account switch); the
  // acknowledgement hands the confirmed revision to them and rebuilds the
  // day chain in queue order, in one write. No field or format is added.
  // ---------------------------------------------------------------------------

  /// Same rule as [_replayAction]: a dependency or the last-set video of an
  /// exercise completion that is not confirmed (through its replacement).
  bool _waitsForFeedback(
    Map<String, dynamic> action,
    List<Map<String, dynamic>> feedback,
  ) {
    bool confirmed(String id) {
      final current = resolveFeedbackReplacement(feedback, id);
      return feedback.any(
        (item) => item['id'] == current && item['status'] == 'completed',
      );
    }

    final dependencies =
        ((action['depends_on_feedback_ids'] as List?) ?? const [])
            .whereType<String>();
    if (dependencies.any((id) => !confirmed(id))) return true;
    final lastSet = action['last_set_feedback_client_upload_id'];
    return action['type'] == _markExerciseCompleted &&
        lastSet is String &&
        !confirmed(lastSet);
  }

  /// Every unconfirmed reference of [action] names an upload that is still
  /// in this owner's queue and not confirmed: it is waiting, not lost.
  bool _waitsForPresentFeedback(
    Map<String, dynamic> action,
    List<Map<String, dynamic>> feedback,
  ) {
    if (!_waitsForFeedback(action, feedback)) return false;
    final references = <String>[
      ...((action['depends_on_feedback_ids'] as List?) ?? const [])
          .whereType<String>(),
      if (action['type'] == _markExerciseCompleted &&
          action['last_set_feedback_client_upload_id'] is String)
        action['last_set_feedback_client_upload_id'] as String,
    ];
    return references.every((reference) {
      final current = resolveFeedbackReplacement(feedback, reference);
      return feedback.any((item) => item['id'] == current);
    });
  }

  bool _neverAttempted(Map<String, dynamic> action) {
    final attempts = action['attempts'];
    return attempts == null || attempts == 0;
  }

  /// Provably never sent because of a video of its own: queued and waiting
  /// for an upload still pending or failed, or failed only because that
  /// unconfirmed upload was discarded (`feedback_discarded`, written solely
  /// by [removeActionsDependingOnFeedback] for unconfirmed uploads).
  bool _heldByOwnVideo(
    Map<String, dynamic> action,
    List<Map<String, dynamic>> feedback,
  ) {
    if (!_neverAttempted(action)) return false;
    if (action['status'] == 'failed') {
      return action['last_error'] == 'feedback_discarded';
    }
    return action['status'] == 'queued' &&
        _waitsForPresentFeedback(action, feedback);
  }

  static const _exerciseOrTrainingTypes = {
    _markExerciseCompleted,
    _unmarkExerciseCompleted,
    _completeTraining,
  };
  static const _mealTypes = {_markMealCompleted, _unmarkMealCompleted};

  /// Whether the server result of [candidate] cannot depend on [prior] of the
  /// same day, so their order is free. Meals never depend on training work;
  /// training work only when both name different trainings (and different
  /// executions and exercises). Anything not provable (legacy actions without
  /// a training, unknown types, the same training) keeps the strict order.
  bool _independentOf(
    Map<String, dynamic> candidate,
    Map<String, dynamic> prior,
  ) {
    final candidateType = candidate['type'];
    final priorType = prior['type'];
    if (_mealTypes.contains(priorType)) {
      return _exerciseOrTrainingTypes.contains(candidateType) ||
          (_mealTypes.contains(candidateType) &&
              candidate['meal_id'] is String &&
              prior['meal_id'] is String &&
              candidate['meal_id'] != prior['meal_id']);
    }
    if (!_exerciseOrTrainingTypes.contains(priorType)) return false;
    if (_mealTypes.contains(candidateType)) return true;
    if (!_exerciseOrTrainingTypes.contains(candidateType)) return false;
    final priorTraining = prior['training_id'];
    final candidateTraining = candidate['training_id'];
    if (priorTraining is! String ||
        priorTraining.isEmpty ||
        candidateTraining is! String ||
        candidateTraining.isEmpty ||
        priorTraining == candidateTraining) {
      return false;
    }
    final priorSession = prior['training_session_id'];
    if (priorSession is String &&
        priorSession.isNotEmpty &&
        priorSession == candidate['training_session_id']) {
      return false;
    }
    final priorExercise = prior['training_exercise_id'];
    return !(priorExercise is String &&
        priorExercise == candidate['training_exercise_id']);
  }

  /// Ids of the owned actions of [reference]'s day that provably never
  /// reached the server and wait for a video: held by their own video
  /// ([_heldByOwnVideo]), or queued, never attempted and ordered behind such
  /// an action they depend on (so no rule ever let them be claimed).
  ///
  /// One pass over the queue (R4): the held actions found so far are exactly
  /// the held [_orderedPredecessors] of the current entry (same owner and
  /// day, earlier in the queue; a held action is never a history-ambiguous
  /// rejection), so only they are compared.
  Set<String> _videoHeldOfDay(
    List<Map<String, dynamic>> queue,
    Map<String, dynamic> reference,
    List<Map<String, dynamic>> feedback,
  ) {
    final held = <String>{};
    final heldEntries = <Map<String, dynamic>>[];
    for (final entry in queue) {
      final id = entry['id'];
      if (id is! String ||
          entry['format_version'] != 2 ||
          entry['date'] != reference['date'] ||
          !_localStorage.ownsEntry(entry)) {
        continue;
      }
      if (_heldByOwnVideo(entry, feedback) ||
          (entry['status'] == 'queued' &&
              _neverAttempted(entry) &&
              heldEntries.any((prior) => !_independentOf(entry, prior)))) {
        held.add(id);
        heldEntries.add(entry);
      }
    }
    return held;
  }

  /// COLA r2: [passed] names the later [overtaker] because a claim recorded
  /// an overtaking. A claim only passes actions that were never attempted,
  /// are queued (or failed only because their video was discarded) and are
  /// independent of it, and they stay so until the overtaker is
  /// acknowledged. Any other link to a later entry keeps the strict order.
  bool _recordsOvertaking(
    Map<String, dynamic> passed,
    Map<String, dynamic> overtaker,
  ) =>
      passed['predecessor_id'] == overtaker['id'] &&
      _neverAttempted(passed) &&
      (passed['status'] == 'queued' ||
          (passed['status'] == 'failed' &&
              passed['last_error'] == 'feedback_discarded')) &&
      _independentOf(overtaker, passed);

  /// COLA r2: only a claim writes a link to a later entry. Entries still
  /// naming [id] (deleted, or about to be appended again with the same
  /// operation id) get the link [_enqueueAction] writes: the previous entry
  /// of their day, or none.
  void _releaseLinksTo(List<Map<String, dynamic>> queue, String id) {
    for (var index = 0; index < queue.length; index++) {
      final entry = queue[index];
      if (entry['predecessor_id'] != id) continue;
      final previous = queue
          .take(index)
          .where(
            (prior) =>
                prior['date'] == entry['date'] && prior['format_version'] == 2,
          )
          .lastOrNull;
      queue[index] = previous == null
          ? (Map<String, dynamic>.from(entry)..remove('predecessor_id'))
          : {...entry, 'predecessor_id': previous['id']};
    }
  }

  /// The later entry that overtook [candidate] and is not acknowledged yet:
  /// an inverted `predecessor_id` link (see the section comment).
  Map<String, dynamic>? _overtakerOf(
    List<Map<String, dynamic>> queue,
    Map<String, dynamic> candidate,
  ) {
    final link = candidate['predecessor_id'];
    if (link is! String) return null;
    final index = queue.indexWhere((entry) => entry['id'] == candidate['id']);
    if (index < 0) return null;
    return queue.skip(index + 1).where((later) =>
        later['id'] == link &&
        later['date'] == candidate['date'] &&
        _localStorage.ownsEntry(later) &&
        _recordsOvertaking(candidate, later)).firstOrNull;
  }

  /// The head-of-day rule ([_orderedPredecessors]) minus the video-held
  /// actions [candidate] may overtake, plus the overtaker [candidate] waits
  /// for. [candidate] overtakes only when it is sendable itself, independent
  /// of what it passes and based on the same day revision (otherwise the
  /// strict order keeps surfacing a real conflict as a 409, as before).
  ///
  /// Lazy, in queue order with the overtaker last (R4): a claim only asks
  /// whether there is any blocker and stops at the first one. [heldByDate]
  /// lets one claim pass reuse the video-held set of a day, which depends
  /// only on the queue, the feedback queue and the date.
  Iterable<Map<String, dynamic>> _blockingPredecessors(
    List<Map<String, dynamic>> queue,
    Map<String, dynamic> candidate,
    List<Map<String, dynamic>> feedback, [
    Map<Object?, Set<String>>? heldByDate,
  ]) sync* {
    if (candidate['format_version'] != 2) return;
    final revision = candidate['expected_revision'];
    bool? waits;
    Set<String>? held;
    for (final prior in _orderedPredecessors(queue, candidate)) {
      if (_recordsOvertaking(prior, candidate)) continue;
      // Nothing is passed by a candidate that waits for a video itself.
      waits ??= _waitsForFeedback(candidate, feedback);
      if (!waits) {
        held ??= heldByDate == null
            ? _videoHeldOfDay(queue, candidate, feedback)
            : heldByDate.putIfAbsent(
                candidate['date'],
                () => _videoHeldOfDay(queue, candidate, feedback),
              );
        if (held.contains(prior['id']) &&
            revision is int &&
            prior['expected_revision'] == revision &&
            _independentOf(candidate, prior)) {
          continue;
        }
      }
      yield prior;
    }
    final overtaker = _overtakerOf(queue, candidate);
    if (overtaker != null) yield overtaker;
  }

  /// Rebuilds the day chain of [date] in queue order: each owned entry names
  /// the previous one, as [_enqueueAction] writes it, so an older build
  /// replaying this queue strictly still propagates revisions coherently.
  void _relinkDay(List<Map<String, dynamic>> queue, Object? date) {
    String? previous;
    for (var index = 0; index < queue.length; index++) {
      final entry = queue[index];
      if (entry['date'] != date ||
          entry['format_version'] != 2 ||
          !_localStorage.ownsEntry(entry)) {
        continue;
      }
      queue[index] = previous == null
          ? (Map<String, dynamic>.from(entry)..remove('predecessor_id'))
          : {...entry, 'predecessor_id': previous};
      previous = entry['id'] as String?;
    }
  }

  bool _overtookAny(List<Map<String, dynamic>> queue, String id) {
    final index = queue.indexWhere((entry) => entry['id'] == id);
    return index > 0 &&
        queue
            .take(index)
            .any((entry) => _recordsOvertaking(entry, queue[index]));
  }

  /// A claimed action that turned out not sendable goes back to the queue,
  /// releasing in the same write anything recorded as passed by it.
  Future<void> _returnUnsentToQueue(String id) async {
    await _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      final index = queue.indexWhere((action) => action['id'] == id);
      if (index < 0) return;
      queue[index] = {...queue[index], 'status': 'queued'};
      if (_overtookAny(queue, id)) _relinkDay(queue, queue[index]['date']);
      await _persistQueue(queue);
    });
    _changes.add(null);
  }

  /// COLA (A): why the queued [action] is not sent yet, for the UI.
  ProgressFeedbackWait? feedbackWaitOf(Map<String, dynamic> action) {
    if (action['status'] != 'queued' || !_localStorage.ownsEntry(action)) {
      return null;
    }
    final feedback = _localStorage.getFeedbackUploadQueue();
    if (_waitsForPresentFeedback(action, feedback)) {
      return ProgressFeedbackWait.ownVideo;
    }
    if (action['format_version'] != 2) return null;
    final queue = pendingActions;
    final held = _videoHeldOfDay(queue, action, feedback);
    if (!held.contains(action['id'])) return null;
    final training = action['training_id'];
    final behindOwnTraining = training is String &&
        training.isNotEmpty &&
        _orderedPredecessors(queue, action).any(
          (prior) =>
              held.contains(prior['id']) &&
              prior['type'] == _markExerciseCompleted &&
              prior['training_id'] == training &&
              _heldByOwnVideo(prior, feedback),
        );
    return behindOwnTraining
        ? ProgressFeedbackWait.behindVideo
        : ProgressFeedbackWait.behindDayVideo;
  }

  /// Read-only diagnosis uses precisely the replay head-of-day rule
  /// ([_blockingPredecessors]). Feedback completion proves only its
  /// dependency, never a training acknowledgement.
  CompletionSyncBlocker? completionBlocker(
    String trainingId, String date, String? sessionId,
  ) {
    final queue = pendingActions.where(_localStorage.ownsEntry).toList();
    final completion = queue.where((entry) =>
        entry['type'] == _completeTraining && entry['training_id'] == trainingId &&
        entry['date'] == date && entry['training_session_id'] == sessionId).firstOrNull;
    if (completion == null || completion['format_version'] != 2) return null;
    final blockers = _blockingPredecessors(
      queue,
      completion,
      _localStorage.getFeedbackUploadQueue(),
    );
    for (final action in [...blockers, completion]) {
      if (action['last_error'] == 'progress_conflict_review_required') {
        return const CompletionSyncBlocker(CompletionSyncBlockerKind.conflict);
      }
      if (action['status'] == 'failed') {
        return CompletionSyncBlocker(
          _receiptMissing(action) ? CompletionSyncBlockerKind.receiptMissing
              : CompletionSyncBlockerKind.failed,
          retryActionId: _canRetryFailure(action) ? action['id'] as String? : null);
      }
      final dependencies = <String>{
        ...((action['depends_on_feedback_ids'] as List?) ?? const []).whereType<String>(),
        if (action['last_set_feedback_client_upload_id'] is String)
          action['last_set_feedback_client_upload_id'] as String,
      };
      if (dependencies.isEmpty) continue;
      final feedback = _localStorage.getFeedbackUploadQueue();
      for (final queuedId in dependencies) {
        final id = resolveFeedbackReplacement(feedback, queuedId);
        final row = feedback.where((item) => item['id'] == id).firstOrNull;
        if (row == null) {
          return const CompletionSyncBlocker(CompletionSyncBlockerKind.feedbackMissing);
        }
        if (row['status'] == 'failed') {
          return const CompletionSyncBlocker(CompletionSyncBlockerKind.feedbackFailed);
        }
        if (row['status'] != 'completed') {
          return const CompletionSyncBlocker(CompletionSyncBlockerKind.feedbackWaiting);
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _claimNextAction(Set<String> excludedIds) {
    return _queueMutex.protect(() async {
      final queue = _localStorage.getPendingSyncActions();
      final feedback = _localStorage.getFeedbackUploadQueue();
      final heldByDate = <Object?, Set<String>>{};
      final index = queue.indexWhere((action) {
        if (!_localStorage.ownsEntry(action)) return false;
        if (excludedIds.contains(action['id'])) return false;
        if (action['status'] != 'queued') return false;
        if (_blockingPredecessors(queue, action, feedback, heldByDate)
            .isNotEmpty) {
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
      // COLA: with no blocker left, every ordered predecessor is a video-held
      // action this one overtakes (or already overtook). Record it in this
      // same write, before anything can reach the server.
      for (final prior in _orderedPredecessors(queue, claimed).toList()) {
        final priorIndex = queue.indexOf(prior);
        if (priorIndex < 0 || prior['predecessor_id'] == claimed['id']) {
          continue;
        }
        queue[priorIndex] = {...prior, 'predecessor_id': claimed['id']};
      }
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
      final queue = _localStorage.getPendingSyncActions();
      final acknowledged = queue.where((entry) => entry['id'] == id).firstOrNull;
      if (acknowledged?['type'] == _completeTraining &&
          acknowledged?['training_session_id'] is String) {
        await _localStorage.completeTrainingExecution(
          acknowledged!['training_session_id'] as String);
      }
      // COLA: actions this one overtook sit before it in the queue and name
      // it. They were based on the same revision it was sent with; only then
      // do they inherit the confirmed one (otherwise their 409 stays due).
      // Every later action of the day is sent after this one, so it gets the
      // confirmed revision now rather than when its own predecessor is
      // confirmed: the value each one is finally sent with is the same, and
      // a later action can compare revisions with what it overtakes.
      final position = queue.indexWhere((entry) => entry['id'] == id);
      final overtook = position >= 0 && _overtookAny(queue, id);
      final sentRevision = acknowledged?['expected_revision'];
      queue.removeWhere((entry) => entry['id'] == id);
      for (var index = 0; index < queue.length; index++) {
        final entry = queue[index];
        final passed = index < position && entry['predecessor_id'] == id;
        final later = position >= 0 &&
            index >= position &&
            entry['date'] == acknowledged?['date'] &&
            entry['format_version'] == 2 &&
            _localStorage.ownsEntry(entry);
        if (entry['predecessor_id'] != id && !later) continue;
        final persistedRevision = entry['expected_revision'];
        queue[index] = {
          ...entry,
          if (revision is int &&
              (passed
                  ? (persistedRevision is int &&
                      persistedRevision == sentRevision &&
                      persistedRevision < revision)
                  : (persistedRevision is! int ||
                      persistedRevision < revision)))
            'expected_revision': revision,
        };
        if (entry['predecessor_id'] == id) {
          queue[index].remove('predecessor_id');
        }
      }
      if (overtook) _relinkDay(queue, acknowledged?['date']);
      await _persistQueue(queue);
      _changes.add(null);
    });
  }

  Future<SyncForDateResult> syncForDate(String date, {String? sessionId}) async {
    await syncPendingActions();
    final relevant = pendingActions.where(
      (action) =>
          action['date'] == date &&
          !(sessionId != null &&
              _isIndependentOfRejectedHistory(action, {
                'training_session_id': sessionId,
              })),
    );
    final failures = relevant.where((action) => action['status'] == 'failed');
    if (failures.isNotEmpty) {
      throw ApiException(
        statusCode: 409,
        message: failures.first['last_error'] as String? ?? 'sync_failed',
      );
    }
    return relevant.isEmpty
        ? SyncForDateResult.confirmed
        : SyncForDateResult.pendingSync;
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
    final receiptRevision = inner['operation_revision'] ?? inner['sync_revision'];
    if (acknowledgedId != null && receiptRevision is! int) {
      throw StateError('progress_receipt_missing');
    }
    final responseRevision = inner['sync_revision'] is int
        ? inner['sync_revision'] as int
        : inner['operation_revision'];
    final server = _localStorage.getCachedMap('server_progress_$date');
    final day = _localStorage.getCachedMap('day_progress_$date');
    Map<String, dynamic>? confirmed;
    int? confirmedRevision;
    for (final candidate in [server, day]) {
      if (candidate?['date'] != date) continue;
      final revision = candidate?['sync_revision'];
      if (revision is int &&
          (confirmedRevision == null || revision > confirmedRevision)) {
        confirmed = candidate;
        confirmedRevision = revision;
      }
    }
    if (confirmed != null &&
        (responseRevision is! int || confirmedRevision! > responseRevision)) {
      // Keep the newer snapshot, but advance the queue using this operation's receipt.
      return receiptRevision is int ? receiptRevision : null;
    }
    await _localStorage.cacheData('server_progress_$date', inner);
    await _saveProgressCache(date, inner, acknowledgedId: acknowledgedId);
    return receiptRevision is int ? receiptRevision : null;
  }
}
