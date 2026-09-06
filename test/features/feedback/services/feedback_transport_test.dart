import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class ByteTransferAdapter implements HttpClientAdapter {
  int calls = 0;
  int bytes = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    await for (final chunk in requestStream!) {
      bytes += chunk.length;
    }
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('exom-wire-');
    file = await File(
      '${dir.path}/evidence.mp4',
    ).writeAsBytes(List.filled(16384, 1));
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
    'lost confirmation response reconciles the existing object without another PUT; byte progress is real',
    () async {
      final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
      final transfer = Dio();
      final adapter = ByteTransferAdapter();
      transfer.httpClientAdapter = adapter;
      var completedCalls = 0;
      final keys = <String>[];
      final checkpoints = <Map<String, dynamic>>[];
      final progress = <int>[];
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/uploads/sessions') {
              keys.add((options.data as Map)['client_operation_id'] as String);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'upload_id': 'one',
                    'upload_url': 'https://storage.exom.test/one',
                  },
                ),
              );
            } else {
              completedCalls++;
              if (completedCalls <= 2) {
                final code = completedCalls == 1 ? 404 : 503;
                handler.reject(
                  DioException.badResponse(
                    statusCode: code,
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: code,
                      data: {
                        'code': completedCalls == 1
                            ? 'UPLOAD_OBJECT_MISSING'
                            : 'UPLOAD_INSPECTION_UNAVAILABLE',
                      },
                    ),
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {'file_url': 'r2://one'},
                  ),
                );
              }
            }
          },
        ),
      );
      final source = FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (f, _) async => f,
        transferClient: transfer,
      );
      FeedbackUploadContext context() => FeedbackUploadContext(
        operationId: 'stable',
        checkpoint: checkpoints.isEmpty ? {} : checkpoints.last,
        saveCheckpoint: (value) async => checkpoints.add(value),
        isCurrent: () => true,
        onProgress: (sent, total) {
          expect(total, 16384);
          progress.add(sent);
        },
      );
      await expectLater(
        source.uploadMedia(file, 'video/mp4', context: context()),
        throwsA(isA<DioException>()),
      );
      final result = await source.uploadMedia(
        file,
        'video/mp4',
        context: context(),
      );
      expect(result.uploadId, 'one');
      expect(adapter.calls, 1);
      expect(adapter.bytes, 16384);
      expect(progress.last, 16384);
      expect(keys, ['stable:0', 'stable:0']);
      expect(await file.exists(), true);
    },
  );
  test(
    'expired upload session renews once and reuses the local file',
    () async {
      final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
      final keys = <String>[];
      var phase = 0;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/uploads/sessions') {
              keys.add((options.data as Map)['client_operation_id'] as String);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'upload_id': phase == 0 ? 'old' : 'renewed',
                    'upload_url': 'https://storage.exom.test',
                  },
                ),
              );
            } else if (phase++ == 0) {
              handler.reject(
                DioException.badResponse(
                  statusCode: 409,
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 409,
                    data: {'code': 'UPLOAD_EXPIRED'},
                  ),
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'file_url': 'r2://renewed'},
                ),
              );
            }
          },
        ),
      );
      Map<String, dynamic> saved = {};
      final source = FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (f, _) async => f,
      );
      final result = await source.uploadMedia(
        file,
        'video/mp4',
        context: FeedbackUploadContext(
          operationId: 'stable',
          checkpoint: {},
          saveCheckpoint: (c) async => saved = c,
          isCurrent: () => true,
        ),
      );
      expect(result.uploadId, 'renewed');
      expect(keys, ['stable:0', 'stable:1']);
      expect(saved['generation'], 1);
      expect(await file.exists(), true);
    },
  );
  test(
    'a definitive signature rejection never starts a different proxy upload',
    () async {
      final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
      final paths = <String>[];
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            if (options.path == '/uploads/sessions') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'upload_id': 'one',
                    'upload_url': 'https://storage.exom.test',
                  },
                ),
              );
            } else {
              handler.reject(
                DioException.badResponse(
                  statusCode: 400,
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 400,
                    data: {'code': 'UPLOAD_SIGNATURE_INVALID'},
                  ),
                ),
              );
            }
          },
        ),
      );
      final source = FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (f, _) async => f,
      );
      await expectLater(
        source.uploadMedia(file, 'video/mp4'),
        throwsA(isA<DioException>()),
      );
      expect(paths, ['/uploads/sessions', '/uploads/sessions/one/complete']);
      expect(await file.exists(), true);
    },
  );
  for (final scenario in ['expired_time', 'expired_code', 'denied']) {
    final expired = scenario != 'denied';
    test(
      'review: direct 403 renews only proven expired URL (scenario=$scenario)',
      () async {
        final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
        final transfer = Dio();
        final adapter = ByteTransferAdapter();
        transfer.httpClientAdapter = adapter;
        var attempts = 0;
        final keys = <String>[];
        transfer.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (attempts++ == 0) {
                handler.reject(
                  DioException.badResponse(
                    statusCode: 403,
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 403,
                      data: scenario == 'expired_code'
                          ? '<Error><Code>ExpiredRequest</Code></Error>'
                          : '<Error><Code>AccessDenied</Code></Error>',
                    ),
                  ),
                );
              } else {
                handler.next(options);
              }
            },
          ),
        );
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/uploads/sessions') {
                keys.add(
                  (options.data as Map)['client_operation_id'] as String,
                );
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'upload_id': 'same',
                      'upload_url': 'https://storage.exom.test',
                      'presigned_expires_at': DateTime.now()
                          .toUtc()
                          .add(
                            Duration(
                              minutes:
                                  scenario == 'expired_time' && keys.length == 1
                                  ? -1
                                  : 15,
                            ),
                          )
                          .toIso8601String(),
                    },
                  ),
                );
              } else if (adapter.calls == 0) {
                handler.reject(
                  DioException.badResponse(
                    statusCode: 404,
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 404,
                      data: {'code': 'UPLOAD_OBJECT_MISSING'},
                    ),
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {'file_url': 'r2://same'},
                  ),
                );
              }
            },
          ),
        );
        final source = FeedbackRemoteDataSourceImpl(
          api,
          prepareFile: (f, _) async => f,
          transferClient: transfer,
        );
        final upload = source.uploadMedia(
          file,
          'video/mp4',
          context: FeedbackUploadContext(
            operationId: 'stable',
            checkpoint: {},
            saveCheckpoint: (_) async {},
            isCurrent: () => true,
          ),
        );
        if (expired) {
          expect((await upload).uploadId, 'same');
          expect(keys, ['stable:0', 'stable:0']);
          expect(adapter.calls, 1);
        } else {
          await expectLater(upload, throwsA(isA<DioException>()));
          expect(keys, ['stable:0']);
          expect(adapter.calls, 0);
        }
        expect(await file.exists(), true);
      },
    );
  }
}
