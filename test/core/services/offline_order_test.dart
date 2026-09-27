import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'offline_sync_service_test.dart';

void main() {
  test(
    'v2 completion backoff blocks later unmark and keeps operation identity/revision',
    () async {
      final storage = FakeSyncStorage();
      final operations = <String>[];
      final revisions = <Object?>[];
      final methods = <String>[];
      var fail = true;
      var revision = 0;
      final client = respondingClient((options, handler) {
        operations.add(options.headers['x-exom-operation-id'] as String);
        revisions.add(options.headers['x-exom-revision']);
        methods.add(options.method);
        if (fail) {
          handler.reject(
            DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            ),
          );
          return;
        }
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'sync_revision': ++revision + 20,
              'operation_revision': revision,
              'exercises_completed': <Map<String, dynamic>>[],
              'meals_completed': <String>[],
            },
          ),
        );
      });
      final service = OfflineSyncService(
        client,
        storage,
        isAuthenticated: () => true,
      );
      await service.queueExerciseCompletion(
        'te',
        '2026-09-06',
        completed: true,
        exerciseId: 'e',
      );
      await service.queueExerciseCompletion(
        'te',
        '2026-09-06',
        completed: false,
      );
      final firstId = storage.actions.first['id'];
      await service.syncPendingActions();
      expect(methods, ['POST']);
      expect(storage.actions, hasLength(2));
      fail = false;
      storage.actions.first.remove('next_attempt_at');
      await service.syncPendingActions();
      expect(methods, ['POST', 'POST', 'DELETE']);
      expect(operations[0], firstId);
      expect(operations[1], firstId);
      expect(revisions, [0, 0, 1]);
      expect(storage.actions, isEmpty);
    },
  );
  for (final conflictCode in [
    'PROGRESS_VERSION_CONFLICT',
    'PROGRESS_HISTORY_AMBIGUOUS',
  ]) {
    test(
      '$conflictCode retains user data and blocks later writes instead of auto-rebasing',
      () async {
        final storage = FakeSyncStorage();
        var calls = 0;
        final client = respondingClient((options, handler) {
          calls++;
          handler.reject(
            DioException.badResponse(
              statusCode: 409,
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 409,
                data: {
                  'code': conflictCode,
                  if (conflictCode == 'PROGRESS_VERSION_CONFLICT')
                    'current_progress': {
                      'sync_revision': 4,
                      'exercises_completed': <Map<String, dynamic>>[],
                      'meals_completed': <String>[],
                    },
                },
              ),
            ),
          );
        });
        final service = OfflineSyncService(
          client,
          storage,
          isAuthenticated: () => true,
        );
        await service.queueExerciseCompletion(
          'te',
          '2026-09-06',
          completed: true,
          exerciseId: 'e',
        );
        await service.queueExerciseCompletion(
          'te',
          '2026-09-06',
          completed: false,
        );
        await service.syncPendingActions();
        await service.syncPendingActions();
        expect(calls, 1);
        expect(storage.actions.first['status'], 'failed');
        expect(storage.actions.first['expected_revision'], 0);
        expect(
          storage.actions.first['last_error'],
          'progress_conflict_review_required',
        );
        expect(storage.actions, hasLength(2));
        await service.retryAction(storage.actions.first['id'] as String);
        expect(calls, 1);
        await service.discardAction(storage.actions.first['id'] as String);
        expect(storage.actions.single['status'], 'failed');
        await service.syncPendingActions();
        expect(calls, 1);
      },
    );
  }
  for (final discard in [false, true]) {
    test('independent B replays after exact no-write A rejection (discard=$discard)', () async {
      final storage = FakeSyncStorage();
      final seen = <({String id, Object? revision, Object? session})>[];
      final service = OfflineSyncService(
        respondingClient((options, handler) {
          seen.add((
            id: options.headers['x-exom-operation-id'] as String,
            revision: options.headers['x-exom-revision'],
            session: (options.data as Map)['training_session_id'],
          ));
          if (seen.last.id == 'A') {
            handler.reject(DioException.badResponse(
              statusCode: 409, requestOptions: options,
              response: Response(requestOptions: options, statusCode: 409,
                data: {'code': 'PROGRESS_HISTORY_AMBIGUOUS'}),
            ));
          } else {
            handler.resolve(Response(requestOptions: options, statusCode: 200,
              data: {'sync_revision': 9, 'operation_revision': 9,
                'exercises_completed': <Map<String, dynamic>>[],
                'meals_completed': <String>[]},
            ));
          }
        }), storage, isAuthenticated: () => true,
      );
      await service.queueExerciseCompletion('te-a', '2026-09-06',
        completed: true, exerciseId: 'e-a', sessionId: 'session-a', operationId: 'A');
      await service.queueExerciseCompletion('te-b', '2026-09-06',
        completed: true, exerciseId: 'e-b', sessionId: 'session-b', operationId: 'B');
      final originalB = Map<String, dynamic>.from(storage.actions.last);
      await service.syncPendingActions();
      expect(storage.actions.first['last_error'], 'progress_conflict_review_required');
      expect(storage.actions.first['failure_code'], 'PROGRESS_HISTORY_AMBIGUOUS');
      expect(seen, [
        (id: 'A', revision: 0, session: 'session-a'),
        (id: originalB['id'] as String,
          revision: originalB['expected_revision'],
          session: originalB['training_session_id']),
      ]);
      expect(storage.actions.where((action) => action['id'] == 'B'), isEmpty);
      if (discard) await service.discardAction('A');
      await service.syncPendingActions();
      expect(seen, hasLength(2), reason: 'B must not replay after acknowledgement or discard');
      expect(storage.actions.where((action) => action['id'] == 'B'), isEmpty);
      await service.dispose();
    });
  }

  for (final code in ['PROGRESS_VERSION_CONFLICT', 'PROGRESS_OPERATION_CONFLICT', null]) {
    test('uncertain A ($code) keeps independent B blocked', () async {
      final storage = FakeSyncStorage();
      final seen = <String>[];
      final service = OfflineSyncService(respondingClient((options, handler) {
        seen.add(options.headers['x-exom-operation-id'] as String);
        handler.reject(DioException.badResponse(statusCode: 409,
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 409,
            data: code == null ? <String, dynamic>{} : {'code': code}),
        ));
      }), storage, isAuthenticated: () => true);
      await service.queueExerciseCompletion('te-a', '2026-09-06', completed: true,
        exerciseId: 'e-a', sessionId: 'session-a', operationId: 'A');
      await service.queueExerciseCompletion('te-b', '2026-09-06', completed: true,
        exerciseId: 'e-b', sessionId: 'session-b', operationId: 'B');
      await service.syncPendingActions();
      expect(seen, ['A']);
      expect(storage.actions.last['status'], 'queued');
      await service.dispose();
    });
  }

  for (final session in ['session-a', null, '']) {
    test('same or unproven session B stays blocked ($session)', () async {
      final storage = FakeSyncStorage();
      final seen = <String>[];
      final service = OfflineSyncService(respondingClient((options, handler) {
        seen.add(options.headers['x-exom-operation-id'] as String);
        handler.reject(DioException.badResponse(statusCode: 409,
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 409,
            data: {'code': 'PROGRESS_HISTORY_AMBIGUOUS'}),
        ));
      }), storage, isAuthenticated: () => true);
      await service.queueExerciseCompletion('te-a', '2026-09-06', completed: true,
        exerciseId: 'e-a', sessionId: 'session-a', operationId: 'A');
      await service.queueExerciseCompletion('te-b', '2026-09-06', completed: true,
        exerciseId: 'e-b', sessionId: session, operationId: 'B');
      await service.syncPendingActions();
      await service.discardAction('A');
      await service.syncPendingActions();
      expect(seen, ['A']);
      expect(storage.actions.single['status'], 'failed');
      await service.dispose();
    });
  }

  test('B server version conflict is failed without revision rebase', () async {
    final storage = FakeSyncStorage();
    final seen = <String>[];
    final service = OfflineSyncService(respondingClient((options, handler) {
      final id = options.headers['x-exom-operation-id'] as String;
      seen.add(id);
      handler.reject(DioException.badResponse(statusCode: 409,
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 409,
          data: {'code': id == 'A' ? 'PROGRESS_HISTORY_AMBIGUOUS'
            : 'PROGRESS_VERSION_CONFLICT'}),
      ));
    }), storage, isAuthenticated: () => true);
    await service.queueExerciseCompletion('te-a', '2026-09-06', completed: true,
      exerciseId: 'e-a', sessionId: 'session-a', operationId: 'A');
    await service.queueExerciseCompletion('te-b', '2026-09-06', completed: true,
      exerciseId: 'e-b', sessionId: 'session-b', operationId: 'B');
    await service.syncPendingActions();
    expect(seen, ['A', 'B']);
    expect(storage.actions.last['status'], 'failed');
    expect(storage.actions.last['last_error'], 'progress_conflict_review_required');
    expect(storage.actions.last['failure_code'], 'PROGRESS_VERSION_CONFLICT');
    expect(storage.actions.last['expected_revision'], 0);
    await service.dispose();
  });

  test('syncForDate returns success for confirmed independent B despite rejected A', () async {
    const date = '2026-09-06';
    final storage = FakeSyncStorage();
    final requests = <({String id, Object? revision, Map<String, dynamic> body})>[];
    final client = respondingClient((options, handler) {
      final id = options.headers['x-exom-operation-id'] as String;
      requests.add((
        id: id,
        revision: options.headers['x-exom-revision'],
        body: Map<String, dynamic>.from(options.data as Map),
      ));
      if (id == 'A') {
        handler.reject(DioException.badResponse(
          statusCode: 409,
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 409,
            data: {'code': 'PROGRESS_HISTORY_AMBIGUOUS'}),
        ));
      } else {
        handler.resolve(Response(requestOptions: options, statusCode: 200,
          data: {'sync_revision': 1, 'operation_revision': 1,
            'exercises_completed': <Map<String, dynamic>>[],
            'meals_completed': <String>[]},
        ));
      }
    });
    final service = OfflineSyncService(client, storage, isAuthenticated: () => true);
    await service.queueExerciseCompletion('te-a', date, completed: true,
      exerciseId: 'e-a', sessionId: 'session-a', operationId: 'A');
    await service.queueTrainingCompletion(date, trainingId: 'training-b',
      sessionId: 'session-b', rpe: 8, notes: 'Original');
    final originalB = Map<String, dynamic>.from(storage.actions.last);
    final expectedBody = <String, dynamic>{
      'date': date, 'training_id': 'training-b',
      'training_session_id': 'session-b', 'rpe': 8, 'session_note': 'Original',
    };

    expect(await service.syncForDate(date, sessionId: 'session-b'),
      SyncForDateResult.confirmed);
    expect(requests, hasLength(2));
    expect(requests.first.id, 'A');
    expect(requests.last.id, originalB['id']);
    expect(requests.last.revision, originalB['expected_revision']);
    expect(requests.last.body, expectedBody);
    expect(storage.actions, hasLength(1));
    expect(storage.actions.single['id'], 'A');
    expect(storage.actions.single['failure_code'], 'PROGRESS_HISTORY_AMBIGUOUS');
    expect(storage.executionStatuses['session-b'], 'confirmed');
    await expectLater(service.syncForDate(date), throwsA(isA<ApiException>()));
    await service.dispose();

    final reopened = OfflineSyncService(client, storage, isAuthenticated: () => true);
    await reopened.syncForDate(date, sessionId: 'session-b');
    await expectLater(reopened.syncForDate(date), throwsA(isA<ApiException>()));
    expect(requests, hasLength(2), reason: 'reopen must not create or replay B');
    expect(storage.actions.single['id'], 'A');
    expect(storage.executionStatuses['session-b'], 'confirmed');
    await reopened.dispose();
  });

  for (final reason in ['timeout', 'unknown 409', 'missing dependency']) {
    test('syncForDate cannot confirm queued B after rejected A ($reason)', () async {
      const date = '2026-09-06';
      final storage = FakeSyncStorage();
      final requests = <String>[];
      final client = respondingClient((options, handler) {
        final id = options.headers['x-exom-operation-id'] as String;
        requests.add(id);
        if (id == 'A') {
          handler.reject(DioException.badResponse(
            statusCode: 409,
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 409,
              data: {'code': 'PROGRESS_HISTORY_AMBIGUOUS'}),
          ));
        } else if (reason == 'timeout') {
          handler.reject(DioException.connectionTimeout(
            requestOptions: options, timeout: const Duration(seconds: 1),
          ));
        } else {
          handler.reject(DioException.badResponse(
            statusCode: 409,
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 409,
              data: <String, dynamic>{}),
          ));
        }
      });
      final service = OfflineSyncService(client, storage, isAuthenticated: () => true);
      await service.queueExerciseCompletion('te-a', date, completed: true,
        exerciseId: 'e-a', sessionId: 'session-a', operationId: 'A');
      await service.queueTrainingCompletion(date, trainingId: 'training-b',
        sessionId: 'session-b', rpe: 8, notes: 'Original');
      final originalB = Map<String, dynamic>.from(storage.actions.last);
      if (reason == 'missing dependency') {
        storage.actions.last['depends_on_feedback_ids'] = ['missing'];
      }

      expect(await service.syncForDate(date, sessionId: 'session-b'),
        SyncForDateResult.pendingSync);
      expect(requests, reason == 'missing dependency' ? ['A'] : ['A', originalB['id']]);
      expect(storage.actions, hasLength(2));
      expect(storage.actions.first['id'], 'A');
      expect(storage.actions.first['status'], 'failed');
      expect(storage.actions.first['failure_code'], 'PROGRESS_HISTORY_AMBIGUOUS');
      final remainingB = storage.actions.last;
      expect(remainingB['status'], 'queued');
      for (final field in ['id', 'expected_revision', 'training_id',
        'training_session_id', 'rpe', 'notes']) {
        expect(remainingB[field], originalB[field], reason: '$field must survive retry');
      }
      expect(storage.executionStatuses['session-b'], isNot('confirmed'));
      await service.dispose();
    });
  }

  test(
    'a missing mandatory feedback receipt never permits complete_training',
    () async {
      final storage = FakeSyncStorage(
        actions: [
          {
            'id': 'complete',
            'type': 'complete_training',
            'date': '2026-09-06',
            'training_id': 't',
            'status': 'queued',
            'depends_on_feedback_ids': ['missing'],
          },
        ],
      );
      var calls = 0;
      final client = respondingClient((o, h) {
        calls++;
        h.resolve(Response(requestOptions: o, statusCode: 200));
      });
      final service = OfflineSyncService(
        client,
        storage,
        isAuthenticated: () => true,
      );
      await service.syncPendingActions();
      expect(calls, 0);
      expect(storage.actions.single['status'], 'queued');
    },
  );
}
