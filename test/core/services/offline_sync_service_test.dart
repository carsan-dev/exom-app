import 'dart:async';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
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
            Response(requestOptions: options, statusCode: 200),
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

    final sync = service.syncPendingActions();
    await firstRequestStarted.future;
    await service.queueMealCompletion('meal-2', '2026-09-01', completed: true);
    releaseFirstRequest.complete();
    await sync;

    expect(requests, ['meal-1', 'meal-2']);
    expect(storage.actions, isEmpty);
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
