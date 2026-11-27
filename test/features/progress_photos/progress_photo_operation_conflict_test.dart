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

/// Progress photos share `ManagedUploadTransport`, but upload the staged file
/// as is (constant bytes and MIME) and never wiped their checkpoint, so the
/// feedback v1.2.4 conflict trigger does not apply. They inherit the in-run
/// renewal; their queue classification (409 terminal) is unchanged.
void main() {
  late Directory directory;
  late File file;
  late PhotoStorage storage;
  late ApiClient api;
  late List<String> operations;
  late List<Map> associations;
  late Set<String> conflicting;

  ProgressPhotoUploadQueueService queue() => ProgressPhotoUploadQueueService(
    ProgressPhotoRepositoryImpl(ProgressPhotoRemoteDataSourceImpl(api)),
    storage,
    isAuthenticated: () => true,
    connectivityChanges: const Stream.empty(),
  );

  DioException conflict(RequestOptions options) => DioException.badResponse(
    statusCode: 409,
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: 409,
      data: {'code': 'UPLOAD_OPERATION_CONFLICT'},
    ),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-photo-conflict-');
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
        'civil_session_date': '2026-11-04',
        'view': 'FRONT',
        'upload_checkpoint': <String, dynamic>{'phase': 'pending'},
      },
    ];
    operations = [];
    associations = [];
    conflicting = {};
    api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/uploads/sessions') {
            final operation =
                (options.data as Map)['client_operation_id'] as String;
            operations.add(operation);
            if (conflicting.contains(operation)) {
              handler.reject(conflict(options));
              return;
            }
            handler.resolve(
              Response(requestOptions: options, data: {'upload_id': 'new'}),
            );
          } else if (options.path == '/uploads/sessions/new/complete') {
            handler.resolve(
              Response(requestOptions: options, data: {'file_url': 'r2://new'}),
            );
          } else if (options.path ==
              '/progress-photos/sessions/session/photos') {
            associations.add(Map.from(options.data as Map));
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'id': 'photo', 'view': 'FRONT', 'image_url': 'r2://new'},
              ),
            );
          } else {
            fail('Unexpected request: ${options.path}');
          }
        },
      ),
    );
  });
  tearDown(() => directory.delete(recursive: true));

  test('a create conflict is renewed once by the shared transport', () async {
    conflicting.add('upload-operation:0');
    final ids = stableIds(storage.all.single);
    await queue().processQueue();

    final item = storage.all.single;
    expect(item['status'], 'completed', reason: '${item['last_error']}');
    expect(operations, ['upload-operation:0', 'upload-operation:1']);
    expect((item['upload_checkpoint'] as Map)['generation'], 1);
    expect(associations.single['upload_id'], 'new');
    expect(stableIds(item), ids);
  });

  test('a conflict after the in-run renewal keeps 409 terminal', () async {
    conflicting.addAll(['upload-operation:0', 'upload-operation:1']);
    final ids = stableIds(storage.all.single);
    await queue().processQueue();

    final item = storage.all.single;
    expect(item['status'], 'failed');
    expect(item['last_error'], 'UPLOAD_OPERATION_CONFLICT');
    expect(operations, ['upload-operation:0', 'upload-operation:1']);
    expect(associations, isEmpty);
    expect(stableIds(item), ids);
    expect(await file.exists(), true);
  });

  for (final lastError in [
    'UPLOAD_OPERATION_CONFLICT',
    'upload_operation_conflict_exhausted',
  ]) {
    test('manual retry after $lastError renews with a fresh bound', () async {
      storage.all = [
        {
          ...storage.all.single,
          'status': 'failed',
          'last_error': lastError,
          'upload_checkpoint': {
            'generation': 1,
            'phase': 'session_creating',
            'session_attempted': true,
            'operation_conflict_renewals': 3,
          },
        },
      ];
      conflicting.add('upload-operation:1');
      final ids = stableIds(storage.all.single);
      await queue().retry('stable');

      final item = storage.all.single;
      expect(item['status'], 'completed', reason: '${item['last_error']}');
      expect(operations, ['upload-operation:2']);
      final checkpoint = item['upload_checkpoint'] as Map;
      expect(checkpoint['generation'], 2);
      expect(checkpoint['operation_conflict_renewals'], 1);
      expect(associations.single['upload_id'], 'new');
      expect(stableIds(item), ids);
    });
  }

  for (final (lastError, checkpoint) in [
    (
      'progress_photo_http_400',
      <String, dynamic>{'generation': 1, 'phase': 'session_creating'},
    ),
    (
      'UPLOAD_OPERATION_CONFLICT',
      <String, dynamic>{
        'generation': 1,
        'phase': 'completion_confirmed',
        'upload_id': 'new',
        'file_url': 'r2://new',
      },
    ),
  ]) {
    test(
      'manual retry keeps the generation: $lastError, '
      '${checkpoint['phase']}',
      () async {
        storage.all = [
          {
            ...storage.all.single,
            'status': 'failed',
            'last_error': lastError,
            'upload_checkpoint': checkpoint,
          },
        ];
        await queue().retry('stable');

        final item = storage.all.single;
        expect(item['status'], 'completed', reason: '${item['last_error']}');
        expect((item['upload_checkpoint'] as Map)['generation'], 1);
        expect(
          (item['upload_checkpoint'] as Map)['operation_conflict_renewals'],
          isNull,
        );
        expect(
          operations,
          checkpoint['upload_id'] == null ? ['upload-operation:1'] : isEmpty,
        );
      },
    );
  }
}
