import 'package:dio/dio.dart';
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
  test(
    'v2 conflicts retain user data and block later writes instead of auto-rebasing',
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
                'code': 'PROGRESS_VERSION_CONFLICT',
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
