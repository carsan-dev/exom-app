import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/services/pending_progress_overlay.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_sync_service_test.dart';

// Drafts written by the released app may hold a set with only RIR (no reps,
// seconds or weight). The API rejects such a set with a non-retryable 400
// (progress.service.ts markExerciseCompleted). Owner decision: repair on
// read, without migration; that set counts as not registered and the
// persisted draft and queue entry are left untouched.

const _date = '2026-11-18';

const _legacySets = <Map<String, dynamic>>[
  {'set_number': 1, 'rir': 2},
  {'set_number': 2, 'reps': 8, 'weight_kg': 60.0, 'rir': 8},
  {'set_number': 3, 'seconds': 30},
];

const _okProgress = {
  'operation_revision': 1,
  'sync_revision': 1,
  'exercises_completed': <Map<String, dynamic>>[],
  'meals_completed': <String>[],
};

/// Mirrors the API rule: every set needs reps, seconds or weight.
ApiClient _apiLikeServer(List<Map<String, dynamic>> requests) =>
    respondingClient((options, handler) {
      final body = Map<String, dynamic>.from(options.data as Map);
      requests.add(body);
      final sets = (body['sets'] as List?) ?? const [];
      final invalid = sets.any((set) =>
          (set as Map)['reps'] == null &&
          set['seconds'] == null &&
          set['weight_kg'] == null);
      if (invalid) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 400,
            data: {
              'statusCode': 400,
              'message': 'Cada serie debe incluir repeticiones, segundos o peso',
            },
          ),
        ));
        return;
      }
      handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: _okProgress),
      );
    });

OfflineSyncService _service(ApiClient client, FakeSyncStorage storage,
        {bool online = true}) =>
    OfflineSyncService(
      client,
      storage,
      isAuthenticated: () => online,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );

List<SetPerformance> _fromDraft(List<Map<String, dynamic>> sets) =>
    sets.map(SetPerformance.fromJson).toList();

