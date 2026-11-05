import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/data/repositories/feedback_repository_impl.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'feedback_upload_queue_service_test.dart'
    show
        FakeFeedbackQueueStorage,
        FakeFeedbackRepository,
        FakeOfflineSyncService;

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'exom-feedback-recovery-',
    );
  });
  tearDown(() => directory.delete(recursive: true));

  for (final verified in [false, true]) {
    test(
      'missing feedback source retained when unsent; verified=$verified can associate',
      () async {
        final storage = FakeFeedbackQueueStorage([
          {
            'id': 'stable',
            'status': 'queued',
            'file_path': '${directory.path}/missing.mp4',
            'media_type': 'VIDEO',
            'content_type': 'video/mp4',
            if (verified) 'verified_upload_id': 'known',
            if (verified) 'verified_file_url': 'r2://known',
          },
        ]);
        final repository = FakeFeedbackRepository();
        final offline = FakeOfflineSyncService(storage);
        final queue = FeedbackUploadQueueService(
          repository,
          storage,
          offline,
          isAuthenticated: () => true,
          connectivityChanges: const Stream.empty(),
        );
        addTearDown(queue.dispose);
        addTearDown(offline.dispose);
        await queue.processQueue();
        expect(repository.uploadCalls, 0);
        expect(repository.createCalls, verified ? 1 : 0);
        expect(
          storage.queue.single['status'],
          verified ? 'completed' : 'failed',
        );
        expect(storage.queue.single['id'], 'stable');
        if (!verified) {
          expect(storage.queue.single['last_error'], 'file_missing');
        }
      },
    );
  }

  test(
    'unknown completion without source reconciles and replays lost association with same identity',
    () async {
      final storage = FakeFeedbackQueueStorage([
        {
          'id': 'stable',
          'status': 'queued',
          'file_path': '${directory.path}/missing.mp4',
          'media_type': 'VIDEO',
          'content_type': 'video/mp4',
          'upload_checkpoint': {'upload_id': 'known', 'generation': 2},
        },
      ]);
      final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
      final paths = <String>[];
      final associations = <String>{};
      var associationAttempts = 0;
      var preparations = 0;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            if (options.path == '/uploads/sessions/known/complete') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'data': {'file_url': 'r2://known'},
                  },
                ),
              );
            } else if (options.path == '/feedback') {
              final data = options.data as Map;
              expect(data['upload_id'], 'known');
              expect(data['client_upload_id'], 'stable');
              associations.add(data['client_upload_id'] as String);
              if (associationAttempts++ == 0) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.receiveTimeout,
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'data': {
                        'id': 'feedback',
                        'media_type': 'VIDEO',
                        'media_url': 'r2://known',
                        'status': 'PENDING',
                        'created_at': '2026-11-04T10:00:00Z',
                      },
                    },
                  ),
                );
              }
            } else {
              fail('Unexpected request: ${options.path}');
            }
          },
        ),
      );
      final repository = FeedbackRepositoryImpl(
        FeedbackRemoteDataSourceImpl(
          api,
          prepareFile: (file, _) async {
            preparations++;
            return file;
          },
        ),
      );
      final offline = FakeOfflineSyncService(storage);
      final queue = FeedbackUploadQueueService(
        repository,
        storage,
        offline,
        isAuthenticated: () => true,
        connectivityChanges: const Stream.empty(),
      );
      addTearDown(queue.dispose);
      addTearDown(offline.dispose);
      await queue.processQueue();
      expect(storage.queue.single['status'], 'queued');
      expect(storage.queue.single['verified_upload_id'], 'known');
      expect(
        (storage.queue.single['upload_checkpoint'] as Map)['generation'],
        2,
      );
      storage.queue.single.remove('next_attempt_at');
      await queue.processQueue();
      expect(storage.queue.single['status'], 'completed');
      expect(preparations, 0);
      expect(associationAttempts, 2);
      expect(associations, {'stable'});
      expect(paths, [
        '/uploads/sessions/known/complete',
        '/feedback',
        '/feedback',
      ]);
    },
  );

  for (final code in ['UPLOAD_EXPIRED', 'UNRELATED_CONFLICT']) {
    test(
      'association $code only authorizes generation renewal on explicit expiry',
      () async {
        final original = await File(
          '${directory.path}/original.mp4',
        ).writeAsBytes([1, 2, 3]);
        final storage = FakeFeedbackQueueStorage([
          {
            'id': 'stable',
            'status': 'queued',
            'file_path': original.path,
            'media_type': 'VIDEO',
            'content_type': 'video/mp4',
            'verified_upload_id': 'known',
            'verified_file_url': 'r2://known',
            'upload_checkpoint': {
              'upload_id': 'known',
              'generation': 2,
              'file_url': 'r2://known',
              'prepared_path': '${directory.path}/lost.mp4',
              'prepared_bytes': 3,
              'prepared_content_type': 'video/mp4',
              'legacy_metadata': 'retained',
            },
          },
        ]);
        final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
        final keys = <String>[];
        var creates = 0;
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/feedback') {
                expect((options.data as Map)['client_upload_id'], 'stable');
                if (creates++ == 0) {
                  handler.reject(
                    DioException.badResponse(
                      statusCode: 409,
                      requestOptions: options,
                      response: Response(
                        requestOptions: options,
                        statusCode: 409,
                        data: {'code': code},
                      ),
                    ),
                  );
                } else {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {
                        'data': {
                          'id': 'feedback',
                          'media_type': 'VIDEO',
                          'media_url': 'r2://renewed',
                          'status': 'PENDING',
                          'created_at': '2026-11-04T10:00:00Z',
                        },
                      },
                    ),
                  );
                }
              } else if (options.path == '/uploads/sessions') {
                keys.add(
                  (options.data as Map)['client_operation_id'] as String,
                );
                expect((options.data as Map)['bytes'], 4);
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {'upload_id': 'renewed'},
                  ),
                );
              } else if (options.path == '/uploads/sessions/renewed/complete') {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {'file_url': 'r2://renewed'},
                  ),
                );
              } else {
                fail('Unexpected request: ${options.path}');
              }
            },
          ),
        );
        final offline = FakeOfflineSyncService(storage);
        final queue = FeedbackUploadQueueService(
          FeedbackRepositoryImpl(
            FeedbackRemoteDataSourceImpl(
              api,
              prepareFile: (_, _) async =>
                  File('${directory.path}/new.mp4').writeAsBytes([1, 2, 3, 4]),
            ),
          ),
          storage,
          offline,
          isAuthenticated: () => true,
          connectivityChanges: const Stream.empty(),
        );
        addTearDown(queue.dispose);
        addTearDown(offline.dispose);
        await queue.processQueue();
        final checkpoint = storage.queue.single['upload_checkpoint'] as Map;
        expect(checkpoint['legacy_metadata'], 'retained');
        if (code == 'UPLOAD_EXPIRED') {
          expect(storage.queue.single['status'], 'queued');
          expect(checkpoint['generation'], 3);
          expect(checkpoint['upload_id'], isNull);
          storage.queue.single.remove('next_attempt_at');
          await queue.processQueue();
          expect(storage.queue.single['status'], 'completed');
          expect(keys, ['stable:3']);
          expect(
            (storage.queue.single['upload_checkpoint']
                as Map)['prepared_bytes'],
            4,
          );
        } else {
          expect(storage.queue.single['status'], 'failed');
          expect(checkpoint['generation'], 2);
          expect(checkpoint['upload_id'], 'known');
          expect(checkpoint['prepared_bytes'], 3);
          expect(keys, isEmpty);
          expect(await original.exists(), true);
        }
      },
    );
  }

  for (final nextOwner in ['A', 'B']) {
    test(
      'reconciliation cannot associate after session generation switches to $nextOwner',
      () async {
        Hive.init(directory.path);
        if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
          Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
        }
        await Hive.openBox('auth_box');
        await Hive.openBox('cache_box');
        await Hive.openBox('settings_box');
        await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
        addTearDown(Hive.close);
        var session = const LocalAuthSession(uid: 'A', generation: 1);
        final storage = LocalStorage(
          currentSession: () => session,
          environment: 'test',
        );
        await storage.saveFeedbackUploadQueue([
          {
            'id': 'stable',
            ...storage.queueIdentity,
            'status': 'queued',
            'file_path': '${directory.path}/missing.mp4',
            'content_type': 'video/mp4',
            'media_type': 'VIDEO',
            'upload_checkpoint': {'upload_id': 'known', 'generation': 2},
          },
        ]);
        final started = Completer<void>();
        final release = Completer<void>();
        final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
        final paths = <String>[];
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              paths.add(options.path);
              if (options.path == '/uploads/sessions/known/complete') {
                if (!started.isCompleted) {
                  started.complete();
                  await release.future;
                }
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {'file_url': 'r2://known'},
                  ),
                );
              } else if (options.path == '/feedback') {
                expect((options.data as Map)['client_upload_id'], 'stable');
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'data': {
                        'id': 'feedback',
                        'media_type': 'VIDEO',
                        'media_url': 'r2://known',
                        'status': 'PENDING',
                        'created_at': '2026-11-04T10:00:00Z',
                      },
                    },
                  ),
                );
              } else {
                fail('Unexpected request: ${options.path}');
              }
            },
          ),
        );
        final offline = FakeOfflineSyncService(storage);
        final queue = FeedbackUploadQueueService(
          FeedbackRepositoryImpl(
            FeedbackRemoteDataSourceImpl(
              api,
              prepareFile: (_, _) async => throw StateError('must not prepare'),
            ),
          ),
          storage,
          offline,
          isAuthenticated: () => true,
          connectivityChanges: const Stream.empty(),
        );
        addTearDown(queue.dispose);
        addTearDown(offline.dispose);
        final processing = queue.processQueue();
        await started.future;
        session = LocalAuthSession(uid: nextOwner, generation: 2);
        release.complete();
        await processing;
        expect(paths, ['/uploads/sessions/known/complete']);
        session = const LocalAuthSession(uid: 'A', generation: 3);
        final retained = storage.getFeedbackUploadQueue().single;
        expect(retained['status'], 'uploading');
        expect(
          (retained['upload_checkpoint'] as Map)['phase'],
          'completion_reconciling',
        );
        expect(retained['verified_upload_id'], isNull);
        await queue.processQueue();
        expect(storage.getFeedbackUploadQueue().single['status'], 'completed');
        expect(paths, [
          '/uploads/sessions/known/complete',
          '/uploads/sessions/known/complete',
          '/feedback',
        ]);
      },
    );
  }
}
