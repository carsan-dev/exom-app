import 'dart:async';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/data/datasources/training_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pauses replay and preserves claimed work when validation is revoked in flight',
    () async {
      var authenticated = true;
      var requests = 0;
      final storage = FakeSyncStorage(
        actions: [
          for (var i = 0; i < 2; i++)
            {
              'id': 'action-$i',
              'type': 'complete_training',
              'training_id': 'training-$i',
              'date': '2026-09-05',
              'status': 'queued',
              'attempts': 0,
            },
        ],
      );
      final service = OfflineSyncService(
        respondingClient((options, handler) {
          requests++;
          authenticated = false;
          handler.resolve(Response(requestOptions: options, statusCode: 200));
        }),
        storage,
        isAuthenticated: () => authenticated,
        authenticationChanges: const Stream<bool>.empty(),
        connectivityChanges: const Stream<bool>.empty(),
      );
      await service.syncPendingActions();
      expect(requests, 1);
      expect(storage.actions, hasLength(2));
      expect(
        storage.actions.map((action) => action['status']),
        everyElement('queued'),
      );
      await service.dispose();
    },
  );
  test('unmark replay targets its execution or the sessionless legacy row', () async {
    final storage = FakeSyncStorage();
    final offline = OfflineSyncService(
      respondingClient((options, handler) {}), storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await offline.queueExerciseCompletion('training-exercise-1', '2026-09-05',
      completed: false, sessionId: 'execution-1', operationId: 'unmark-1');
    await offline.queueExerciseCompletion('training-exercise-2', '2026-09-06',
      completed: false, operationId: 'legacy-unmark-1');
    expect(storage.actions.map((action) => action['id']),
      ['unmark-1', 'legacy-unmark-1']);
    await offline.dispose();

    final requests = <({String path, Map<String, dynamic> query, String? id})>[];
    final replay = OfflineSyncService(
      respondingClient((options, handler) {
        requests.add((path: options.path,
          query: Map<String, dynamic>.from(options.queryParameters),
          id: options.headers['x-exom-operation-id'] as String?));
        handler.resolve(Response(requestOptions: options, statusCode: 200,
          data: {'operation_revision': 1, 'sync_revision': 1,
            'exercises_completed': <Map<String, dynamic>>[],
            'meals_completed': <String>[]},
        ));
      }), storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await replay.syncPendingActions();
    expect(requests.map((request) => request.path), [
      '/progress/exercises/training-exercise-1',
      '/progress/exercises/training-exercise-2',
    ]);
    expect(requests.map((request) => request.id), [
      'unmark-1', 'legacy-unmark-1',
    ]);
    expect(requests.map((request) => request.query).toList(), [
      <String, dynamic>{'date': '2026-09-05', 'training_session_id': 'execution-1'},
      <String, dynamic>{'date': '2026-09-06'},
    ]);
    expect(storage.actions, isEmpty);
    await replay.dispose();
  });

  test('restart after durable enqueue reuses the completed set operation', () async {
    final storage = FakeSyncStorage();
    final first = OfflineSyncService(
      respondingClient((options, handler) {}), storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await first.queueExerciseCompletion('te-1', '2026-09-05',
      completed: true, exerciseId: 'ex-1', operationId: 'set-op-1',
      sets: const [SetPerformance(setNumber: 1, reps: 12)]);
    await first.dispose();
    final restarted = OfflineSyncService(
      respondingClient((options, handler) {}), storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await restarted.queueExerciseCompletion('te-1', '2026-09-05',
      completed: true, exerciseId: 'ex-1', operationId: 'set-op-1',
      sets: const [SetPerformance(setNumber: 1, reps: 12)]);
    expect(storage.actions, hasLength(1));
    expect(storage.actions.single['id'], 'set-op-1');
    await restarted.dispose();
  });

  test('retry after server ack keeps the draft operation identity', () async {
    final storage = FakeSyncStorage();
    final ids = <String?>[];
    final service = OfflineSyncService(
      respondingClient((options, handler) {
        ids.add(options.headers['x-exom-operation-id'] as String?);
        handler.resolve(Response(requestOptions: options, statusCode: 200,
          data: {'operation_revision': 1, 'sync_revision': 1,
            'exercises_completed': <Map<String, dynamic>>[],
            'meals_completed': <String>[]},
        ));
      }), storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await service.queueExerciseCompletion('te-1', '2026-09-05',
        completed: true, exerciseId: 'ex-1', operationId: 'set-op-1',
        sets: const [SetPerformance(setNumber: 1, reps: 12)]);
      await service.syncPendingActions();
    }
    expect(ids, ['set-op-1', 'set-op-1']);
    expect(storage.actions, isEmpty);
    await service.dispose();
  });

  test('persists seconds and RIR in queued exercise completion', () async {
    final storage = FakeSyncStorage();
    final service = OfflineSyncService(
      respondingClient((options, handler) {}),
      storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );

    await service.queueExerciseCompletion(
      'training-exercise-1',
      '2026-09-05',
      completed: true,
      exerciseId: 'exercise-1',
      sets: const [SetPerformance(setNumber: 1, seconds: 45, rir: 2)],
    );

    expect(storage.actions.single['sets'], [
      {'set_number': 1, 'seconds': 45, 'rir': 2},
    ]);
    await service.dispose();
  });

  test('replays set completions with their distinct execution identities', () async {
    final storage = FakeSyncStorage();
    final offline = OfflineSyncService(
      respondingClient((options, handler) {}),
      storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    for (final session in ['execution-1', 'execution-2']) {
      await offline.queueExerciseCompletion(
        'training-exercise-1',
        '2026-09-05',
        completed: true,
        exerciseId: 'exercise-1',
        trainingId: 'training-1',
        sessionId: session,
        sets: const [SetPerformance(setNumber: 1, reps: 10, rir: 0)],
      );
    }
    await offline.dispose();

    final requests = <Map<String, dynamic>>[];
    final replay = OfflineSyncService(
      respondingClient((options, handler) {
        requests.add(Map<String, dynamic>.from(options.data as Map));
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'operation_revision': requests.length,
            'sync_revision': requests.length,
            'exercises_completed': <Map<String, dynamic>>[],
            'meals_completed': <String>[],
          },
        ));
      }),
      storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await replay.syncPendingActions();
    expect(requests.map((request) => request['training_session_id']), [
      'execution-1',
      'execution-2',
    ]);
    expect(requests.map((request) => request['sets']), everyElement(isNotEmpty));
    await replay.dispose();
  });

  test('omits absent RIR so replay cannot clear a stored value', () async {
    final storage = FakeSyncStorage();
    final service = OfflineSyncService(
      respondingClient((options, handler) {}),
      storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );

    await service.queueExerciseCompletion(
      'training-exercise-1',
      '2026-09-05',
      completed: true,
      exerciseId: 'exercise-1',
      sets: const [SetPerformance(setNumber: 1, reps: 10)],
    );

    expect((storage.actions.single['sets'] as List).single, {
      'set_number': 1,
      'reps': 10,
    });
    await service.dispose();
  });

  test('keeps independent executions and a stable completion payload across restart', () async {
    final storage = FakeSyncStorage();
    final offline = OfflineSyncService(
      respondingClient((options, handler) {}),
      storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await offline.queueTrainingCompletion(
      '2026-09-05', trainingId: 'training-1', sessionId: 'session-1',
      rpe: 8, notes: ' First ',
    );
    await offline.queueTrainingCompletion(
      '2026-09-05', trainingId: 'training-1', sessionId: 'session-1',
      rpe: 7, notes: 'Changed after confirmation',
    );
    expect(storage.getCachedMap('day_progress_2026-09-05')?['notes'], isNull);
    await offline.queueTrainingCompletion(
      '2026-09-05', trainingId: 'training-1', sessionId: 'session-2',
      rpe: 9, notes: 'Second',
    );
    expect(storage.actions, hasLength(2));
    final firstId = storage.actions.first['id'];
    expect(storage.actions.first['rpe'], 8);
    expect(storage.actions.map((action) => action['notes']), ['First', 'Second']);
    expect(storage.getCachedMap('day_progress_2026-09-05')?['notes'], isNull);
    await offline.dispose();

    final requests = <Map<String, dynamic>>[];
    final ids = <String?>[];
    final restarted = OfflineSyncService(
      respondingClient((options, handler) {
        requests.add(Map<String, dynamic>.from(options.data as Map));
        ids.add(options.headers['x-exom-operation-id'] as String?);
        handler.resolve(Response(requestOptions: options, statusCode: 200,
          data: {'operation_revision': requests.length, 'sync_revision': requests.length,
            'exercises_completed': <Map<String, dynamic>>[],
            'meals_completed': <String>[]},
        ));
      }),
      storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await restarted.syncPendingActions();
    expect(requests, [
      {'date': '2026-09-05', 'training_id': 'training-1',
       'training_session_id': 'session-1', 'rpe': 8, 'session_note': 'First'},
      {'date': '2026-09-05', 'training_id': 'training-1',
       'training_session_id': 'session-2', 'rpe': 9, 'session_note': 'Second'},
    ]);
    expect(ids.first, firstId);
    await restarted.dispose();
  });

  test('local confirmation stays pending-sync and retains its RPE draft before replay', () async {
    final storage = FakeSyncStorage();
    final offline = OfflineSyncService(respondingClient((options, handler) {}), storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    final remote = TrainingRemoteDataSourceImpl(
      respondingClient((options, handler) {}), storage, offline);
    await remote.completeTraining('2026-09-05', trainingId: 'training-1',
      sessionId: 'execution-1', rpe: 8, notes: 'Original');
    expect(storage.executionStatuses['execution-1'], 'pending-sync');
    expect(storage.actions.single['status'], 'queued');
    expect(storage.savedDrafts['execution-1'], containsPair('rpe', 8));
    await offline.dispose();
  });

  test('accepted completion with lost response replays the same operation after restart', () async {
    const date = '2026-09-05';
    const execution = 'execution-1';
    const payload = {
      'date': date,
      'training_id': 'training-1',
      'training_session_id': execution,
      'rpe': 8,
      'session_note': 'Original',
    };
    final storage = FakeSyncStorage();
    final accepted = <String, Map<String, dynamic>>{};
    final requests = <Map<String, dynamic>>[];
    final ids = <String>[];
    var serverEffects = 0;
    var loseResponse = true;
    var online = false;
    final client = respondingClient((options, handler) {
      expect(options.path, '/progress/trainings/complete');
      final id = options.headers['x-exom-operation-id'] as String;
      final body = Map<String, dynamic>.from(options.data as Map);
      ids.add(id);
      requests.add(body);
      accepted.putIfAbsent(id, () {
        serverEffects++;
        return body;
      });
      if (loseResponse) {
        loseResponse = false;
        handler.reject(DioException.connectionError(
          requestOptions: options, reason: 'response lost after acceptance'));
      } else {
        handler.resolve(Response(requestOptions: options, statusCode: 200,
          data: {'operation_revision': 1, 'sync_revision': 1,
            'exercises_completed': <Map<String, dynamic>>[],
            'meals_completed': <String>[]}));
      }
    });
    final first = OfflineSyncService(client, storage,
      isAuthenticated: () => online,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    final remote = TrainingRemoteDataSourceImpl(client, storage, first);
    await remote.completeTraining(date, trainingId: 'training-1',
      sessionId: execution, rpe: 8, notes: ' Original ');
    final originalId = storage.actions.single['id'] as String;
    expect(storage.savedDrafts[execution], containsPair('rpe', 8));
    online = true;
    await first.syncPendingActions();
    expect(ids, [originalId]);
    expect(requests, [payload]);
    expect(storage.actions.single['status'], 'queued');
    expect(storage.executionStatuses[execution], 'pending-sync');
    await first.dispose();

    final reconnects = StreamController<bool>();
    final restarted = OfflineSyncService(client, storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: reconnects.stream);
    await restarted.init();
    final drained = restarted.changes.firstWhere((_) => storage.actions.isEmpty);
    reconnects.add(true); // Bypass retry backoff after connectivity returns.
    await drained.timeout(const Duration(seconds: 1));
    expect(ids, [originalId, originalId]);
    expect(requests, [payload, payload]);
    expect(accepted, {originalId: payload});
    expect(serverEffects, 1);
    expect(storage.actions, isEmpty);
    expect(storage.executionStatuses[execution], 'confirmed');
    expect(storage.savedDrafts, hasLength(1));
    await restarted.dispose();
    await reconnects.close();
  });

  test('failed and discarded completion retries with original payload and ID', () async {
    final storage = FakeSyncStorage();
    final failing = OfflineSyncService(
      respondingClient((options, handler) => handler.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 400),
      ))), storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await failing.queueTrainingCompletion('2026-09-05',
        trainingId: 'training-1', sessionId: 'execution-1', rpe: 8, notes: 'Original');
    final original = Map<String, dynamic>.from(storage.actions.single);
    await failing.syncPendingActions();
    expect(storage.actions.single['status'], 'failed');
    expect(storage.executionStatuses['execution-1'], 'failed');
    await failing.discardAction(original['id'] as String);
    expect(storage.actions, isEmpty);
    await failing.dispose();

    final requests = <Map<String, dynamic>>[];
    final ids = <String?>[];
    final restarted = OfflineSyncService(
      respondingClient((options, handler) {
        requests.add(Map<String, dynamic>.from(options.data as Map));
        ids.add(options.headers['x-exom-operation-id'] as String?);
        handler.resolve(Response(requestOptions: options, statusCode: 200,
            data: {'operation_revision': 1, 'sync_revision': 1,
              'exercises_completed': <Map<String, dynamic>>[],
              'meals_completed': <String>[]}));
      }), storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await restarted.queueTrainingCompletion('2026-09-05',
        trainingId: 'training-1', sessionId: 'execution-1', rpe: 2, notes: 'Changed');
    expect(storage.actions.single['id'], original['id']);
    expect(storage.actions.single['rpe'], 8);
    await restarted.syncPendingActions();
    expect(ids, [original['id']]);
    expect(requests.single['session_note'], 'Original');
    expect(requests.single, isNot(contains('notes')));
    expect(requests.single['rpe'], 8);
    expect(storage.executionStatuses['execution-1'], 'confirmed');
    await restarted.dispose();
  });

  test('retrying a failed completion retains its operation and original payload', () async {
    final storage = FakeSyncStorage();
    final service = OfflineSyncService(
      respondingClient((options, handler) {}), storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await service.queueTrainingCompletion('2026-09-05',
      trainingId: 'training-1', sessionId: 'execution-1', rpe: 8, notes: 'First');
    final original = Map<String, dynamic>.from(storage.actions.single);
    storage.actions.single['status'] = 'failed';
    storage.actions.single['attempts'] = 5;
    storage.actions.single['last_error'] = 'sync_request_failed';

    await service.queueTrainingCompletion('2026-09-05',
      trainingId: 'training-1', sessionId: 'execution-1', rpe: 3, notes: 'Changed');
    expect(storage.actions, hasLength(1));
    expect(storage.actions.single, {
      ...original, 'status': 'queued', 'attempts': 0, 'last_error': null,
    });
    expect(storage.getCachedMap('day_progress_2026-09-05')?['notes'], isNull);
    await service.dispose();
  });

  test('a conflict failure cannot be confirmed or silently retried', () async {
    final storage = FakeSyncStorage();
    final service = OfflineSyncService(
      respondingClient((options, handler) {}), storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await service.queueTrainingCompletion('2026-09-05',
      trainingId: 'training-1', sessionId: 'execution-1', notes: 'First');
    storage.actions.single['status'] = 'failed';
    storage.actions.single['last_error'] = 'progress_conflict_review_required';
    final failed = Map<String, dynamic>.from(storage.actions.single);
    await expectLater(
      service.queueTrainingCompletion('2026-09-05',
        trainingId: 'training-1', sessionId: 'execution-1', notes: 'Changed'),
      throwsStateError,
    );
    expect(storage.actions, [failed]);
    await service.dispose();
  });

  test('discarding a conflicting completion does not authorize blind replay', () async {
    final storage = FakeSyncStorage();
    final service = OfflineSyncService(respondingClient((options, handler) {}), storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    await service.queueTrainingCompletion('2026-09-05',
        trainingId: 'training-1', sessionId: 'execution-1', rpe: 8);
    storage.actions.single['status'] = 'failed';
    storage.actions.single['last_error'] = 'progress_conflict_review_required';
    await service.discardAction(storage.actions.single['id'] as String);
    expect(storage.executionStatuses['execution-1'], 'conflict');
    await expectLater(service.queueTrainingCompletion('2026-09-05',
        trainingId: 'training-1', sessionId: 'execution-1', rpe: 2), throwsStateError);
    expect(storage.actions, isEmpty);
    await service.dispose();
  });

  test('replays persisted session notes without changing their queue schema', () async {
    final storage = FakeSyncStorage(actions: [
      {
        'id': 'existing-session-operation',
        'type': 'complete_training',
        'date': '2026-09-05',
        'training_id': 'training-1',
        'training_session_id': 'session-1',
        'notes': 'Persisted session note',
        'status': 'queued',
        'attempts': 0,
      },
    ]);
    final persisted = Map<String, dynamic>.from(storage.actions.single);
    final requests = <Map<String, dynamic>>[];
    final service = OfflineSyncService(respondingClient((options, handler) {
      expect(options.path, '/progress/trainings/complete');
      requests.add(Map<String, dynamic>.from(options.data as Map));
      handler.resolve(Response(requestOptions: options, statusCode: 200));
    }), storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    expect(persisted['notes'], 'Persisted session note');
    expect(persisted['id'], 'existing-session-operation');
    await service.syncPendingActions();
    expect(requests, [{
      'date': '2026-09-05', 'training_id': 'training-1',
      'training_session_id': 'session-1',
      'session_note': 'Persisted session note',
    }]);
    expect(storage.actions, isEmpty);
    await service.dispose();
  });

  test('sessionless completion retains legacy day notes in queue and replay', () async {
    final storage = FakeSyncStorage();
    final offline = OfflineSyncService(respondingClient((options, handler) {}), storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    await offline.queueTrainingCompletion('2026-09-05',
      trainingId: 'training-1', notes: ' Legacy day note ');
    expect(storage.actions.single['notes'], 'Legacy day note');
    expect(storage.actions.single.containsKey('training_session_id'), isFalse);
    expect(storage.getCachedMap('day_progress_2026-09-05')?['notes'], 'Legacy day note');
    await offline.dispose();

    final requests = <Map<String, dynamic>>[];
    final replay = OfflineSyncService(respondingClient((options, handler) {
      requests.add(Map<String, dynamic>.from(options.data as Map));
      handler.resolve(Response(requestOptions: options, statusCode: 200,
        data: {'operation_revision': 1, 'sync_revision': 1,
          'exercises_completed': <Map<String, dynamic>>[],
          'meals_completed': <String>[]}));
    }), storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    await replay.syncPendingActions();
    expect(requests, [{
      'date': '2026-09-05', 'training_id': 'training-1',
      'notes': 'Legacy day note',
    }]);
    expect(storage.actions, isEmpty);
    await replay.dispose();
  });

  test('deduplicates repeated pending complete-training actions', () async {
    final storage = FakeSyncStorage();
    final service = OfflineSyncService(
      respondingClient((options, handler) {}),
      storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );

    await Future.wait([
      service.queueTrainingCompletion('2026-09-05', trainingId: 'training-1'),
      service.queueTrainingCompletion('2026-09-05', trainingId: 'training-1'),
    ]);

    expect(
      storage.actions.where((action) => action['type'] == 'complete_training'),
      hasLength(1),
    );
    await service.dispose();
  });

  test('replays an interrupted upload when the app starts again', () async {
    final storage = FakeSyncStorage(
      actions: [
        {
          'id': 'interrupted-exercise',
          'type': 'mark_exercise_completed',
          'training_exercise_id': 'training-exercise-1',
          'exercise_id': 'exercise-1',
          'training_id': 'training-1',
          'date': '2026-09-05',
          'sets': [
            {'set_number': 1, 'reps': 10, 'rir': null},
          ],
          'status': 'uploading',
          'attempts': 0,
        },
      ],
    );
    final requests = <String>[];
    Map<String, dynamic>? exercisePayload;
    final client = respondingClient((options, handler) {
      requests.add(options.path);
      exercisePayload = Map<String, dynamic>.from(options.data as Map);
      handler.resolve(Response(requestOptions: options, statusCode: 200));
    });
    final service = OfflineSyncService(
      client,
      storage,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );

    await service.init();

    expect(requests, ['/progress/exercises/complete']);
    expect(exercisePayload, {
      'exercise_id': 'exercise-1',
      'training_exercise_id': 'training-exercise-1',
      'date': '2026-09-05',
      'sets': [
        {'set_number': 1, 'reps': 10},
      ],
    });
    expect(storage.actions, isEmpty);
    await service.dispose();
  });

  test(
    'retries immediately when connectivity returns despite backoff',
    () async {
      final reconnects = StreamController<bool>();
      final storage = FakeSyncStorage(
        actions: [
          {
            'id': 'offline-exercise',
            'type': 'mark_exercise_completed',
            'training_exercise_id': 'training-exercise-1',
            'exercise_id': 'exercise-1',
            'date': '2026-09-05',
            'status': 'queued',
            'attempts': 1,
            'next_attempt_at': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          },
        ],
      );
      final requests = <String>[];
      final client = respondingClient((options, handler) {
        requests.add(options.path);
        handler.resolve(Response(requestOptions: options, statusCode: 200));
      });
      final service = OfflineSyncService(
        client,
        storage,
        isAuthenticated: () => true,
        authenticationChanges: const Stream<bool>.empty(),
        connectivityChanges: reconnects.stream,
      );

      await service.init();
      expect(requests, isEmpty);

      final drained = service.changes.firstWhere(
        (_) => storage.actions.isEmpty,
      );
      reconnects.add(true);
      await drained.timeout(const Duration(seconds: 1));

      expect(requests, ['/progress/exercises/complete']);
      expect(storage.actions, isEmpty);
      await service.dispose();
      await reconnects.close();
    },
  );

  test(
    'retries reconnect after an in-flight offline request finishes',
    () async {
      final reconnects = StreamController<bool>();
      final firstRequestStarted = Completer<void>();
      final releaseFirstRequest = Completer<void>();
      final storage = FakeSyncStorage(
        actions: [
          {
            'id': 'in-flight-exercise',
            'type': 'mark_exercise_completed',
            'training_exercise_id': 'training-exercise-1',
            'exercise_id': 'exercise-1',
            'date': '2026-09-05',
            'status': 'queued',
            'attempts': 0,
          },
        ],
      );
      var requestCount = 0;
      final client = respondingClient((options, handler) {
        requestCount++;
        if (requestCount == 1) {
          firstRequestStarted.complete();
          releaseFirstRequest.future.then(
            (_) => handler.reject(
              DioException.connectionError(
                requestOptions: options,
                reason: 'offline',
              ),
            ),
          );
          return;
        }
        handler.resolve(Response(requestOptions: options, statusCode: 200));
      });
      final service = OfflineSyncService(
        client,
        storage,
        isAuthenticated: () => true,
        authenticationChanges: const Stream<bool>.empty(),
        connectivityChanges: reconnects.stream,
      );

      final initialization = service.init();
      await firstRequestStarted.future;
      final drained = service.changes.firstWhere(
        (_) => storage.actions.isEmpty,
      );
      reconnects.add(true);
      releaseFirstRequest.complete();
      await initialization;
      await drained.timeout(const Duration(seconds: 1));

      expect(requestCount, 2);
      expect(storage.actions, isEmpty);
      await service.dispose();
      await reconnects.close();
    },
  );

  test('skips an upload-blocked action and executes later actions', () async {
    final storage = FakeSyncStorage(
      actions: [
        {
          'id': 'exercise-action',
          'type': 'mark_exercise_completed',
          'training_exercise_id': 'training-exercise-1',
          'exercise_id': 'exercise-1',
          'date': '2026-09-01',
          'last_set_feedback_client_upload_id': 'feedback-1',
          'status': 'queued',
          'attempts': 0,
        },
        {
          'id': 'meal-action',
          'type': 'mark_meal_completed',
          'meal_id': 'meal-1',
          'date': '2026-09-01',
          'status': 'queued',
          'attempts': 0,
        },
      ],
      feedback: [
        {'id': 'feedback-1', 'status': 'queued'},
      ],
    );
    final requests = <String>[];
    final client = respondingClient((options, handler) {
      requests.add(options.path);
      handler.resolve(Response(requestOptions: options, statusCode: 200));
    });
    final service = OfflineSyncService(
      client,
      storage,
      isAuthenticated: () => true,
    );

    await service.syncPendingActions();

    expect(requests, ['/progress/meals/complete']);
    expect(storage.actions, hasLength(1));
    expect(storage.actions.single['id'], 'exercise-action');
  });

  test('keeps a permanent failure visible and continues the queue', () async {
    final storage = FakeSyncStorage(
      actions: [
        {
          'id': 'invalid-action',
          'type': 'mark_exercise_completed',
          'training_exercise_id': 'training-exercise-1',
          'exercise_id': 'exercise-1',
          'date': '2026-09-01',
          'status': 'queued',
          'attempts': 0,
        },
        {
          'id': 'meal-action',
          'type': 'mark_meal_completed',
          'meal_id': 'meal-1',
          'date': '2026-09-01',
          'status': 'queued',
          'attempts': 0,
        },
      ],
    );
    storage.cache.addAll({
      'day_progress_2026-09-01': {
        'exercises_completed': ['stale'],
      },
      'home_progress_2026-09-01': {
        'exercises_completed': ['stale'],
      },
      'completed_exercises_2026-09-01': ['training-exercise-1'],
      'completed_meals_2026-09-01': ['meal-1'],
    });
    final requests = <String>[];
    final client = respondingClient((options, handler) {
      requests.add(options.path);
      if (options.path.contains('/exercises/')) {
        handler.reject(
          DioException.badResponse(
            statusCode: 422,
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 422),
          ),
        );
      } else {
        handler.resolve(Response(requestOptions: options, statusCode: 200));
      }
    });
    final service = OfflineSyncService(
      client,
      storage,
      isAuthenticated: () => true,
    );

    await service.syncPendingActions();

    expect(requests, [
      '/progress/exercises/complete',
      '/progress/meals/complete',
    ]);
    expect(storage.actions, hasLength(1));
    expect(storage.actions.single['status'], 'failed');
    expect(storage.actions.single['attempts'], 1);
    final progress = storage.getCachedMap('day_progress_2026-09-01');
    expect(progress?['exercises_completed'], isEmpty);
    expect(progress?['meals_completed'], ['meal-1']);
  });

  test(
    'clears stale progress from an action that failed before restart',
    () async {
      final storage = FakeSyncStorage(
        actions: [
          {
            'id': 'failed-exercise',
            'type': 'mark_exercise_completed',
            'training_exercise_id': 'training-exercise-1',
            'exercise_id': 'exercise-1',
            'date': '2026-09-05',
            'status': 'failed',
            'attempts': 1,
          },
          {
            'id': 'queued-exercise',
            'type': 'mark_exercise_completed',
            'training_exercise_id': 'training-exercise-2',
            'exercise_id': 'exercise-2',
            'date': '2026-09-05',
            'status': 'queued',
            'attempts': 0,
          },
        ],
      );
      storage.cache.addAll({
        'day_progress_2026-09-05': {
          'exercises_completed': ['stale'],
        },
        'home_progress_2026-09-05': {
          'exercises_completed': ['stale'],
        },
        'completed_exercises_2026-09-05': ['training-exercise-1'],
      });
      final service = OfflineSyncService(
        respondingClient((options, handler) {
          handler.resolve(Response(requestOptions: options, statusCode: 200));
        }),
        storage,
        isAuthenticated: () => false,
        authenticationChanges: const Stream<bool>.empty(),
        connectivityChanges: const Stream<bool>.empty(),
      );

      await service.init();

      expect(storage.actions.first['status'], 'failed');
      final progress = storage.getCachedMap('day_progress_2026-09-05');
      final exercises = (progress?['exercises_completed'] as List?) ?? const [];
      expect(exercises, hasLength(1));
      expect(
        (exercises.single as Map)['training_exercise_id'],
        'training-exercise-2',
      );
      await service.dispose();
    },
  );

  test(
    'retries dependent 409 responses and fails manually after five attempts',
    () async {
      final storage = FakeSyncStorage(
        actions: [
          {
            'id': 'pending-feedback',
            'type': 'mark_exercise_completed',
            'training_exercise_id': 'training-exercise-1',
            'exercise_id': 'exercise-1',
            'date': '2026-09-01',
            'status': 'queued',
            'attempts': 4,
          },
        ],
      );
      final client = respondingClient((options, handler) {
        handler.reject(
          DioException.badResponse(
            statusCode: 409,
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 409),
          ),
        );
      });
      final service = OfflineSyncService(
        client,
        storage,
        isAuthenticated: () => true,
      );

      await service.syncPendingActions();

      expect(storage.actions.single['status'], 'failed');
      expect(storage.actions.single['attempts'], 5);
    },
  );

  test('keeps prolonged offline actions queued after five attempts', () async {
    final storage = FakeSyncStorage(
      actions: [
        {
          'id': 'offline-exercise',
          'type': 'mark_exercise_completed',
          'training_exercise_id': 'training-exercise-1',
          'exercise_id': 'exercise-1',
          'date': '2026-09-05',
          'status': 'queued',
          'attempts': 4,
        },
      ],
    );
    final client = respondingClient((options, handler) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
    });
    final service = OfflineSyncService(
      client,
      storage,
      isAuthenticated: () => true,
    );

    await service.syncPendingActions();

    expect(storage.actions.single['status'], 'queued');
    expect(storage.actions.single['attempts'], 5);
    expect(storage.actions.single['next_attempt_at'], isNotNull);
  });

  test('preserves actions enqueued while a replay is in flight', () async {
    final storage = FakeSyncStorage(
      actions: [
        {
          'id': 'first-meal',
          'type': 'mark_meal_completed',
          'meal_id': 'meal-1',
          'date': '2026-09-01',
          'status': 'queued',
          'attempts': 0,
        },
      ],
    );
    final firstRequestStarted = Completer<void>();
    final releaseFirstRequest = Completer<void>();
    final requests = <String>[];
    final client = respondingClient((options, handler) {
      requests.add((options.data as Map<String, dynamic>)['meal_id'] as String);
      if (!firstRequestStarted.isCompleted) {
        firstRequestStarted.complete();
        releaseFirstRequest.future.then(
          (_) => handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'sync_revision': requests.length,
                'operation_revision': requests.length,
                'exercises_completed': [],
                'meals_completed': [],
              },
            ),
          ),
        );
      } else {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'sync_revision': requests.length,
              'operation_revision': requests.length,
              'exercises_completed': [],
              'meals_completed': [],
            },
          ),
        );
      }
    });
    final service = OfflineSyncService(
      client,
      storage,
      isAuthenticated: () => true,
    );

    final sync = service.syncPendingActions();
    await firstRequestStarted.future;
    await service.queueMealCompletion('meal-2', '2026-09-01', completed: true);
    releaseFirstRequest.complete();
    await sync;

    expect(requests, ['meal-1', 'meal-2']);
    expect(storage.actions, isEmpty);
  });

  test('completion depends only on feedback from its execution', () async {
    final storage = FakeSyncStorage(feedback: [
      {
        'id': 'video-a',
        'training_id': 'training-1',
        'assignment_date': '2026-09-01',
        'training_session_id': 'execution-a',
        'status': 'completed',
      },
      {
        'id': 'video-b',
        'training_id': 'training-1',
        'assignment_date': '2026-09-01',
        'training_session_id': 'execution-b',
        'status': 'uploading',
      },
    ]);
    final service = OfflineSyncService(
      respondingClient((options, handler) {}),
      storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    await service.queueTrainingCompletion(
      '2026-09-01',
      trainingId: 'training-1',
      sessionId: 'execution-a',
      rpe: 8,
    );
    expect(storage.actions.single['depends_on_feedback_ids'], isNull);
    await service.queueTrainingCompletion(
      '2026-09-01',
      trainingId: 'training-1',
      sessionId: 'execution-b',
      rpe: 9,
    );
    expect(storage.actions.last['depends_on_feedback_ids'], ['video-b']);
    await service.dispose();
  });

  test('blocks training completion until feedback is completed', () async {
    final storage = FakeSyncStorage(
      actions: [
        {
          'id': 'complete-training',
          'type': 'complete_training',
          'training_id': 'training-1',
          'date': '2026-09-01',
          'depends_on_feedback_ids': ['feedback-1'],
          'status': 'queued',
          'attempts': 0,
        },
      ],
      feedback: [
        {'id': 'feedback-1', 'status': 'uploading'},
      ],
    );
    final requests = <String>[];
    final client = respondingClient((options, handler) {
      requests.add(options.path);
      handler.resolve(Response(requestOptions: options, statusCode: 200));
    });
    final service = OfflineSyncService(
      client,
      storage,
      isAuthenticated: () => true,
    );

    await service.syncPendingActions();
    expect(requests, isEmpty);
    expect(storage.actions.single['status'], 'queued');

    storage.feedback = [
      {'id': 'feedback-1', 'status': 'completed'},
    ];
    await service.syncPendingActions();

    expect(requests, ['/progress/trainings/complete']);
    expect(storage.actions, isEmpty);
  });

  test('keeps completion cached while the server response is stale', () async {
    final storage = FakeSyncStorage(
      actions: [
        {
          'id': 'exercise-action',
          'type': 'mark_exercise_completed',
          'training_exercise_id': 'training-exercise-1',
          'exercise_id': 'exercise-1',
          'date': '2026-09-03',
          'status': 'queued',
          'attempts': 0,
        },
      ],
    );
    final client = respondingClient((options, handler) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'data': {
              'exercises_completed': <Map<String, dynamic>>[],
              'meals_completed': <String>[],
            },
          },
        ),
      );
    });
    final service = OfflineSyncService(
      client,
      storage,
      isAuthenticated: () => true,
    );

    await service.syncPendingActions();

    final cached = storage.getCachedMap('day_progress_2026-09-03');
    final exercises = (cached?['exercises_completed'] as List?) ?? const [];
    expect(storage.actions, isEmpty);
    expect(exercises, hasLength(1));
    expect(
      (exercises.single as Map)['training_exercise_id'],
      'training-exercise-1',
    );
  });
}

