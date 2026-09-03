import 'dart:async';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });

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
