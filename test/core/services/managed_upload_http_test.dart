import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:flutter_test/flutter_test.dart';

// Real sockets and Dio adapters; only the API/storage backend is simulated.
void main() {
  late HttpServer server;
  late Directory directory;
  late File file;
  late List<int> payload;
  late Map<String, dynamic> checkpoint;
  late List<Map<String, dynamic>> snapshots;
  late List<String> operations;
  late Set<String> sessions;
  late List<String> requests;
  late List<List<int>> transfers;
  late List<List<int>> progress;
  late List<Dio> clients;
  late bool objectExists;
  late bool dropSessionResponse;
  late bool dropCompletionResponse;
  late bool transientCompletion;
  late int completionCount;
  late String baseUrl;

  Future<void> jsonResponse(
    HttpRequest request,
    int status,
    Object body,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> dropResponse(HttpRequest request) async {
    final socket = await request.response.detachSocket(writeHeaders: false);
    socket.destroy();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-http-upload-');
    payload = List<int>.generate(256 * 1024 + 17, (index) => index % 251);
    file = await File('${directory.path}/synthetic.mp4').writeAsBytes(payload);
    checkpoint = {'generation': 0, 'owner_marker': 'synthetic-owner'};
    snapshots = [];
    operations = [];
    sessions = {};
    requests = [];
    transfers = [];
    progress = [];
    clients = [];
    objectExists = false;
    dropSessionResponse = false;
    dropCompletionResponse = false;
    transientCompletion = false;
    completionCount = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      if (request.method == 'POST' && request.uri.path == '/uploads/sessions') {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['bytes'], payload.length);
        expect(body['content_type'], 'video/mp4');
        expect(body['purpose'], 'FEEDBACK_VIDEO');
        final operation = body['client_operation_id'] as String;
        operations.add(operation);
        sessions.add(operation);
        if (dropSessionResponse) {
          dropSessionResponse = false;
          await dropResponse(request);
          return;
        }
        await jsonResponse(request, 200, {
          'upload_id': 'synthetic-session',
          'transport': 'presigned',
          'upload_url': '$baseUrl/storage/synthetic',
        });
      } else if (request.method == 'PUT' &&
          request.uri.path == '/storage/synthetic') {
        expect(request.headers.contentType?.mimeType, 'video/mp4');
        expect(request.headers.contentLength, payload.length);
        final received = await request.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        );
        transfers.add(received);
        objectExists = true;
        await jsonResponse(request, 200, {});
      } else if (request.method == 'POST' &&
          request.uri.path == '/uploads/sessions/synthetic-session/complete') {
        await request.drain<void>();
        completionCount++;
        if (transientCompletion) {
          request.response.headers.set(HttpHeaders.retryAfterHeader, '2');
          await jsonResponse(request, 503, {
            'code': 'UPLOAD_INSPECTION_UNAVAILABLE',
          });
        } else if (!objectExists) {
          await jsonResponse(request, 404, {'code': 'UPLOAD_OBJECT_MISSING'});
        } else if (dropCompletionResponse) {
          dropCompletionResponse = false;
          await dropResponse(request);
        } else {
          await jsonResponse(request, 200, {
            'file_url': '$baseUrl/media/confirmed',
          });
        }
      } else {
        await jsonResponse(request, 404, {'code': 'UNEXPECTED_ROUTE'});
      }
    });
  });

  tearDown(() async {
    for (final client in clients) {
      client.close(force: true);
    }
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  Future<ManagedUploadResult> upload() {
    // Each attempt has fresh HTTP clients, retaining only saved checkpoint data.
    final api = ApiClient(useAuth: false, baseUrl: baseUrl);
    api.dio.options.receiveTimeout = const Duration(seconds: 3);
    final transfer = Dio(
      BaseOptions(receiveTimeout: const Duration(seconds: 3)),
    );
    clients.addAll([api.dio, transfer]);
    return ManagedUploadTransport(api, transferClient: transfer).upload(
      file: file,
      contentType: 'video/mp4',
      purpose: 'FEEDBACK_VIDEO',
      context: ManagedUploadContext(
        operationId: 'synthetic-operation',
        checkpoint: Map<String, dynamic>.from(checkpoint),
        isCurrent: () => true,
        saveCheckpoint: (value) async {
          checkpoint = Map<String, dynamic>.from(value);
          snapshots.add(Map<String, dynamic>.from(value));
        },
        onProgress: (sent, total) => progress.add([sent, total]),
      ),
    );
  }

  test(
    'streams exact bytes with content headers before server-confirmed completion',
    () async {
      final result = await upload();
      expect(transfers, hasLength(1));
      expect(transfers.single, payload);
      expect(operations, ['synthetic-operation:0']);
      expect(sessions, hasLength(1));
      expect(completionCount, 2);
      expect(result.fileUrl, '$baseUrl/media/confirmed');
      expect(progress, isNotEmpty);
      expect(progress.last, [payload.length, payload.length]);
      expect(
        snapshots.map((value) => value['phase']),
        containsAllInOrder([
          'session_created',
          'completion_reconciling',
          'transfer_uncertain',
          'transfer_completed',
          'completion_confirmed',
        ]),
      );
    },
  );

  test(
    'lost session response replays same operation without duplicate session',
    () async {
      dropSessionResponse = true;
      await expectLater(upload(), throwsA(isA<DioException>()));
      expect(transfers, isEmpty);
      expect(checkpoint['generation'], 0);
      final result = await upload();
      expect(result.uploadId, 'synthetic-session');
      expect(operations, ['synthetic-operation:0', 'synthetic-operation:0']);
      expect(sessions, hasLength(1));
      expect(transfers, hasLength(1));
    },
  );

  test(
    'lost completion response after accepted PUT reconciles without another PUT or session',
    () async {
      dropCompletionResponse = true;
      await expectLater(upload(), throwsA(isA<DioException>()));
      expect(transfers.single, payload);
      expect(checkpoint['upload_id'], 'synthetic-session');
      expect(checkpoint['phase'], 'transfer_completed');
      final requestCount = requests.length;
      final result = await upload();
      expect(result.fileUrl, '$baseUrl/media/confirmed');
      expect(requests.skip(requestCount), [
        'POST /uploads/sessions/synthetic-session/complete',
      ]);
      expect(operations, ['synthetic-operation:0']);
      expect(transfers, hasLength(1));
      expect(sessions, hasLength(1));
    },
  );

  test(
    'real 503 exposes retry-after and preserves checkpoint and evidence for later attempt',
    () async {
      checkpoint['upload_id'] = 'synthetic-session';
      checkpoint['file_url'] = '$baseUrl/media/stale';
      objectExists = true;
      transientCompletion = true;
      await expectLater(
        upload(),
        throwsA(
          isA<DioException>()
              .having((error) => error.response?.statusCode, 'HTTP status', 503)
              .having(
                (error) => error.response?.headers.value('retry-after'),
                'backoff signal',
                '2',
              ),
        ),
      );
      expect(checkpoint['upload_id'], 'synthetic-session');
      expect(checkpoint['generation'], 0);
      expect(checkpoint['owner_marker'], 'synthetic-owner');
      expect(checkpoint['phase'], 'completion_reconciling');
      expect(await file.readAsBytes(), payload);
      expect(operations, isEmpty);
      expect(transfers, isEmpty);
      expect(
        snapshots.any((value) => value['phase'] == 'completion_confirmed'),
        isFalse,
      );
      transientCompletion = false;
      final result = await upload();
      expect(result.fileUrl, '$baseUrl/media/confirmed');
      expect(operations, isEmpty);
      expect(transfers, isEmpty);
    },
  );

  test(
    'missing local file still requires server confirmation, never trusts cached URL',
    () async {
      checkpoint['upload_id'] = 'synthetic-session';
      checkpoint['file_url'] = '$baseUrl/media/stale';
      objectExists = true;
      await file.delete();
      final result = await upload();
      expect(result.fileUrl, '$baseUrl/media/confirmed');
      expect(requests, ['POST /uploads/sessions/synthetic-session/complete']);
      expect(operations, isEmpty);
      expect(transfers, isEmpty);
      expect(checkpoint['phase'], 'completion_confirmed');
      expect(checkpoint['owner_marker'], 'synthetic-owner');
    },
  );
}
