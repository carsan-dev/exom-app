import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/data/repositories/feedback_repository_impl.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_upload_queue_service_test.dart'
    show FakeFeedbackQueueStorage, FakeOfflineSyncService;

/// Minimal model of the API managed-upload contract that matters here:
/// `client_operation_id` is immutable. Replaying it with different bytes or
/// MIME is rejected with 409 `UPLOAD_OPERATION_CONFLICT`
/// (exom-api `UploadsService.createSession`).
class _UploadsApi {
  _UploadsApi(this.sessions, {this.transferFailures = 0});

  final Map<String, ({String id, int bytes, String mime})> sessions;

  /// Transfers that drop the connection first (app backgrounded, radio lost).
  int transferFailures;
  final Set<String> uploaded = {};
  final List<String> operations = [];
  final List<String> associations = [];

  void attach(ApiClient api) {
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          if (path == '/uploads/sessions') {
            final body = options.data as Map;
            final operation = body['client_operation_id'] as String;
            final bytes = body['bytes'] as int;
            final mime = body['content_type'] as String;
            operations.add(operation);
            final existing = sessions[operation];
            if (existing != null &&
                (existing.bytes != bytes || existing.mime != mime)) {
              handler.reject(_error(options, 409, 'UPLOAD_OPERATION_CONFLICT'));
              return;
            }
            final session =
                existing ??
                (id: 'upload-${sessions.length + 1}', bytes: bytes, mime: mime);
            sessions[operation] = session;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {
                    'upload_id': session.id,
                    'upload_url': '/uploads/sessions/${session.id}/file',
                    'transport': 'proxy',
                    'status': 'PENDING',
                  },
                },
              ),
            );
            return;
          }
          final complete = RegExp(
            r'^/uploads/sessions/([^/]+)/complete$',
          ).firstMatch(path);
          if (complete != null) {
            final id = complete.group(1)!;
            if (!uploaded.contains(id)) {
              handler.reject(_error(options, 404, 'UPLOAD_OBJECT_MISSING'));
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {
                    'upload_id': id,
                    'file_url': 'r2://$id',
                    'status': 'VERIFIED',
                  },
                },
              ),
            );
            return;
          }
          final file = RegExp(
            r'^/uploads/sessions/([^/]+)/file$',
          ).firstMatch(path);
          if (file != null) {
            if (transferFailures > 0) {
              transferFailures--;
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            uploaded.add(file.group(1)!);
            handler.resolve(
              Response(requestOptions: options, data: {'data': {}}),
            );
            return;
          }
          if (path == '/feedback') {
            final body = options.data as Map;
            associations.add(body['client_upload_id'] as String);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {
                    'id': 'feedback',
                    'media_type': 'VIDEO',
                    'media_url': 'r2://${body['upload_id']}',
                    'status': 'PENDING',
                    'created_at': '2026-11-05T10:00:00Z',
                  },
                },
              ),
            );
            return;
          }
          fail('Unexpected request: $path');
        },
      ),
    );
  }

  static DioException _error(RequestOptions options, int status, String code) =>
      DioException.badResponse(
        statusCode: status,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: status,
          data: {'code': code},
        ),
      );
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'exom-feedback-operation-conflict-',
    );
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'interrupted transfer then retries reuse the first prepared bytes',
    () async {
      // Shipped build (v1.2.4 == develop HEAD): attempt 2 re-compresses, replays
      // `stable:0` with new bytes, gets 409 and every manual retry repeats it.
      final source = await File(
        '${directory.path}/stable.mp4',
      ).writeAsBytes([1, 2, 3, 4, 5, 6]);
      final storage = FakeFeedbackQueueStorage([
        {
          'id': 'stable',
          'file_path': source.path,
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          'status': 'queued',
          'attempts': 0,
        },
      ]);
      final server = _UploadsApi({}, transferFailures: 1);
      final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
      server.attach(api);
      var compressions = 0;
      final offline = FakeOfflineSyncService(storage);
      final queue = FeedbackUploadQueueService(
        FeedbackRepositoryImpl(
          FeedbackRemoteDataSourceImpl(
            api,
            // The first output has 3 bytes; a later re-compression differs.
            prepareFile: (_, _) async => File(
              '${directory.path}/compressed-${++compressions}.mp4',
            ).writeAsBytes(compressions == 1 ? [9, 9, 9] : [9, 9, 9, 9]),
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
      expect(storage.queue.single['status'], 'queued');
      await queue.retry('stable');
      await queue.retry('stable');

      final item = storage.queue.single;
      expect(
        item['status'],
        'completed',
        reason:
            'operations=${server.operations} '
            'last_error=${item['last_error']} compressions=$compressions',
      );
      expect(server.associations, ['stable']);
      expect(compressions, 1);
    },
  );

  // Queue rows exactly as the shipped build (v1.2.4 == develop HEAD) persists
  // them: its datasource cleared its own checkpoint map while saving
  // `prepared_path`, so no preparation metadata (`prepared_*`) survives and the
  // server-side operation `stable:0` keeps the first compression's byte count.
  final legacyRows = <String, Map<String, dynamic>>{
    'conflicted and failed before the upgrade': {
      'status': 'failed',
      'attempts': 2,
      'last_error': 'UPLOAD_OPERATION_CONFLICT',
      'last_http_status': 409,
      'upload_checkpoint': {'generation': 0, 'phase': 'session_creating'},
    },
    'interrupted transfer pending at the upgrade': {
      'status': 'queued',
      'attempts': 1,
      'upload_checkpoint': {
        'generation': 0,
        'phase': 'transfer_uncertain',
        'upload_id': 'upload-1',
      },
    },
  };

  for (final MapEntry(key: name, value: row) in legacyRows.entries) {
    test(
      'manual retry recovers a persisted operation conflict: $name',
      () async {
        final source = await File(
          '${directory.path}/stable.mp4',
        ).writeAsBytes([1, 2, 3, 4, 5, 6]);
        final storage = FakeFeedbackQueueStorage([
          {
            'id': 'stable',
            'file_path': source.path,
            'content_type': 'video/mp4',
            'media_type': 'VIDEO',
            'feedback_kind': 'LAST_SET',
            ...row,
          },
        ]);
        // First compression produced 3 bytes; the session was never uploaded.
        final server = _UploadsApi({
          'stable:0': (id: 'upload-1', bytes: 3, mime: 'video/mp4'),
        });
        final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
        server.attach(api);
        var compressions = 0;
        final offline = FakeOfflineSyncService(storage);
        final queue = FeedbackUploadQueueService(
          FeedbackRepositoryImpl(
            FeedbackRemoteDataSourceImpl(
              api,
              // Re-compressing the retained source is not byte-identical
              // to the first output (fallback/encoder variance): 4 bytes.
              prepareFile: (_, _) async => File(
                '${directory.path}/compressed-${++compressions}.mp4',
              ).writeAsBytes([9, 9, 9, 9]),
            ),
          ),
          storage,
          offline,
          isAuthenticated: () => true,
          connectivityChanges: const Stream.empty(),
        );
        addTearDown(queue.dispose);
        addTearDown(offline.dispose);

        if (row['status'] == 'queued') await queue.processQueue();
        // The owner retries from the Feedback screen, more than once.
        await queue.retry('stable');
        await queue.retry('stable');

        final item = storage.queue.single;
        expect(
          item['status'],
          'completed',
          reason:
              'operations=${server.operations} '
              'last_error=${item['last_error']} '
              'checkpoint=${item['upload_checkpoint']}',
        );
        // Recovery must not re-key the feedback, only the upload generation.
        expect(server.associations, ['stable']);
        expect(server.operations.last, isNot('stable:0'));
        expect(server.sessions['stable:0']!.bytes, 3);
      },
    );
  }
}
