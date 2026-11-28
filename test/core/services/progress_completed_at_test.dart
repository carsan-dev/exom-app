import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'offline_sync_service_test.dart';

// C-O1: the completion time is captured on the phone when the completion is
// created (the exercise's last logged set) and travels inside the queued
// action, so a completion synced later keeps it. Actions queued by earlier
// versions (no `completed_at`) are replayed byte for byte: the API hashes the
// body per operation id, and adding a field to an operation it already
// accepted would answer PROGRESS_OPERATION_CONFLICT.

const _date = '2026-11-27';

// T0: last set logged. T1: completion queued (end of the rest). T2: sync.
final _t0 = DateTime.utc(2026, 11, 27, 13, 56, 51, 120);
final _t1 = DateTime.utc(2026, 11, 27, 13, 58, 0, 5);
final _t2 = DateTime.utc(2026, 11, 27, 16, 30, 0);
const _t0Wire = '2026-11-27T13:56:51.120Z';
const _t1Wire = '2026-11-27T13:58:00.005Z';

const _okProgress = {
  'operation_revision': 1,
  'sync_revision': 1,
  'exercises_completed': <Map<String, dynamic>>[],
  'meals_completed': <String>[],
};

ApiClient _recording(
  List<Map<String, dynamic>> bodies, {
  List<int> statuses = const [],
}) {
  var call = 0;
  return respondingClient((options, handler) {
    final data = options.data;
    bodies.add(data is Map ? Map<String, dynamic>.from(data) : {});
    final status = call < statuses.length ? statuses[call] : 200;
    call++;
    if (status != 200) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: status),
      ));
      return;
    }
    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: _okProgress),
    );
  });
}

OfflineSyncService _service(
  ApiClient client,
  LocalStorage storage, {
  required DateTime now,
  bool online = true,
}) => OfflineSyncService(
  client,
  storage,
  isAuthenticated: () => online,
  authenticationChanges: const Stream<bool>.empty(),
  connectivityChanges: const Stream<bool>.empty(),
  now: () => now,
);

Future<void> _queueOffline(
  FakeSyncStorage storage, {
  DateTime? completedAt,
  String? operationId = 'op-1',
}) async {
  final offline = _service(
    respondingClient((options, handler) {}),
    storage,
    now: _t1,
    online: false,
  );
  await offline.queueExerciseCompletion('te-1', _date,
      completed: true,
      exerciseId: 'ex-1',
      sessionId: 'execution-1',
      completedAt: completedAt,
      operationId: operationId);
  await offline.dispose();
}