ApiClient respondingClient(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final client = ApiClient(baseUrl: 'https://api.exom.test', useAuth: false);
  client.dio.interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return client;
}

class FakeSyncStorage extends LocalStorage {
  FakeSyncStorage({
    List<Map<String, dynamic>>? actions,
    this.feedback = const [],
  }) : actions = actions ?? [];

  List<Map<String, dynamic>> actions;
  List<Map<String, dynamic>> feedback;
  final Map<String, dynamic> cache = {};
  final Map<String, String> executionStatuses = {};
  final Map<String, Map<String, dynamic>> discarded = {};
  final Map<String, Map<String, dynamic>> savedDrafts = {};

  @override
  Future<void> saveTrainingCompletionDraft(String trainingId, String date,
      String executionId, {int? rpe, String? notes}) async {
    savedDrafts[executionId] = {'training_id': trainingId,
      'assignment_date': date, 'rpe': ?rpe,
      'notes': ?notes};
  }

  @override
  Future<void> setTrainingExecutionStatus(String id, String status) async =>
      executionStatuses[id] = status;

  @override
  Future<void> completeTrainingExecution(String id) async =>
      executionStatuses[id] = 'confirmed';

  @override
  Future<void> preserveDiscardedTrainingCompletion(Map<String, dynamic> action) async {
    discarded[action['training_session_id'] as String] = Map<String, dynamic>.from(action);
  }

  @override
  Map<String, dynamic>? getTrainingCompletionDraft(String trainingId,
      String date, String executionId) {
    final action = discarded[executionId];
    return action == null ? savedDrafts[executionId] : {'discarded_action': action};
  }

  @override
  List<Map<String, dynamic>> getPendingSyncActions() =>
      actions.map(Map<String, dynamic>.from).toList();

  @override
  Future<void> savePendingSyncActions(List<Map<String, dynamic>> value) async {
    actions = value.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<void> clearPendingSyncActions() async => actions = [];

  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() =>
      feedback.map(Map<String, dynamic>.from).toList();

  @override
  Future<void> cacheData(String key, dynamic value) async => cache[key] = value;

  @override
  Map<String, dynamic>? getCachedMap(String key) {
    final value = cache[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  @override
  List<dynamic>? getCachedList(String key) {
    final value = cache[key];
    return value is List ? List<dynamic>.from(value) : null;
  }
}
