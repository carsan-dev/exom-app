import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/models/training_execution_discard.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late LocalAuthSession? current;
  late LocalStorage storage;
  late OfflineSyncService service;
  late TrainingExecutionDiscardRequest request;
  late int httpCalls;
  late ApiClient client;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-discard-test-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
      Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
    }
    await Hive.openBox('cache_box');
    await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
    current = const LocalAuthSession(uid: 'A', generation: 1);
    storage = LocalStorage(currentSession: () => current);
    httpCalls = 0;
    client = ApiClient(baseUrl: 'https://api.exom.test', useAuth: false);
    client.dio.interceptors.clear();
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      httpCalls++;
      handler.resolve(Response(requestOptions: options, statusCode: 200,
        data: {'operation_revision': 1, 'sync_revision': 1}));
    }));
    service = OfflineSyncService(client, storage, isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    request = TrainingExecutionDiscardRequest(ownerId: 'A',
      sessionStamp: storage.sessionStamp!, executionId: 'target',
      trainingId: 'training', date: '2026-09-05');
    await storage.cacheData('training_executions', [
      {'id': 'target', 'training_id': 'training',
        'assignment_date': request.date, 'status': 'failed'},
      {'id': 'confirmed', 'training_id': 'training',
        'assignment_date': request.date, 'status': 'confirmed'},
      {'id': 'other', 'training_id': 'training',
        'assignment_date': request.date, 'status': 'pending'},
    ]);
    await storage.saveTrainingCompletionDraft('training', request.date, 'target', notes: 'local');
    await storage.savePendingSyncActions([
      {'id': 'closure', ...storage.queueIdentity, 'type': 'complete_training',
        'training_id': 'training', 'training_session_id': 'target',
        'date': request.date, 'status': 'failed', 'expected_revision': 4,
        'last_error': 'progress_conflict_review_required'},
      {'id': 'other-action', ...storage.queueIdentity, 'type': 'complete_training',
        'training_id': 'training', 'training_session_id': 'other',
        'date': request.date, 'status': 'failed', 'expected_revision': 4,
        'predecessor_id': 'closure'},
    ]);
  });

  tearDown(() async {
    await service.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('explicit discard hides only target, preserves raw queue and evidence, survives reopen', () async {
    final rawQueue = jsonEncode(storage.getCachedList('offline_sync_actions'));
    final other = jsonEncode(storage.getPendingSyncActions().last);
    final file = File('${directory.path}/pending-evidence')..writeAsStringSync('bytes');
    await storage.saveFeedbackUploadQueue([
      {'id': 'independent', ...storage.queueIdentity, 'training_session_id': 'other',
        'status': 'queued', 'local_path': file.path},
    ]);
    final workout = ActiveWorkoutHiveModel(trainingId: 'training', sessionId: 'target',
      exerciseId: 'exercise:${request.date}:target', currentSet: 1, completedSets: 0);
    await storage.saveActiveWorkout(workout);
    expect(service.inspectTrainingExecutionDiscard(request).canDiscard, isTrue);
    expect((await service.discardTrainingExecution(request)).reason,
      TrainingExecutionDiscardReason.discarded);
    expect(storage.getPendingTrainingExecutions().map((e) => e['id']), ['other']);
    expect(storage.getConfirmedTrainingExecutions('training', request.date).single['id'], 'confirmed');
    expect(storage.getTrainingCompletionDraft('training', request.date, 'target'), isNull);
    expect(storage.getActiveWorkout(workout.exerciseId), isNull);
    expect(storage.getActiveWorkouts(), isEmpty);
    expect(() => storage.saveActiveWorkout(workout), throwsStateError);
    expect(jsonEncode(storage.getPendingSyncActions().single), other);
    expect(jsonEncode(storage.getCachedList('offline_sync_actions')), rawQueue);
    expect(file.readAsStringSync(), 'bytes');
    expect(storage.getFeedbackUploadQueue(), hasLength(1));
    expect(httpCalls, 0);
    expect(() => storage.saveFeedbackUploadQueue([
      ...storage.getFeedbackUploadQueue(),
      {'id': 'late-target-evidence', ...storage.queueIdentity,
        'training_session_id': 'target', 'status': 'queued'},
    ]), throwsStateError);
    expect(storage.getFeedbackUploadQueue(), hasLength(1));
    await Hive.close();
    await Hive.openBox('cache_box');
    await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
    expect(storage.getPendingSyncActions().single['id'], 'other-action');
    expect(service.completionBlocker('training', request.date, 'target'), isNull);
    await service.syncPendingActions();
    expect(httpCalls, 0);
    expect(storage.getPendingTrainingExecutions().map((e) => e['id']), ['other']);
    expect((await service.discardTrainingExecution(request)).reason,
      TrainingExecutionDiscardReason.alreadyDiscarded);
    await expectLater(service.queueTrainingCompletion(request.date,
      trainingId: 'training', sessionId: 'target'), throwsStateError);
    await expectLater(service.queueExerciseCompletion('exercise', request.date,
      completed: true, sessionId: 'target'), throwsStateError);
    expect(httpCalls, 0);
  });

  test('discarded raw closure survives unrelated enqueue and acknowledgement', () async {
    final queue = storage.getPendingSyncActions();
    queue.first.addAll({
      'operation_id': 'retained-operation',
      'operation_revision': 7,
      'attempts': 3,
      'failure_metadata': {'code': 'conflict', 'revisions': [4, 7]},
    });
    await storage.savePendingSyncActions(queue);
    final rawClosure = jsonEncode(queue.first);
    expect((await service.discardTrainingExecution(request)).reason,
      TrainingExecutionDiscardReason.discarded);

    final foreign = {'id': 'foreign', ...storage.queueIdentity,
      'owner_id': 'B', 'type': 'complete_training',
      'training_session_id': 'target', 'status': 'failed'};
    final unowned = {'id': 'unowned', 'type': 'mark_meal_completed'};
    await storage.cacheData('offline_sync_actions', [
      ...storage.getCachedList('offline_sync_actions')!, foreign, unowned,
    ]);
    final foreignBytes = jsonEncode(foreign);
    final unownedBytes = jsonEncode(unowned);
    void expectRetained() {
      final raw = storage.getCachedList('offline_sync_actions')!.whereType<Map>();
      expect(jsonEncode(raw.singleWhere((e) => e['id'] == 'closure')), rawClosure);
      expect(jsonEncode(raw.singleWhere((e) => e['id'] == 'foreign')), foreignBytes);
      expect(jsonEncode(raw.singleWhere((e) => e['id'] == 'unowned')), unownedBytes);
      expect(storage.getPendingSyncActions().any((e) => e['id'] == 'closure'), isFalse);
    }

    await storage.savePendingSyncActions([
      ...storage.getPendingSyncActions(),
      {'id': 'unrelated', ...storage.queueIdentity,
        'operation_id': 'unrelated-operation', 'type': 'mark_meal_completed',
        'meal_id': 'meal', 'date': '2026-09-06', 'status': 'queued'},
    ]);
    expectRetained();
    expect(storage.getPendingSyncActions().map((e) => e['id']),
      ['other-action', 'unrelated']);
    await service.syncPendingActions();
    expect(httpCalls, 1);
    expect(storage.getPendingSyncActions().single['id'], 'other-action');
    expectRetained();

    await Hive.close();
    await Hive.openBox('cache_box');
    await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
    expectRetained();
    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(storage.getPendingSyncActions(), isEmpty);
    expect(storage.isTrainingExecutionDiscarded('target'), isFalse);
    await storage.savePendingSyncActions([]);
    current = const LocalAuthSession(uid: 'A', generation: 1);
    expectRetained();
    expect((await service.discardTrainingExecution(request)).reason,
      TrainingExecutionDiscardReason.alreadyDiscarded);
    await service.syncPendingActions();
    expect(httpCalls, 1);
    expectRetained();
    await storage.clearPendingSyncActions();
    await storage.clearPendingSyncActions();
    expect(storage.getPendingSyncActions(), isEmpty);
    expectRetained();
    expect(() => storage.savePendingSyncActions([queue.first]), throwsStateError);
    expectRetained();
  });

  test('wrong owner and stale generation are rejected without writes', () async {
    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect((await service.discardTrainingExecution(request)).reason,
      TrainingExecutionDiscardReason.wrongOwner);
    current = const LocalAuthSession(uid: 'A', generation: 3);
    expect((await service.discardTrainingExecution(request)).reason,
      TrainingExecutionDiscardReason.staleSession);
    expect(storage.getPendingSyncActions(), hasLength(2));
  });

  test('confirmed target cannot be discarded', () async {
    final confirmed = TrainingExecutionDiscardRequest(ownerId: 'A',
      sessionStamp: storage.sessionStamp!, executionId: 'confirmed',
      trainingId: 'training', date: request.date);
    expect((await service.discardTrainingExecution(confirmed)).reason,
      TrainingExecutionDiscardReason.confirmed);
  });

  test('unknown legacy closure ownership fails closed', () async {
    await storage.cacheData('offline_sync_actions', [
      {'id': 'legacy', 'type': 'complete_training', 'training_session_id': 'target',
        'training_id': 'training', 'date': request.date, 'status': 'failed'},
    ]);
    expect((await service.discardTrainingExecution(request)).reason,
      TrainingExecutionDiscardReason.unknownOwnership);
  });

  for (final kind in ['exercise', 'evidence', 'legacy-exercise']) {
    test('blocks unsent $kind dependency without deleting anything', () async {
      if (kind == 'evidence') {
        await storage.saveFeedbackUploadQueue([
          {'id': 'evidence', ...storage.queueIdentity, 'training_session_id': 'target',
            'status': 'queued'},
        ]);
      } else {
        await storage.savePendingSyncActions([
          ...storage.getPendingSyncActions(),
          {'id': 'exercise', ...storage.queueIdentity, 'type': 'mark_exercise_completed',
            if (kind != 'legacy-exercise') 'training_session_id': 'target',
            'date': request.date, 'status': 'failed'},
        ]);
      }
      expect((await service.discardTrainingExecution(request)).reason,
        TrainingExecutionDiscardReason.unsentDependencies);
      expect(storage.getTrainingCompletionDraft('training', request.date, 'target'), isNotNull);
      expect(httpCalls, 0);
    });
  }

  test('in-flight HTTP barrier refuses discard rather than waiting and deleting', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    client.dio.interceptors.clear();
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      started.complete();
      await release.future;
      handler.resolve(Response(requestOptions: options, statusCode: 200,
        data: {'operation_revision': 5, 'sync_revision': 5}));
    }));
    final queue = storage.getPendingSyncActions();
    queue.first['status'] = 'queued';
    queue.first.remove('last_error');
    await storage.savePendingSyncActions(queue);
    final syncing = service.syncPendingActions();
    await started.future;
    final result = await service.discardTrainingExecution(request);
    expect(result.reason, TrainingExecutionDiscardReason.inFlight);
    release.complete();
    await syncing;
    expect(storage.getConfirmedTrainingExecutions('training', request.date)
      .any((e) => e['id'] == 'target'), isTrue);
  });

  test('dependency added while waiting for sync is rechecked at mutation time', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    client.dio.interceptors.clear();
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      started.complete();
      await release.future;
      handler.resolve(Response(requestOptions: options, statusCode: 200,
        data: {'operation_revision': 1, 'sync_revision': 1}));
    }));
    await storage.savePendingSyncActions([
      storage.getPendingSyncActions().first,
      {'id': 'independent-meal', ...storage.queueIdentity, 'type': 'mark_meal_completed',
        'meal_id': 'meal', 'date': '2026-09-06', 'status': 'queued'},
    ]);
    final syncing = service.syncPendingActions();
    await started.future;
    final discarding = service.discardTrainingExecution(request);
    await storage.saveFeedbackUploadQueue([
      {'id': 'new-dependency', ...storage.queueIdentity,
        'training_session_id': 'target', 'status': 'queued'},
    ]);
    release.complete();
    await syncing;
    expect((await discarding).reason, TrainingExecutionDiscardReason.unsentDependencies);
    expect(storage.isTrainingExecutionDiscarded('target'), isFalse);
  });

  test('atomic write interruption has no partial projection; concurrent calls recheck', () async {
    expect(service.inspectTrainingExecutionDiscard(request).canDiscard, isTrue);
    final barrier = _BarrierStorage(currentSession: () => current);
    final writer = OfflineSyncService(client, barrier, isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    final first = writer.discardTrainingExecution(request);
    await barrier.started.future;
    final second = writer.discardTrainingExecution(request);
    expect(storage.getPendingSyncActions(), hasLength(2));
    barrier.release.complete();
    expect((await first).reason, TrainingExecutionDiscardReason.discarded);
    expect((await second).reason, TrainingExecutionDiscardReason.alreadyDiscarded);
    await writer.dispose();
  });

  test('unproven exercise draft completion prevents discard', () async {
    await storage.saveActiveWorkout(ActiveWorkoutHiveModel(trainingId: 'training',
      sessionId: 'target', exerciseId: 'exercise:${request.date}:target',
      currentSet: 2, completedSets: 1, completionOperationId: 'unproven-operation'));
    expect((await service.discardTrainingExecution(request)).reason,
      TrainingExecutionDiscardReason.unsentDependencies);
    expect(storage.getActiveWorkouts(), hasLength(1));
  });

  for (final afterCommit in [false, true]) {
    test('write failure ${afterCommit ? 'after' : 'before'} atomic commit recovers on restart', () async {
      final failing = _FailingStorage(currentSession: () => current, afterCommit: afterCommit);
      final writer = OfflineSyncService(client, failing, isAuthenticated: () => true,
        authenticationChanges: const Stream<bool>.empty(),
        connectivityChanges: const Stream<bool>.empty());
      expect((await writer.discardTrainingExecution(request)).reason,
        TrainingExecutionDiscardReason.storageFailure);
      await writer.dispose();
      await Hive.close();
      await Hive.openBox('cache_box');
      await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
      expect(storage.getPendingSyncActions().length, afterCommit ? 1 : 2);
      expect((await service.discardTrainingExecution(request)).reason,
        afterCommit ? TrainingExecutionDiscardReason.alreadyDiscarded :
          TrainingExecutionDiscardReason.discarded);
      await storage.clearCache();
      expect(storage.getPendingSyncActions().single['id'], 'other-action');
    });
  }

  test('generation change during write barrier cannot discard the new session', () async {
    expect(service.inspectTrainingExecutionDiscard(request).canDiscard, isTrue);
    final barrier = _BarrierStorage(currentSession: () => current);
    final writer = OfflineSyncService(client, barrier, isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    final pending = writer.discardTrainingExecution(request);
    await barrier.started.future;
    current = const LocalAuthSession(uid: 'A', generation: 2);
    barrier.release.complete();
    expect((await pending).reason, TrainingExecutionDiscardReason.staleSession);
    expect(storage.getPendingSyncActions(), hasLength(2));
    await writer.dispose();
  });
}

class _FailingStorage extends LocalStorage {
  _FailingStorage({super.currentSession, required this.afterCommit});
  final bool afterCommit;
  @override
  Future<void> cacheData(String key, dynamic value) async {
    if (key.startsWith('training_execution_discard:')) {
      if (afterCommit) await super.cacheData(key, value);
      throw StateError('simulated interrupted write');
    }
    await super.cacheData(key, value);
  }
}

class _BarrierStorage extends LocalStorage {
  _BarrierStorage({super.currentSession});
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> cacheData(String key, dynamic value) async {
    if (key.startsWith('training_execution_discard:')) {
      started.complete();
      await release.future;
      guardSession();
    }
    await super.cacheData(key, value);
  }
}