void main() {
  test('a legacy draft with a RIR-only set mixed with valid sets completes '
      'and only the RIR-only set is left out of the request', () async {
    final storage = FakeSyncStorage();
    final requests = <Map<String, dynamic>>[];
    final service = _service(_apiLikeServer(requests), storage);

    await service.queueExerciseCompletion('te-1', _date,
        completed: true,
        exerciseId: 'ex-1',
        weightUsed: 60.0,
        sets: _fromDraft(_legacySets),
        operationId: 'op-mixed');
    await service.syncPendingActions();

    expect(requests, hasLength(1));
    expect(requests.single['sets'], [
      {'set_number': 2, 'reps': 8, 'weight_kg': 60.0, 'rir': 8},
      {'set_number': 3, 'seconds': 30},
    ]);
    expect(storage.actions, isEmpty, reason: 'acknowledged, not failed');
    await service.dispose();
  });

  test('a completion whose only set is RIR-only is accepted with no '
      'registered sets', () async {
    final storage = FakeSyncStorage();
    final requests = <Map<String, dynamic>>[];
    final service = _service(_apiLikeServer(requests), storage);

    await service.queueExerciseCompletion('te-1', _date,
        completed: true,
        exerciseId: 'ex-1',
        sets: _fromDraft(const [
          {'set_number': 1, 'rir': 3},
        ]),
        operationId: 'op-single');
    await service.syncPendingActions();

    expect(requests.single['sets'], isEmpty);
    expect(storage.actions, isEmpty);
    await service.dispose();
  });

  test('an action queued by the released app with a RIR-only set replays '
      'without that set', () async {
    final storage = FakeSyncStorage(actions: [
      {
        'id': 'released-app-action',
        'type': 'mark_exercise_completed',
        'training_exercise_id': 'te-1',
        'exercise_id': 'ex-1',
        'training_id': 'training-1',
        'date': _date,
        'sets': _legacySets,
        'status': 'queued',
        'attempts': 0,
      },
    ]);
    final requests = <Map<String, dynamic>>[];
    final service = _service(_apiLikeServer(requests), storage);

    await service.syncPendingActions();

    expect(requests.single['sets'], [
      {'set_number': 2, 'reps': 8, 'weight_kg': 60.0, 'rir': 8},
      {'set_number': 3, 'seconds': 30},
    ]);
    expect(storage.actions, isEmpty);
    await service.dispose();
  });

  test('a completion that already failed with 400 succeeds when the same '
      'operation is dispatched again', () async {
    final storage = FakeSyncStorage(actions: [
      {
        'id': 'op-frozen',
        'format_version': 2,
        'type': 'mark_exercise_completed',
        'training_exercise_id': 'te-1',
        'exercise_id': 'ex-1',
        'date': _date,
        'sets': _legacySets,
        'status': 'failed',
        'attempts': 1,
        'retryable': false,
        'last_error': 'sync_request_failed',
      },
    ]);
    final requests = <Map<String, dynamic>>[];
    final service = _service(_apiLikeServer(requests), storage);

    await service.queueExerciseCompletion('te-1', _date,
        completed: true,
        exerciseId: 'ex-1',
        sets: _fromDraft(_legacySets),
        operationId: 'op-frozen');
    await service.syncPendingActions();

    expect(requests.single['sets'], [
      {'set_number': 2, 'reps': 8, 'weight_kg': 60.0, 'rir': 8},
      {'set_number': 3, 'seconds': 30},
    ]);
    expect(storage.actions, isEmpty);
    await service.dispose();
  });

  test('the queued RIR-only set is kept as written while the completion is '
      'pending', () async {
    final storage = FakeSyncStorage();
    final offline = _service(respondingClient((options, handler) {}), storage,
        online: false);
    await offline.queueExerciseCompletion('te-1', _date,
        completed: true,
        exerciseId: 'ex-1',
        sets: _fromDraft(_legacySets),
        operationId: 'op-pending');
    await offline.dispose();
    expect(storage.actions.single['sets'], _legacySets);

    final unavailable = _service(
      respondingClient((options, handler) => handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: options, statusCode: 503),
          ))),
      storage,
    );
    await unavailable.syncPendingActions();
    expect(storage.actions.single['id'], 'op-pending');
    expect(storage.actions.single['sets'], _legacySets);
    await unavailable.dispose();
  });

  test('the pending-progress overlay does not show a RIR-only set as done',
      () {
    final result = overlayPendingProgressActions(
      progress: {
        'exercises_completed': [
          {
            'training_exercise_id': 'te-1',
            'exercise_id': 'ex-1',
            'sets': [
              {'set_number': 1, 'reps': 10, 'weight_kg': 50.0},
            ],
          },
        ],
      },
      actions: [
        {
          'id': 'pending-action',
          'type': 'mark_exercise_completed',
          'training_exercise_id': 'te-1',
          'exercise_id': 'ex-1',
          'date': _date,
          'sets': _legacySets,
          'status': 'queued',
        },
      ],
      date: _date,
    );
    final entry = (result['exercises_completed'] as List).single as Map;
    // Same sets the replay sends; the stored set 1 is not overwritten.
    expect(entry['sets'], [
      {'set_number': 1, 'reps': 10, 'weight_kg': 50.0},
      {'set_number': 2, 'reps': 8, 'weight_kg': 60.0, 'rir': 8},
      {'set_number': 3, 'seconds': 30},
    ]);
  });

  test('a healthy completion produces a byte-identical request', () async {
    final storage = FakeSyncStorage();
    final requests = <Map<String, dynamic>>[];
    final service = _service(_apiLikeServer(requests), storage);

    await service.queueExerciseCompletion('te-1', _date,
        completed: true,
        exerciseId: 'ex-1',
        weightUsed: 62.5,
        sessionId: 'execution-1',
        sets: const [
          SetPerformance(setNumber: 1, reps: 8, weightKg: 62.5, rir: 2),
          SetPerformance(setNumber: 2, seconds: 45),
          SetPerformance(setNumber: 3, weightKg: 20.0, rir: 0),
        ],
        operationId: 'op-healthy');
    await service.syncPendingActions();

    expect(
      jsonEncode(requests.single),
      '{"exercise_id":"ex-1","training_exercise_id":"te-1",'
      '"date":"2026-11-18","training_session_id":"execution-1",'
      '"weight_used":62.5,"sets":['
      '{"set_number":1,"reps":8,"weight_kg":62.5,"rir":2},'
      '{"set_number":2,"seconds":45},'
      '{"set_number":3,"weight_kg":20.0,"rir":0}]}',
    );
    expect(storage.actions, isEmpty);
    await service.dispose();
  });
}
