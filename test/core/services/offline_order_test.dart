import 'dart:io';
import 'package:hive/hive.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'offline_sync_service_test.dart';

// Controlled local fixture bytes, not a playable-video/device-upload claim.
class _SyntheticFeedbackRepository extends Fake implements FeedbackRepository {
  static const bytes = [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50];
  int uploads = 0;
  int creations = 0;
  String? boundDate;
  String? boundSession;
  @override
  Future<ManagedFeedbackUpload> uploadMedia(File file, String contentType,
      {FeedbackUploadContext? context}) async {
    expect(await file.readAsBytes(), bytes);
    expect(contentType, 'video/mp4');
    expect(context?.isCurrent(), true);
    uploads++;
    return const ManagedFeedbackUpload(uploadId: 'synthetic-upload', fileUrl: 'https://fixture.invalid/video');
  }
  @override
  Future<FeedbackEntity> createFeedback({required String mediaType,
      required String mediaUrl, String? uploadId, String? notes, String? exerciseId,
      String? clientUploadId, String? feedbackKind, String? trainingId,
      String? trainingExerciseId, String? assignmentDate, String? sessionId}) async {
    expect(mediaType, 'VIDEO');
    expect(uploadId, 'synthetic-upload');
    expect(feedbackKind, 'LAST_SET');
    expect(trainingExerciseId, 'fixture-te');
    boundDate = assignmentDate;
    boundSession = sessionId;
    creations++;
    return FeedbackEntity(id: 'synthetic-feedback', mediaType: mediaType,
      mediaUrl: mediaUrl, status: 'PENDING', createdAt: DateTime.utc(2026, 10, 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('persisted failed exercise blocks completion after reopen without unsafe retry', () async {
    final directory = await Directory.systemTemp.createTemp('exom-sync-restart-');
    Hive.init(directory.path);
    await Hive.openBox('cache_box');
    var session = const LocalAuthSession(uid: 'synthetic-owner', generation: 1);
    LocalStorage storage() => LocalStorage(currentSession: () => session);
    var store = storage();
    var calls = 0;
    final client = respondingClient((options, handler) {
      calls++;
      handler.reject(DioException.badResponse(statusCode: 400,
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 400,
          data: {'code': 'INVALID_EXERCISE'})));
    });
    OfflineSyncService service() => OfflineSyncService(client, store,
      isAuthenticated: () => true,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    var sync = service();
    await sync.queueExerciseCompletion('fixture-te', '2026-10-01',
      completed: true, exerciseId: 'fixture-e', trainingId: 'fixture-training',
      sessionId: 'fixture-session', operationId: 'stable-exercise');
    await sync.queueTrainingCompletion('2026-10-01',
      trainingId: 'fixture-training', sessionId: 'fixture-session', rpe: 8);
    await sync.syncPendingActions();
    expect(calls, 1);
    final original = store.getPendingSyncActions();
    expect(original.first['status'], 'failed');
    expect(original.last['status'], 'queued');
    await sync.dispose();
    await Hive.close();
    await Hive.openBox('cache_box');
    store = storage();
    sync = service();
    await sync.syncPendingActions();
    expect(calls, 1, reason: 'restart must retain the failed same-day head');
    expect(store.getPendingSyncActions(), original);
    expect(sync.completionBlocker('fixture-training', '2026-10-01', 'fixture-session')?.kind,
      CompletionSyncBlockerKind.failed);
    expect(sync.completionBlocker('fixture-training', '2026-10-01', 'fixture-session')?.retryActionId,
      isNull);
    expect(sync.completionBlocker('fixture-training', '2026-11-01', 'fixture-session'), isNull);
    await sync.retryAction('stable-exercise');
    expect(calls, 1, reason: 'nonretryable failure requires correction, not blind replay');
    session = const LocalAuthSession(uid: 'other-owner', generation: 2);
    expect(store.getPendingSyncActions(), isEmpty);
    await sync.dispose();
    await Hive.close();
  });
  test('mandatory synthetic video producer and receipts survive month change and Hive reopen exactly once', () async {
    final directory = await Directory.systemTemp.createTemp('exom-video-restart-');
    Hive.init(directory.path);
    await Hive.openBox('cache_box');
    const owner = LocalAuthSession(uid: 'synthetic-owner', generation: 1);
    LocalStorage storage() => LocalStorage(currentSession: () => owner);
    var store = storage();
    var authenticated = false;
    final requests = <({String id, Object? revision, String path})>[];
    var revision = 0;
    final client = respondingClient((options, handler) {
      requests.add((id: options.headers['x-exom-operation-id'] as String,
        revision: options.headers['x-exom-revision'], path: options.path));
      handler.resolve(Response(requestOptions: options, statusCode: 200,
        data: {'date': '2026-10-01', 'sync_revision': ++revision,
          'operation_revision': revision, 'exercises_completed': <Map<String, dynamic>>[],
          'meals_completed': <String>[]}));
    });
    OfflineSyncService service() => OfflineSyncService(client, store,
      isAuthenticated: () => authenticated,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    var sync = service();
    final execution = await store.createTrainingExecution('fixture-training', '2026-10-01');
    final repository = _SyntheticFeedbackRepository();
    final feedback = FeedbackUploadQueueService(repository, store, sync,
      isAuthenticated: () => authenticated,
      applicationSupportDirectory: () async => directory,
      deleteFile: (_) async => throw const FileSystemException('synthetic cleanup retry'),
      connectivityChanges: const Stream<bool>.empty());
    final video = File('${directory.path}/synthetic.mp4');
    await video.writeAsBytes(_SyntheticFeedbackRepository.bytes);
    final feedbackId = await feedback.enqueue(file: video,
      contentType: 'video/mp4', mediaType: 'VIDEO', feedbackKind: 'LAST_SET',
      exerciseId: 'fixture-e', trainingId: 'fixture-training', trainingExerciseId: 'fixture-te',
      assignmentDate: '2026-10-01', sessionId: execution);
    await sync.queueExerciseCompletion('fixture-te', '2026-10-01', completed: true,
      exerciseId: 'fixture-e', trainingId: 'fixture-training', sessionId: execution,
      lastSetFeedbackClientUploadId: feedbackId, operationId: 'mandatory-exercise');
    await sync.queueTrainingCompletion('2026-10-01', trainingId: 'fixture-training',
      sessionId: execution, rpe: 8);
    final completionId = store.getPendingSyncActions().last['id'];
    expect(sync.completionBlocker('fixture-training', '2026-10-01', execution)?.kind,
      CompletionSyncBlockerKind.feedbackWaiting);
    authenticated = true;
    await feedback.processQueue();
    expect(repository.uploads, 1);
    expect(repository.creations, 1);
    expect(repository.boundDate, '2026-10-01');
    expect(repository.boundSession, execution);
    expect(store.getFeedbackUploadQueue().single['status'], 'completed');
    expect(store.getFeedbackUploadQueue().single['cleanup_pending'], true);
    expect(requests.map((r) => r.id), ['mandatory-exercise', completionId]);
    expect(requests.map((r) => r.revision), [0, 1]);
    expect(store.getPendingSyncActions(), isEmpty);
    expect(store.getConfirmedTrainingExecutions('fixture-training', '2026-10-01').single['id'], execution);
    await feedback.dispose();
    await sync.dispose();
    await Hive.close();
    await Hive.openBox('cache_box');
    store = storage();
    sync = service();
    expect(store.getConfirmedTrainingExecutions('fixture-training', '2026-11-01'), isEmpty);
    expect(store.getConfirmedTrainingExecutions('fixture-training', '2026-10-01').single['id'], execution);
    await sync.syncPendingActions();
    expect(requests, hasLength(2));
    expect(store.getPendingSyncActions(), isEmpty);
    expect(store.getFeedbackUploadQueue().single['cleanup_pending'], true);
    await sync.dispose();
    await Hive.close();
  });

  test('receipt missing head is recoverable only with stable replay after persisted restart', () async {
    final directory = await Directory.systemTemp.createTemp('exom-receipt-restart-');
    Hive.init(directory.path);
    await Hive.openBox('cache_box');
    var owner = const LocalAuthSession(uid: 'synthetic-owner', generation: 1);
    LocalStorage storage() => LocalStorage(currentSession: () => owner);
    var store = storage();
    var authenticated = true;
    var supplyReceipt = false;
    final requests = <({String id, Object? revision, Object? data})>[];
    final client = respondingClient((options, handler) {
      requests.add((id: options.headers['x-exom-operation-id'] as String,
        revision: options.headers['x-exom-revision'], data: options.data));
      final revision = options.path.contains('/exercises/') ? 1 : 2;
      handler.resolve(Response(requestOptions: options, statusCode: 200,
        data: supplyReceipt ? {'date': '2026-10-01', 'operation_revision': revision,
          'sync_revision': revision, 'exercises_completed': <Map<String, dynamic>>[],
          'meals_completed': <String>[]} : <String, dynamic>{}));
    });
    OfflineSyncService service() => OfflineSyncService(client, store,
      isAuthenticated: () => authenticated,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty());
    var sync = service();
    final execution = await store.createTrainingExecution('fixture-training', '2026-10-01');
    await sync.queueExerciseCompletion('fixture-te', '2026-10-01', completed: true,
      exerciseId: 'fixture-e', trainingId: 'fixture-training', sessionId: execution,
      operationId: 'receipt-exercise');
    await sync.queueTrainingCompletion('2026-10-01', trainingId: 'fixture-training',
      sessionId: execution, rpe: 8);
    await sync.syncPendingActions();
    expect(requests, hasLength(1));
    final original = store.getPendingSyncActions();
    expect(original.first['last_error'], 'progress_receipt_missing');
    await sync.dispose();
    await Hive.close();
    await Hive.openBox('cache_box');
    store = storage();
    sync = service();
    final blocker = sync.completionBlocker('fixture-training', '2026-10-01', execution);
    expect(blocker?.kind, CompletionSyncBlockerKind.receiptMissing);
    expect(blocker?.retryActionId, 'receipt-exercise');
    expect(store.getConfirmedTrainingExecutions('fixture-training', '2026-10-01'), isEmpty);
    authenticated = false;
    await sync.retryAction('receipt-exercise');
    expect(store.getPendingSyncActions(), original, reason: 'revoked session must not revive failed operations');
    owner = const LocalAuthSession(uid: 'other-owner', generation: 2);
    authenticated = true;
    expect(sync.completionBlocker('fixture-training', '2026-10-01', execution), isNull);
    await sync.retryAction('receipt-exercise');
    expect(requests, hasLength(1));
    owner = const LocalAuthSession(uid: 'synthetic-owner', generation: 3);
    supplyReceipt = true;
    await sync.retryAction('receipt-exercise');
    expect(requests[1].id, requests[0].id);
    expect(requests[1].revision, requests[0].revision);
    expect(requests[1].data, requests[0].data,
      reason: 'exact original operation/payload/revision must be replayed');
    expect(requests.last.id, original.last['id']);
    expect(requests.last.revision, 1);
    expect(store.getPendingSyncActions(), isEmpty);
    expect(store.getConfirmedTrainingExecutions('fixture-training', '2026-10-01').single['id'], execution);
    await sync.syncPendingActions();
    expect(requests, hasLength(3));
    await sync.dispose();
    await Hive.close();
  });

  test('manual recovery cannot acknowledge across an awaited owner generation change', () async {
    final directory = await Directory.systemTemp.createTemp('exom-retry-generation-');
    Hive.init(directory.path);
    await Hive.openBox('cache_box');
    var owner = const LocalAuthSession(uid: 'synthetic-owner', generation: 1);
    final store = LocalStorage(currentSession: () => owner);
    await store.savePendingSyncActions([{
      ...store.queueIdentity, 'id': 'generation-op', 'type': 'complete_training',
      'training_id': 'fixture', 'training_session_id': 'execution',
      'date': '2026-10-01', 'status': 'failed', 'last_error': 'progress_receipt_missing',
      'expected_revision': 0,
    }]);
    final sync = OfflineSyncService(respondingClient((options, handler) {
      owner = const LocalAuthSession(uid: 'other-owner', generation: 2);
      handler.resolve(Response(requestOptions: options, statusCode: 200,
        data: {'date': '2026-10-01', 'operation_revision': 1, 'sync_revision': 1}));
    }), store, isAuthenticated: () => true);
    await sync.retryAction('generation-op');
    expect(store.getPendingSyncActions(), isEmpty);
    expect(store.getCachedMap('server_progress_2026-10-01'), isNull);
    owner = const LocalAuthSession(uid: 'synthetic-owner', generation: 3);
    expect(store.getPendingSyncActions().single['id'], 'generation-op');
    expect(store.getPendingSyncActions().single['expected_revision'], 0);
    expect(store.getPendingSyncActions().single['status'], 'uploading');
    expect(store.getCachedMap('server_progress_2026-10-01'), isNull);
    await sync.dispose();
    await Hive.close();
  });

  test('blocker diagnosis shares historical ambiguity exemption and never mutates proof', () async {
    final storage = FakeSyncStorage(actions: [
      {'id': 'a', 'date': '2026-10-01', 'status': 'failed',
        'last_error': 'progress_conflict_review_required',
        'failure_code': 'PROGRESS_HISTORY_AMBIGUOUS', 'training_session_id': 'session-a'},
      {'id': 'b', 'date': '2026-10-01', 'status': 'queued', 'format_version': 2,
        'type': 'complete_training', 'training_id': 'fixture', 'training_session_id': 'session-b'},
    ]);
    final sync = OfflineSyncService(respondingClient((_, _) {}), storage,
      isAuthenticated: () => false);
    expect(sync.completionBlocker('fixture', '2026-10-01', 'session-b'), isNull);
    storage.actions.first['failure_code'] = 'PROGRESS_VERSION_CONFLICT';
    expect(sync.completionBlocker('fixture', '2026-10-01', 'session-b')?.kind,
      CompletionSyncBlockerKind.conflict);
    storage.actions.first['date'] = '2026-09-30';
    expect(sync.completionBlocker('fixture', '2026-10-01', 'session-b'), isNull);
    storage.actions.last['depends_on_feedback_ids'] = ['missing-proof'];
    expect(sync.completionBlocker('fixture', '2026-10-01', 'session-b')?.kind,
      CompletionSyncBlockerKind.feedbackMissing);
    expect(storage.actions.last['status'], 'queued');
    expect(storage.getFeedbackUploadQueue(), isEmpty);
    await sync.dispose();
  });

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
