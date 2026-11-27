import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/features/progress_photos/data/datasources/progress_photo_remote_datasource.dart';
import 'package:exom_app/features/progress_photos/data/repositories/progress_photo_repository_impl.dart';
import 'package:exom_app/features/progress_photos/services/progress_photo_upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progress_photo_upload_queue_service_test.dart' show PhotoStorage;

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-photo-recovery-');
  });
  tearDown(() => directory.delete(recursive: true));

  for (final known in [false, true]) {
    test('missing progress photo source: known checkpoint=$known', () async {
      final storage = PhotoStorage(
        const LocalAuthSession(uid: 'A', generation: 1),
      );
      storage.all = [
        {
          'id': 'stable',
          ...storage.progressPhotoQueueIdentity,
          'status': 'queued',
          'file_path': '${directory.path}/missing.jpg',
          'content_type': 'image/jpeg',
          'session_id': 'session',
          'session_operation_id': 'session-operation',
          'upload_operation_id': 'upload-operation',
          'association_operation_id': 'association-operation',
          'civil_session_date': '2026-11-04',
          'view': 'FRONT',
          'upload_checkpoint': {
            if (known) 'upload_id': 'known',
            'generation': 2,
          },
        },
      ];
      final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
      final paths = <String>[];
      final associations = <String>{};
      var associationAttempts = 0;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            if (options.path == '/uploads/sessions/known/complete') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'file_url': 'r2://known'},
                ),
              );
            } else if (options.path ==
                '/progress-photos/sessions/session/photos') {
              final data = options.data as Map;
              expect(data['upload_id'], 'known');
              expect(data['operation_id'], 'association-operation');
              associations.add(data['operation_id'] as String);
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
                      'id': 'photo',
                      'view': 'FRONT',
                      'image_url': 'r2://known',
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
      final queue = ProgressPhotoUploadQueueService(
        ProgressPhotoRepositoryImpl(ProgressPhotoRemoteDataSourceImpl(api)),
        storage,
        isAuthenticated: () => true,
        connectivityChanges: const Stream.empty(),
      );
      addTearDown(queue.dispose);
      await queue.processQueue();
      expect(storage.all.single['status'], known ? 'queued' : 'failed');
      if (known) {
        final checkpoint = storage.all.single['upload_checkpoint'] as Map;
        expect(checkpoint['upload_id'], 'known');
        expect(checkpoint['generation'], 2);
        expect(checkpoint['phase'], 'completion_confirmed');
        storage.all.single.remove('next_attempt_at');
        await queue.processQueue();
        expect(storage.all.single['status'], 'completed');
        expect(associationAttempts, 2);
        expect(associations, {'association-operation'});
        expect(paths, [
          '/uploads/sessions/known/complete',
          '/progress-photos/sessions/session/photos',
          '/progress-photos/sessions/session/photos',
        ]);
      } else {
        expect(storage.all.single['last_error'], 'progress_photo_file_missing');
        expect(paths, isEmpty);
      }
      expect(storage.all.single['upload_operation_id'], 'upload-operation');
      expect(
        storage.all.single['association_operation_id'],
        'association-operation',
      );
    });
  }

  for (final nextOwner in ['A', 'B']) {
    test(
      'progress reconciliation is invalid after session generation switches to $nextOwner',
      () async {
        final storage = PhotoStorage(
          const LocalAuthSession(uid: 'A', generation: 1),
        );
        storage.all = [
          {
            'id': 'stable',
            ...storage.progressPhotoQueueIdentity,
            'status': 'queued',
            'file_path': '${directory.path}/missing.jpg',
            'content_type': 'image/jpeg',
            'session_id': 'session',
            'session_operation_id': 'session-operation',
            'upload_operation_id': 'upload-operation',
            'association_operation_id': 'association-operation',
            'civil_session_date': '2026-11-04',
            'view': 'FRONT',
            'upload_checkpoint': {'upload_id': 'known', 'generation': 2},
          },
        ];
        final started = Completer<void>();
        final release = Completer<void>();
        final paths = <String>[];
        final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
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
              } else if (options.path ==
                  '/progress-photos/sessions/session/photos') {
                expect(
                  (options.data as Map)['operation_id'],
                  'association-operation',
                );
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'id': 'photo',
                      'view': 'FRONT',
                      'image_url': 'r2://known',
                    },
                  ),
                );
              } else {
                fail('Unexpected request: ${options.path}');
              }
            },
          ),
        );
        final queue = ProgressPhotoUploadQueueService(
          ProgressPhotoRepositoryImpl(ProgressPhotoRemoteDataSourceImpl(api)),
          storage,
          isAuthenticated: () => true,
          connectivityChanges: const Stream.empty(),
        );
        addTearDown(queue.dispose);
        final processing = queue.processQueue();
        await started.future;
        storage.current = LocalAuthSession(uid: nextOwner, generation: 2);
        release.complete();
        await processing;
        expect(paths, ['/uploads/sessions/known/complete']);
        expect(storage.all.single['status'], 'processing');
        expect(
          (storage.all.single['upload_checkpoint'] as Map)['phase'],
          'completion_reconciling',
        );
        storage.current = const LocalAuthSession(uid: 'A', generation: 3);
        await queue.processQueue();
        expect(storage.all.single['status'], 'completed');
        expect(storage.all.single['upload_operation_id'], 'upload-operation');
        expect(paths, [
          '/uploads/sessions/known/complete',
          '/uploads/sessions/known/complete',
          '/progress-photos/sessions/session/photos',
        ]);
      },
    );
  }
}