void main() {
  test('a completion queued at T1 whose last set was logged at T0 is sent '
      'at T2 with T0', () async {
    final storage = FakeSyncStorage();
    await _queueOffline(storage, completedAt: _t0);
    expect(storage.actions.single['completed_at'], _t0Wire);
    expect(storage.actions.single['queued_at'], _t1.toIso8601String());

    final bodies = <Map<String, dynamic>>[];
    final online = _service(_recording(bodies), storage, now: _t2);
    await online.syncPendingActions();

    expect(bodies.single['completed_at'], _t0Wire);
    expect(storage.actions, isEmpty);
    await online.dispose();
  });

  test('a completion with sub-millisecond precision is sent in the '
      'millisecond form the draft can restore', () async {
    final storage = FakeSyncStorage();
    await _queueOffline(storage,
        completedAt: DateTime.utc(2026, 11, 27, 13, 56, 51, 120, 987));
    expect(storage.actions.single['completed_at'], _t0Wire);
  });

  test('a manual completion without a set or a frozen identity is dated '
      'when it is created, not when it is synced', () async {
    final storage = FakeSyncStorage();
    await _queueOffline(storage, operationId: null);
    expect(storage.actions.single['completed_at'], _t1Wire);

    final bodies = <Map<String, dynamic>>[];
    final online = _service(_recording(bodies), storage, now: _t2);
    await online.syncPendingActions();
    expect(bodies.single['completed_at'], _t1Wire);
    await online.dispose();
  });

  test('a frozen completion identity without a set time (draft of an '
      'earlier version) is sent without the field', () async {
    final storage = FakeSyncStorage();
    await _queueOffline(storage);
    expect(storage.actions.single.containsKey('completed_at'), isFalse);

    final bodies = <Map<String, dynamic>>[];
    final online = _service(_recording(bodies), storage, now: _t2);
    await online.syncPendingActions();
    expect(bodies.single.containsKey('completed_at'), isFalse);
    await online.dispose();
  });

  test('unmarking never carries a completion time', () async {
    final storage = FakeSyncStorage();
    final offline = _service(
      respondingClient((options, handler) {}),
      storage,
      now: _t1,
      online: false,
    );
    await offline.queueExerciseCompletion('te-1', _date,
        completed: false, sessionId: 'execution-1', completedAt: _t0);
    expect(storage.actions.single.containsKey('completed_at'), isFalse);
    await offline.dispose();
  });

  group('legacy queued actions', () {
    Map<String, dynamic> legacyAction({String status = 'queued'}) => {
      'id': 'legacy-op',
      'format_version': 2,
      'type': 'mark_exercise_completed',
      'training_exercise_id': 'te-1',
      'exercise_id': 'ex-1',
      'training_session_id': 'execution-1',
      'date': _date,
      'expected_revision': 0,
      'status': status,
      'attempts': status == 'failed' ? 5 : 0,
      if (status == 'failed') 'last_error': 'sync_request_failed',
      'queued_at': _t1.toIso8601String(),
    };

    test('an action persisted without the field is sent without it, never '
        'derived from queued_at', () async {
      final storage = FakeSyncStorage(actions: [legacyAction()]);
      final bodies = <Map<String, dynamic>>[];
      final online = _service(_recording(bodies), storage, now: _t2);
      await online.syncPendingActions();

      expect(bodies.single.containsKey('completed_at'), isFalse);
      expect(storage.actions, isEmpty);
      await online.dispose();
    });

    test('dispatching the same operation again with a set time keeps the '
        'persisted body', () async {
      final storage = FakeSyncStorage(actions: [legacyAction()]);
      final offline = _service(
        respondingClient((options, handler) {}),
        storage,
        now: _t1,
        online: false,
      );
      await offline.queueExerciseCompletion('te-1', _date,
          completed: true,
          exerciseId: 'ex-1',
          sessionId: 'execution-1',
          completedAt: _t0,
          operationId: 'legacy-op');
      await offline.dispose();
      expect(storage.actions.single.containsKey('completed_at'), isFalse);

      final bodies = <Map<String, dynamic>>[];
      final online = _service(_recording(bodies), storage, now: _t2);
      await online.syncPendingActions();
      expect(bodies.single.containsKey('completed_at'), isFalse);
      await online.dispose();
    });

    test('retrying a failed legacy action does not add the field', () async {
      final storage = FakeSyncStorage(actions: [legacyAction(status: 'failed')]);
      final bodies = <Map<String, dynamic>>[];
      final online = _service(_recording(bodies), storage, now: _t2);
      await online.queueExerciseCompletion('te-1', _date,
          completed: true,
          exerciseId: 'ex-1',
          sessionId: 'execution-1',
          completedAt: _t0,
          operationId: 'legacy-op');
      await online.syncPendingActions();

      expect(bodies, isNotEmpty);
      expect(bodies.every((body) => !body.containsKey('completed_at')), isTrue);
      await online.dispose();
    });

    test('a restored training completion keeps its legacy body', () async {
      final storage = FakeSyncStorage();
      storage.discarded['execution-1'] = {
        'id': 'legacy-training-op',
        'format_version': 2,
        'type': 'complete_training',
        'date': _date,
        'training_id': 'training-1',
        'training_session_id': 'execution-1',
        'rpe': 7,
        'expected_revision': 0,
        'status': 'failed',
        'attempts': 1,
        'queued_at': _t1.toIso8601String(),
      };
      final bodies = <Map<String, dynamic>>[];
      final online = _service(_recording(bodies), storage, now: _t2);
      await online.queueTrainingCompletion(_date,
          trainingId: 'training-1', sessionId: 'execution-1', rpe: 7);
      expect(storage.actions.isEmpty ||
          !storage.actions.single.containsKey('completed_at'), isTrue);
      await online.syncPendingActions();

      expect(bodies.single.containsKey('completed_at'), isFalse);
      await online.dispose();
    });
  });

  group('retries', () {
    test('a retried completion sends exactly the same value', () async {
      final storage = FakeSyncStorage();
      await _queueOffline(storage, completedAt: _t0);

      final bodies = <Map<String, dynamic>>[];
      final online = _service(
        _recording(bodies, statuses: [503]),
        storage,
        now: _t2,
      );
      await online.syncPendingActions();
      expect(storage.actions.single['completed_at'], _t0Wire);

      // The draft dispatches the same operation again with another time
      // (e.g. a later clock): the queued value wins.
      await online.queueExerciseCompletion('te-1', _date,
          completed: true,
          exerciseId: 'ex-1',
          sessionId: 'execution-1',
          completedAt: _t2,
          operationId: 'op-1');
      // The backoff elapses.
      storage.actions.single.remove('next_attempt_at');
      await online.syncPendingActions();

      expect(bodies.length, greaterThanOrEqualTo(2));
      expect(bodies.map((body) => body['completed_at']).toSet(), {_t0Wire});
      expect(storage.actions, isEmpty);
      await online.dispose();
    });

    test('a training completion is dated when it is queued and keeps that '
        'value across retries', () async {
      final storage = FakeSyncStorage();
      final offline = _service(
        respondingClient((options, handler) {}),
        storage,
        now: _t1,
        online: false,
      );
      await offline.queueTrainingCompletion(_date,
          trainingId: 'training-1', sessionId: 'execution-1', rpe: 8);
      await offline.dispose();
      expect(storage.actions.single['completed_at'], _t1Wire);

      final bodies = <Map<String, dynamic>>[];
      final online = _service(
        _recording(bodies, statuses: [503]),
        storage,
        now: _t2,
      );
      await online.syncPendingActions();
      await online.queueTrainingCompletion(_date,
          trainingId: 'training-1', sessionId: 'execution-1', rpe: 8);
      storage.actions.single.remove('next_attempt_at');
      await online.syncPendingActions();

      expect(bodies.length, greaterThanOrEqualTo(2));
      expect(bodies.map((body) => body['completed_at']).toSet(), {_t1Wire});
      await online.dispose();
    });
  });

  test('the persisted queue round-trips the value through Hive', () async {
    final directory = await Directory.systemTemp.createTemp('exom-co1-');
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    Hive.init(directory.path);
    await Hive.openBox('cache_box');
    const session = LocalAuthSession(uid: 'synthetic-owner', generation: 1);
    var store = LocalStorage(currentSession: () => session);

    final offline = _service(
      respondingClient((options, handler) {}),
      store,
      now: _t1,
      online: false,
    );
    await offline.queueExerciseCompletion('te-1', _date,
        completed: true,
        exerciseId: 'ex-1',
        sessionId: 'execution-1',
        completedAt: _t0,
        operationId: 'op-hive');
    await offline.dispose();
    final written = store.getPendingSyncActions();
    expect(written.single['completed_at'], _t0Wire);

    await Hive.close();
    await Hive.openBox('cache_box');
    store = LocalStorage(currentSession: () => session);
    final restored = store.getPendingSyncActions();
    expect(restored, written);

    final bodies = <Map<String, dynamic>>[];
    final online = _service(_recording(bodies), store, now: _t2);
    await online.syncPendingActions();
    expect(bodies.single['completed_at'], _t0Wire);
    await online.dispose();
  });
}
