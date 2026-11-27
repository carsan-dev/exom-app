import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File original;
  late ApiClient api;
  late Map<String, dynamic> saved;
  late List<RequestOptions> requests;
  late bool current;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-recovery-');
    original = await File(
      '${directory.path}/original.mp4',
    ).writeAsBytes([1, 2, 3]);
    api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
    saved = {
      'upload_id': 'known',
      'generation': 3,
      'legacy_metadata': 'retained',
    };
    requests = [];
    current = true;
  });
  tearDown(() => directory.delete(recursive: true));

  void server(
    FutureOr<void> Function(RequestOptions, RequestInterceptorHandler) respond,
  ) {
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          try {
            await respond(options, handler);
          } catch (error, stackTrace) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                stackTrace: stackTrace,
              ),
            );
          }
        },
      ),
    );
  }

  void verified(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(
      Response(requestOptions: options, data: {'file_url': 'r2://known'}),
    );
  }

  void reject(
    RequestOptions options,
    RequestInterceptorHandler handler,
    int status,
    String code,
  ) {
    handler.reject(
      DioException.badResponse(
        statusCode: status,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: status,
          data: {'code': code},
        ),
      ),
    );
  }

  ManagedUploadContext context({
    Future<void> Function(Map<String, dynamic>)? save,
  }) => ManagedUploadContext(
    operationId: 'stable',
    checkpoint: saved,
    isCurrent: () => current,
    saveCheckpoint: save ?? (value) async => saved = value,
  );

  Future<ManagedUploadResult> upload() => ManagedUploadTransport(api).upload(
    file: original,
    contentType: 'video/mp4',
    purpose: 'FEEDBACK_VIDEO',
    context: context(),
  );

  test(
    'known upload completes without surviving bytes or new session',
    () async {
      await original.delete();
      server(verified);
      final result = await upload();
      expect(result.uploadId, 'known');
      expect(result.fileUrl, 'r2://known');
      expect(requests.map((value) => value.path), [
        '/uploads/sessions/known/complete',
      ]);
      expect(saved['generation'], 3);
      expect(saved['phase'], 'completion_confirmed');
      expect(saved['legacy_metadata'], 'retained');
    },
  );

  test('wrapped remote completion is authoritative, not cached URL', () async {
    saved['file_url'] = 'r2://stale';
    server(
      (options, handler) => handler.resolve(
        Response(
          requestOptions: options,
          data: {
            'data': {'file_url': 'r2://wrapped'},
          },
        ),
      ),
    );
    expect((await upload()).fileUrl, 'r2://wrapped');
    expect(saved['file_url'], 'r2://wrapped');
    expect(requests.map((value) => value.path), [
      '/uploads/sessions/known/complete',
    ]);
  });

  test(
    'unsent missing source does not create a session or fabricate success',
    () async {
      saved = {'generation': 3};
      await original.delete();
      server(verified);
      await expectLater(upload(), throwsA(isA<FileSystemException>()));
      expect(requests, isEmpty);
      expect(saved, {'generation': 3});
    },
  );

  test(
    'missing remote object safely transfers retained source with same generation',
    () async {
      saved.addAll({'prepared_content_type': 'video/mp4', 'prepared_bytes': 3});
      var transferred = false;
      server((options, handler) async {
        if (options.path == '/uploads/sessions') {
          expect(options.data, {
            'purpose': 'FEEDBACK_VIDEO',
            'content_type': 'video/mp4',
            'bytes': 3,
            'client_operation_id': 'stable:3',
          });
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'upload_id': 'known',
                'upload_url': '/uploads/proxy/known',
                'transport': 'proxy',
              },
            ),
          );
        } else if (options.path == '/uploads/proxy/known') {
          final form = options.data as FormData;
          expect(
            await form.files.single.value
                .finalize()
                .expand((chunk) => chunk)
                .toList(),
            [1, 2, 3],
          );
          transferred = true;
          handler.resolve(Response(requestOptions: options, statusCode: 204));
        } else if (transferred) {
          verified(options, handler);
        } else {
          reject(options, handler, 404, 'UPLOAD_OBJECT_MISSING');
        }
      });
      expect((await upload()).uploadId, 'known');
      expect(transferred, true);
      expect(saved['generation'], 3);
      expect(saved['prepared_bytes'], 3);
      expect(saved['prepared_content_type'], 'video/mp4');
      expect(saved['legacy_metadata'], 'retained');
      expect(await original.exists(), true);
    },
  );

  for (final changed in [false, true]) {
    test(
      'missing prepared artifact after remote missing renews only changed immutable metadata: changed=$changed',
      () async {
        saved.addAll({
          'prepared_path': '${directory.path}/missing-prepared.mp4',
          'prepared_content_type': 'video/mp4',
          'prepared_bytes': 3,
        });
        var preparations = 0;
        var transferred = false;
        server((options, handler) {
          if (options.path == '/uploads/sessions') {
            expect(
              (options.data as Map)['client_operation_id'],
              changed ? 'stable:4' : 'stable:3',
            );
            expect((options.data as Map)['bytes'], changed ? 4 : 3);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'upload_id': changed ? 'renewed' : 'known',
                  'upload_url': changed
                      ? '/uploads/proxy/renewed'
                      : '/uploads/proxy/known',
                  'transport': 'proxy',
                },
              ),
            );
          } else if (options.path.startsWith('/uploads/proxy/')) {
            expect(
              (options.data as FormData).files.single.value.length,
              changed ? 4 : 3,
            );
            transferred = true;
            handler.resolve(Response(requestOptions: options));
          } else if (transferred) {
            verified(options, handler);
          } else {
            reject(options, handler, 404, 'UPLOAD_OBJECT_MISSING');
          }
        });
        final source = FeedbackRemoteDataSourceImpl(
          api,
          prepareFile: (file, _) async {
            preparations++;
            return changed
                ? File(
                    '${directory.path}/changed.mp4',
                  ).writeAsBytes([1, 2, 3, 4])
                : file;
          },
        );
        final result = source.uploadMedia(
          original,
          'video/mp4',
          context: FeedbackUploadContext(
            operationId: 'stable',
            checkpoint: saved,
            isCurrent: () => current,
            saveCheckpoint: (value) async => saved = value,
          ),
        );
        expect((await result).uploadId, changed ? 'renewed' : 'known');
        expect(transferred, true);
        expect(saved['prepared_bytes'], changed ? 4 : 3);
        expect(saved['prepared_content_type'], 'video/mp4');
        expect(
          saved['prepared_path'],
          changed ? '${original.path}.prepared.mp4' : original.path,
        );
        expect(preparations, changed ? 2 : 1);
        expect(saved['upload_id'], changed ? 'renewed' : 'known');
        expect(saved['generation'], changed ? 4 : 3);
        expect(saved['legacy_metadata'], 'retained');
        expect(await original.readAsBytes(), [1, 2, 3]);
      },
    );
  }

  test(
    'feedback reconciles known upload before preparing different bytes',
    () async {
      var preparations = 0;
      server((options, handler) {
        if (options.path == '/uploads/sessions/known/complete') {
          verified(options, handler);
        } else {
          reject(options, handler, 409, 'UPLOAD_OPERATION_CONFLICT');
        }
      });
      final source = FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (_, _) async {
          preparations++;
          return File(
            '${directory.path}/different.mp4',
          ).writeAsBytes([4, 5, 6, 7]);
        },
      );
      final result = await source.uploadMedia(
        original,
        'video/mp4',
        context: FeedbackUploadContext(
          operationId: 'stable',
          checkpoint: saved,
          isCurrent: () => current,
          saveCheckpoint: (value) async => saved = value,
        ),
      );
      expect(result.uploadId, 'known');
      expect(preparations, 0);
      expect(requests.map((value) => value.path), [
        '/uploads/sessions/known/complete',
      ]);
      expect(saved['legacy_metadata'], 'retained');
    },
  );

  test(
    'durable expiry permits changed preparation after crash and restart',
    () async {
      saved.addAll({
        'prepared_path': '${directory.path}/lost.mp4',
        'prepared_content_type': 'video/mp4',
        'prepared_bytes': 3,
      });
      server((options, handler) {
        if (options.path == '/uploads/sessions/known/complete') {
          reject(options, handler, 409, 'UPLOAD_EXPIRED');
        } else if (options.path == '/uploads/sessions') {
          expect((options.data as Map)['client_operation_id'], 'stable:4');
          expect((options.data as Map)['bytes'], 4);
          handler.resolve(
            Response(requestOptions: options, data: {'upload_id': 'renewed'}),
          );
        } else {
          verified(options, handler);
        }
      });
      await expectLater(
        ManagedUploadTransport(api).upload(
          file: original,
          contentType: 'video/mp4',
          purpose: 'FEEDBACK_VIDEO',
          context: context(
            save: (value) async {
              saved = value;
              if (value['phase'] == 'session_expired') {
                throw StateError('simulated crash');
              }
            },
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'simulated crash',
          ),
        ),
      );
      expect(saved['generation'], 4);
      expect(saved['upload_id'], isNull);
      final source = FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (_, _) async =>
            File('${directory.path}/new.mp4').writeAsBytes([1, 2, 3, 4]),
      );
      final result = await source.uploadMedia(
        original,
        'video/mp4',
        context: FeedbackUploadContext(
          operationId: 'stable',
          checkpoint: saved,
          isCurrent: () => current,
          saveCheckpoint: (value) async => saved = value,
        ),
      );
      expect(result.uploadId, 'renewed');
      expect(saved['generation'], 4);
      expect(saved['prepared_bytes'], 4);
      expect(saved['prepared_content_type'], 'video/mp4');
      expect(saved['legacy_metadata'], 'retained');
      expect(await original.exists(), true);
    },
  );

  test(
    'retained prepared artifact survives original loss and replays frozen MIME and size',
    () async {
      final retained = await File(
        '${directory.path}/retained.mp4',
      ).writeAsBytes([4, 5, 6]);
      await original.delete();
      saved = {
        'generation': 3,
        'prepared_path': retained.path,
        'prepared_content_type': 'video/mp4',
        'prepared_bytes': 3,
      };
      var preparations = 0;
      server((options, handler) {
        if (options.path == '/uploads/sessions') {
          expect(options.data, {
            'purpose': 'FEEDBACK_VIDEO',
            'content_type': 'video/mp4',
            'bytes': 3,
            'client_operation_id': 'stable:3',
          });
          handler.resolve(
            Response(requestOptions: options, data: {'upload_id': 'known'}),
          );
        } else {
          verified(options, handler);
        }
      });
      final source = FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (_, _) async {
          preparations++;
          throw StateError('Original is gone');
        },
      );
      final result = await source.uploadMedia(
        original,
        'video/quicktime',
        context: FeedbackUploadContext(
          operationId: 'stable',
          checkpoint: saved,
          isCurrent: () => current,
          saveCheckpoint: (value) async => saved = value,
        ),
      );
      expect(result.uploadId, 'known');
      expect(preparations, 0);
      expect(saved['prepared_content_type'], 'video/mp4');
      expect(saved['prepared_bytes'], 3);
      expect(await retained.readAsBytes(), [4, 5, 6]);
    },
  );

  test(
    'MIME drift renews generation before changed metadata dispatch',
    () async {
      saved.addAll({
        'prepared_path': '${directory.path}/lost.mp4',
        'prepared_content_type': 'video/mp4',
        'prepared_bytes': 3,
      });
      server((options, handler) {
        if (options.path == '/uploads/sessions/known/complete') {
          reject(options, handler, 404, 'UPLOAD_OBJECT_MISSING');
        } else if (options.path == '/uploads/sessions') {
          expect((options.data as Map)['client_operation_id'], 'stable:4');
          expect((options.data as Map)['content_type'], 'image/jpeg');
          expect((options.data as Map)['bytes'], 3);
          handler.resolve(
            Response(requestOptions: options, data: {'upload_id': 'renewed'}),
          );
        } else {
          verified(options, handler);
        }
      });
      final source = FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (_, _) async =>
            File('${directory.path}/changed.jpg').writeAsBytes([1, 2, 3]),
      );
      final result = await source.uploadMedia(
        original,
        'video/mp4',
        context: FeedbackUploadContext(
          operationId: 'stable',
          checkpoint: saved,
          isCurrent: () => current,
          saveCheckpoint: (value) async => saved = value,
        ),
      );
      expect(result.uploadId, 'renewed');
      expect(requests.map((value) => value.path), [
        '/uploads/sessions/known/complete',
        '/uploads/sessions',
        '/uploads/sessions/renewed/complete',
      ]);
      expect(saved['upload_id'], 'renewed');
      expect(saved['generation'], 4);
      expect(saved['prepared_content_type'], 'image/jpeg');
      expect(saved['prepared_bytes'], 3);
      expect(await original.readAsBytes(), [1, 2, 3]);
    },
  );

  for (final failure in [
    'timeout',
    'inspection',
    'auth',
    'forbidden',
    'conflict',
  ]) {
    test(
      '$failure during reconciliation preserves IDs and source without preparation',
      () async {
        var preparations = 0;
        server((options, handler) {
          if (failure == 'timeout') {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
          } else {
            final status = switch (failure) {
              'inspection' => 503,
              'auth' => 401,
              'forbidden' => 403,
              _ => 409,
            };
            reject(options, handler, status, 'REJECTED');
          }
        });
        final source = FeedbackRemoteDataSourceImpl(
          api,
          prepareFile: (file, _) async {
            preparations++;
            return file;
          },
        );
        await expectLater(
          source.uploadMedia(
            original,
            'video/mp4',
            context: FeedbackUploadContext(
              operationId: 'stable',
              checkpoint: saved,
              isCurrent: () => current,
              saveCheckpoint: (value) async => saved = value,
            ),
          ),
          throwsA(isA<DioException>()),
        );
        expect(requests.map((value) => value.path), [
          '/uploads/sessions/known/complete',
        ]);
        expect(preparations, 0);
        expect(saved['upload_id'], 'known');
        expect(saved['generation'], 3);
        expect(await original.readAsBytes(), [1, 2, 3]);
      },
    );
  }

  test(
    'missing remote object and local file retain upload identity without new session',
    () async {
      await original.delete();
      server(
        (options, handler) =>
            reject(options, handler, 404, 'UPLOAD_OBJECT_MISSING'),
      );
      await expectLater(upload(), throwsA(isA<FileSystemException>()));
      expect(requests.map((value) => value.path), [
        '/uploads/sessions/known/complete',
      ]);
      expect(saved['upload_id'], 'known');
      expect(saved['generation'], 3);
    },
  );

  test(
    'expired known session renews exactly one generation and clears stale URL atomically',
    () async {
      saved['file_url'] = 'r2://stale';
      final snapshots = <Map<String, dynamic>>[];
      server((options, handler) {
        if (options.path == '/uploads/sessions/known/complete') {
          reject(options, handler, 409, 'UPLOAD_EXPIRED');
        } else if (options.path == '/uploads/sessions') {
          expect((options.data as Map)['client_operation_id'], 'stable:4');
          handler.resolve(
            Response(requestOptions: options, data: {'upload_id': 'renewed'}),
          );
        } else {
          verified(options, handler);
        }
      });
      final result = await ManagedUploadTransport(api).upload(
        file: original,
        contentType: 'video/mp4',
        purpose: 'FEEDBACK_VIDEO',
        context: context(
          save: (value) async {
            saved = value;
            snapshots.add(value);
          },
        ),
      );
      expect(result.uploadId, 'renewed');
      final expired = snapshots.singleWhere(
        (value) => value['phase'] == 'session_expired',
      );
      expect(expired['generation'], 4);
      expect(expired.containsKey('upload_id'), false);
      expect(expired.containsKey('file_url'), false);
      expect(saved['generation'], 4);
      expect(await original.exists(), true);
    },
  );

  test(
    'session switch while reconciliation waits rejects response without preparing or confirming',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      server((options, handler) async {
        started.complete();
        await release.future;
        verified(options, handler);
      });
      final result = upload();
      final assertion = expectLater(
        result,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await started.future;
      current = false;
      release.complete();
      await assertion;
      expect(saved['phase'], 'completion_reconciling');
      expect(saved['upload_id'], 'known');
      expect(requests.length, 1);
    },
  );

  test(
    'session switch while reconcile checkpoint saves prevents HTTP',
    () async {
      server(verified);
      await expectLater(
        ManagedUploadTransport(api).upload(
          file: original,
          contentType: 'video/mp4',
          purpose: 'FEEDBACK_VIDEO',
          context: context(
            save: (value) async {
              saved = value;
              current = false;
            },
          ),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(requests, isEmpty);
      expect(saved['upload_id'], 'known');
    },
  );

  test(
    'session switch during preparation prevents checkpoint and session creation',
    () async {
      saved = {'generation': 3};
      server(verified);
      final source = FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (file, _) async {
          current = false;
          return file;
        },
      );
      await expectLater(
        source.uploadMedia(
          original,
          'video/mp4',
          context: FeedbackUploadContext(
            operationId: 'stable',
            checkpoint: saved,
            isCurrent: () => current,
            saveCheckpoint: (value) async => saved = value,
          ),
        ),
        throwsA(isA<DioException>()),
      );
      expect(requests, isEmpty);
      expect(saved, {'generation': 3});
      expect(await original.exists(), true);
    },
  );
}
