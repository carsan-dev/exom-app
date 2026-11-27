import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:flutter_test/flutter_test.dart';

class _TransferAdapter implements HttpClientAdapter {
  int calls = 0;
  int bytes = 0;
  int closes = 0;
  final paths = <String>[];
  final transferred = <String>{};
  final headers = <Map<String, dynamic>>[];
  Future<void> Function()? beforeRead;
  Future<void> Function()? afterChunk;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    paths.add(options.path);
    headers.add(Map<String, dynamic>.from(options.headers));
    await beforeRead?.call();
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes += chunk.length;
        await afterChunk?.call();
      }
    }
    transferred.add(options.uri.pathSegments.last);
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {
    closes++;
  }
}

class _GatedConnections extends HttpOverrides {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      if (!started.isCompleted) started.complete();
      await release.future;
      return Socket.startConnect(uri.host, uri.port);
    };
    return client;
  }
}

void main() {
  late Directory directory;
  late File file;
  late ApiClient api;
  late Dio transfer;
  late _TransferAdapter adapter;
  late Map<String, dynamic> saved;
  late List<String> completions;
  late String identity;
  late String storageBase;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-transfer-guard-');
    file = await File(
      '${directory.path}/retained.mp4',
    ).writeAsBytes(List.filled(262144, 1));
    api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
    adapter = _TransferAdapter();
    transfer = Dio()..httpClientAdapter = adapter;
    saved = {'upload_id': 'A-upload', 'generation': 2};
    completions = [];
    identity = 'A:1';
    storageBase = 'https://storage.invalid';
    api.dio.options.headers[HttpHeaders.authorizationHeader] = 'test-api-only';
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/uploads/sessions') {
            final operation =
                (options.data as Map)['client_operation_id'] as String;
            final id = operation.startsWith('B') ? 'B-upload' : 'A-upload';
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'upload_id': id,
                  'upload_url': '$storageBase/$id',
                  'transport': 'signed',
                },
              ),
            );
          } else {
            completions.add(options.path);
            final id = options.path.split('/')[3];
            if (adapter.transferred.contains(id)) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'file_url': 'r2://$id'},
                ),
              );
            } else {
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
            }
          }
        },
      ),
    );
  });
  tearDown(() => directory.delete(recursive: true));

  Future<ManagedUploadResult> upload({
    String operation = 'A-operation',
    bool Function()? isCurrent,
  }) => ManagedUploadTransport(api, transferClient: transfer).upload(
    file: file,
    contentType: 'video/mp4',
    purpose: 'FEEDBACK_VIDEO',
    context: ManagedUploadContext(
      operationId: operation,
      checkpoint: operation.startsWith('A') ? saved : {'generation': 2},
      saveCheckpoint: (value) async {
        if (operation.startsWith('A')) saved = value;
      },
      isCurrent: isCurrent ?? () => identity == 'A:1',
    ),
  );

  final cancelled = isA<DioException>().having(
    (error) => error.type,
    'type',
    DioExceptionType.cancel,
  );

  for (final next in ['B:2', 'A:2']) {
    test(
      'actual signed dispatch blocked after interceptor wait and session switch $next',
      () async {
        final started = Completer<void>();
        final release = Completer<void>();
        transfer.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              started.complete();
              await release.future;
              handler.next(options);
            },
          ),
        );
        final result = upload();
        final assertion = expectLater(result, throwsA(cancelled));
        await started.future;
        identity = next;
        release.complete();
        await assertion;
        expect(adapter.calls, 0);
        expect(adapter.bytes, 0);
        expect(saved['phase'], 'transfer_uncertain');
        expect(saved['upload_id'], 'A-upload');
        expect(saved['generation'], 2);
        expect(completions.length, 2);
        expect(await file.length(), 262144);
        expect(adapter.closes, 0);
      },
    );
  }

  test(
    'body consumption rejects a session switch after adapter dispatch',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      adapter.beforeRead = () async {
        started.complete();
        await release.future;
      };
      final result = upload();
      final assertion = expectLater(result, throwsA(cancelled));
      await started.future;
      identity = 'B:2';
      release.complete();
      await assertion;
      expect(adapter.calls, 1);
      expect(adapter.bytes, 0);
      expect(adapter.transferred, isEmpty);
      expect(saved['phase'], 'transfer_uncertain');
      expect(completions.length, 2);
      expect(await file.length(), 262144);
    },
  );

  test(
    'body consumption stops later chunks after same-owner generation switch',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      adapter.afterChunk = () async {
        if (!started.isCompleted) {
          started.complete();
          await release.future;
        }
      };
      final result = upload();
      final assertion = expectLater(result, throwsA(cancelled));
      await started.future;
      final alreadyConsumed = adapter.bytes;
      expect(alreadyConsumed, greaterThan(0));
      expect(alreadyConsumed, lessThan(262144));
      identity = 'A:2';
      release.complete();
      await assertion;
      expect(adapter.bytes, alreadyConsumed);
      expect(adapter.transferred, isEmpty);
      expect(saved['phase'], 'transfer_uncertain');
      expect(completions.length, 2);
      expect(await file.length(), 262144);
    },
  );

  test(
    'concurrent uploads share supplied client without guard or close leakage',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      transfer.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path.endsWith('/A-upload')) {
              started.complete();
              await release.future;
            }
            handler.next(options);
          },
        ),
      );
      final originalInterceptors = transfer.interceptors.toList();
      final a = upload();
      final rejectedA = expectLater(a, throwsA(cancelled));
      await started.future;
      identity = 'B:2';
      final b = await upload(
        operation: 'B-operation',
        isCurrent: () => identity == 'B:2',
      );
      expect(b.uploadId, 'B-upload');
      release.complete();
      await rejectedA;
      expect(adapter.paths, ['https://storage.invalid/B-upload']);
      expect(adapter.bytes, 262144);
      expect(
        adapter.headers.single.keys.any(
          (key) => key.toLowerCase() == HttpHeaders.authorizationHeader,
        ),
        false,
      );
      expect(transfer.httpClientAdapter, same(adapter));
      expect(transfer.interceptors.toList(), originalInterceptors);
      expect(adapter.closes, 0);
      await transfer.get<void>('https://storage.invalid/unrelated');
      expect(adapter.paths.last, 'https://storage.invalid/unrelated');
      expect(adapter.closes, 0);
      expect(await file.exists(), true);
    },
  );

  for (final switchBeforeBody in [false, true]) {
    test(
      'default signed client uses guarded body without API credentials: switch=$switchBeforeBody',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        storageBase = 'http://127.0.0.1:${server.port}';
        var receivedBytes = 0;
        String? authorization;
        server.listen((request) async {
          authorization = request.headers.value(
            HttpHeaders.authorizationHeader,
          );
          try {
            await for (final chunk in request) {
              receivedBytes += chunk.length;
            }
            adapter.transferred.add(request.uri.pathSegments.last);
            request.response.write('{}');
            await request.response.close();
          } on HttpException {
            // Cancellation can close an already opened request before its body.
          } on SocketException {
            // The request-scoped cancellation aborts only this local connection.
          }
        });
        final connections = _GatedConnections();
        await HttpOverrides.runWithHttpOverrides(() async {
          final result = ManagedUploadTransport(api).upload(
            file: file,
            contentType: 'video/mp4',
            purpose: 'FEEDBACK_VIDEO',
            context: ManagedUploadContext(
              operationId: 'A-operation',
              checkpoint: saved,
              isCurrent: () => identity == 'A:1',
              saveCheckpoint: (value) async => saved = value,
            ),
          );
          if (switchBeforeBody) {
            final assertion = expectLater(result, throwsA(cancelled));
            await connections.started.future;
            identity = 'B:2';
            connections.release.complete();
            await assertion;
            expect(receivedBytes, 0);
            expect(saved['phase'], 'transfer_uncertain');
            expect(completions.length, 2);
          } else {
            connections.release.complete();
            expect((await result).uploadId, 'A-upload');
            expect(receivedBytes, 262144);
            expect(saved['phase'], 'completion_confirmed');
          }
        }, connections);
        expect(authorization, isNull);
        expect(await file.length(), 262144);
        expect(saved['upload_id'], 'A-upload');
        expect(saved['generation'], 2);
      },
    );
  }
}
