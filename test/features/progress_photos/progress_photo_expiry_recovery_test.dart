import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/features/progress_photos/data/datasources/progress_photo_remote_datasource.dart';
import 'package:exom_app/features/progress_photos/data/repositories/progress_photo_repository_impl.dart';
import 'package:exom_app/features/progress_photos/services/progress_photo_upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progress_photo_upload_queue_service_test.dart'
    show PhotoStorage, stableIds;

void main() {
  late Directory directory;
  late File file;
  late PhotoStorage storage;
  late ApiClient api;
  late List<String> paths;
  late List<Map> associations;
  late List<Map> sessions;
  String? errorCode;
  int errorStatus = 409;
  bool loseAssociationResponse = false;
  Completer<void>? started;
  Completer<void>? release;

  ProgressPhotoUploadQueueService queue() => ProgressPhotoUploadQueueService(
    ProgressPhotoRepositoryImpl(ProgressPhotoRemoteDataSourceImpl(api)),
    storage,
    isAuthenticated: () => true,
    connectivityChanges: const Stream.empty(),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-photo-expiry-');
    file = await File('${directory.path}/photo.jpg').writeAsBytes([1, 2, 3]);
    storage = PhotoStorage(const LocalAuthSession(uid: 'A', generation: 1));
    storage.all = [
      {
        'id': 'stable',
        ...storage.progressPhotoQueueIdentity,
        'status': 'queued',
        'file_path': file.path,
        'content_type': 'image/jpeg',
        'session_id': 'session',
        'session_operation_id': 'session-operation',
        'upload_operation_id': 'upload-operation',
        'association_operation_id': 'association-operation',
        'replaces_photo_id': 'original-photo',
        'civil_session_date': '2026-11-04',
        'view': 'FRONT',
        'upload_checkpoint': {
          'phase': 'completion_confirmed',
          'generation': 2,
          'upload_id': 'old',
          'file_url': 'r2://old',
          'prepared_path': file.path,
          'prepared_bytes': 99,
          'prepared_content_type': 'image/png',
          'legacy_resume_metadata': {'opaque': 'retain-across-renewal'},
        },
      },
    ];
    paths = [];
    associations = [];
    sessions = [];
    errorCode = 'UPLOAD_EXPIRED';
    errorStatus = 409;
    started = null;
    release = null;
    loseAssociationResponse = false;
    api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          paths.add(options.path);
          if (options.path == '/progress-photos/sessions/session/photos') {
            associations.add(Map.from(options.data as Map));
            if (started != null && !started!.isCompleted) {
              started!.complete();
              await release!.future;
            }
            if (errorCode != null) {
              handler.reject(
                DioException.badResponse(
                  statusCode: errorStatus,
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: errorStatus,
                    data: {'code': errorCode},
                  ),
                ),
              );
            } else if (loseAssociationResponse) {
              loseAssociationResponse = false;
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
                    'image_url': 'r2://new',
                  },
                ),
              );
            }
          } else if (options.path == '/uploads/sessions') {
            sessions.add(Map.from(options.data as Map));
            handler.resolve(
              Response(requestOptions: options, data: {'upload_id': 'new'}),
            );
          } else if (options.path == '/uploads/sessions/new/complete') {
            handler.resolve(
              Response(requestOptions: options, data: {'file_url': 'r2://new'}),
            );
          } else {
            fail('Unexpected request: ${options.path}');
          }
        },
      ),
    );
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'expiry atomically renews generation and survives crash before next upload',
    () async {
      final ids = stableIds(storage.all.single);
      final first = queue();
      await first.processQueue();
      await first.dispose();
      final saved = storage.all.single;
      expect(saved['status'], 'queued');
      expect(
        DateTime.parse(
          saved['next_attempt_at'] as String,
        ).isAfter(DateTime.now()),
        true,
      );
      expect(saved['upload_checkpoint'], {
        'generation': 3,
        'phase': 'session_expired',
        'prepared_path': file.path,
        'legacy_resume_metadata': {'opaque': 'retain-across-renewal'},
      });
      expect(stableIds(saved), ids);
      expect(await file.exists(), true);
      expect(sessions, isEmpty);
      errorCode = null;
      saved.remove('next_attempt_at');
      final resumed = queue();
      addTearDown(resumed.dispose);
      await resumed.processQueue();
      expect(sessions.single['client_operation_id'], 'upload-operation:3');
      expect(sessions.single['bytes'], 3);
      expect(sessions.single['content_type'], 'image/jpeg');
      expect(associations.map((v) => v['upload_id']), ['old', 'new']);
      expect(
        associations.every(
          (v) =>
              v['operation_id'] == 'association-operation' &&
              v['replaces_photo_id'] == 'original-photo',
        ),
        true,
      );
      expect(storage.all.single['status'], 'completed');
      expect(
        (storage.all.single['upload_checkpoint'] as Map)['legacy_resume_metadata'],
        {'opaque': 'retain-across-renewal'},
      );
      expect(stableIds(storage.all.single), ids);
    },
  );

  test(
    'expired confirmed upload with missing source renews then fails locally without deleting journal',
    () async {
      await file.delete();
      final service = queue();
      addTearDown(service.dispose);
      await service.processQueue();
      expect(storage.all.single['status'], 'queued');
      storage.all.single.remove('next_attempt_at');
      await service.processQueue();
      expect(storage.all.single['status'], 'failed');
      expect(storage.all.single['last_error'], 'progress_photo_file_missing');
      expect(sessions, isEmpty);
      expect(associations, hasLength(1));
    },
  );

  for (final code in [
    'UPLOAD_ALREADY_CONSUMED',
    'UNKNOWN_CONFLICT',
    'PROGRESS_PHOTO_REPLACEMENT_CONFLICT',
  ]) {
    test('ambiguous or replacement conflict $code never renews', () async {
      errorCode = code;
      final service = queue();
      addTearDown(service.dispose);
      await service.processQueue();
      await service.retry('stable');
      expect(storage.all.single['status'], 'failed');
      expect((storage.all.single['upload_checkpoint'] as Map)['generation'], 2);
      expect(
        (storage.all.single['upload_checkpoint'] as Map)['upload_id'],
        'old',
      );
      expect(sessions, isEmpty);
      expect(associations, hasLength(2));
      expect(await file.exists(), true);
    });
  }
  for (final status in [401, 403]) {
    test('authorization $status never renews even with expiry code', () async {
      errorStatus = status;
      final service = queue();
      addTearDown(service.dispose);
      await service.processQueue();
      expect(storage.all.single['status'], 'failed');
      expect((storage.all.single['upload_checkpoint'] as Map)['generation'], 2);
    });
  }
  for (final owner in ['A', 'B']) {
    test(
      'expiry response after session switches to $owner cannot renew',
      () async {
        started = Completer<void>();
        release = Completer<void>();
        final service = queue();
        addTearDown(service.dispose);
        final processing = service.processQueue();
        await started!.future;
        storage.current = LocalAuthSession(uid: owner, generation: 2);
        release!.complete();
        await processing;
        expect(
          (storage.all.single['upload_checkpoint'] as Map)['generation'],
          2,
        );
        expect(storage.all.single['status'], 'processing');
        expect(sessions, isEmpty);
      },
    );
  }
  test(
    'lost association response replays same confirmed upload without renewal',
    () async {
      errorCode = null;
      loseAssociationResponse = true;
      final service = queue();
      addTearDown(service.dispose);
      await service.processQueue();
      expect(storage.all.single['status'], 'queued');
      storage.all.single.remove('next_attempt_at');
      await service.processQueue();
      expect(storage.all.single['status'], 'completed');
      expect(associations.map((v) => v['upload_id']), ['old', 'old']);
      expect(sessions, isEmpty);
    },
  );
  test(
    'durable association receipt remains cleanup-only despite old expiry checkpoint',
    () async {
      storage.all.single.addAll({
        'status': 'completed',
        'cleanup_pending': true,
        'association_checkpoint': {'state': 'confirmed', 'photo_id': 'photo'},
      });
      final service = queue();
      addTearDown(service.dispose);
      await service.processQueue();
      expect(paths, isEmpty);
      expect(storage.all.single['cleanup_pending'], false);
      expect((storage.all.single['upload_checkpoint'] as Map)['generation'], 2);
    },
  );
}
