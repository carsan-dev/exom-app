import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/features/progress_photos/data/datasources/progress_photo_remote_datasource.dart';
import 'package:exom_app/features/progress_photos/data/repositories/progress_photo_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._respond);

  final Map<String, dynamic> Function(RequestOptions options) _respond;
  final requests = <RequestOptions>[];
  final transferredBytes = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    var bytes = 0;
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes += chunk.length;
      }
    }
    transferredBytes.add(bytes);
    final response = _respond(options);
    return ResponseBody.fromString(
      jsonEncode(response['data']),
      response['status'] as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory directory;
  late File photo;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-progress-photo-wire-');
    photo = await File('${directory.path}/photo.jpg').writeAsBytes([1, 2, 3]);
  });

  tearDown(() => directory.delete(recursive: true));

  test('repository parses sessions and sends replacement without owner or purpose confusion', () async {
    final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
    final adapter = _RecordingAdapter((options) {
      switch ('${options.method} ${options.path}') {
        case 'GET /progress-photos/sessions':
          return {
            'status': 200,
            'data': {
              'data': {
                'data': [
                  {
                    'id': 'session-history',
                    'session_date': '2026-09-16',
                    'is_complete': true,
                    'photos': [
                      {
                        'id': 'photo-history',
                        'view': 'FRONT',
                        'image_url': 'r2://history',
                      },
                    ],
                  },
                ],
              },
            },
          };
        case 'POST /progress-photos/sessions':
          return {
            'status': 200,
            'data': {
              'data': {
                'id': 'session-created',
                'session_date': '2026-09-17',
                'is_complete': false,
                'photos': const [],
              },
            },
          };
        case 'POST /progress-photos/sessions/session-created/photos':
          return {
            'status': 200,
            'data': {
              'data': {
                'id': 'photo-created',
                'view': 'SIDE',
                'image_url': 'r2://created',
                'replaces_photo_id': 'photo-active',
              },
            },
          };
        default:
          throw StateError('Unexpected request: ${options.method} ${options.path}');
      }
    });
    api.dio.httpClientAdapter = adapter;
    final repository = ProgressPhotoRepositoryImpl(
      ProgressPhotoRemoteDataSourceImpl(api),
    );

    final history = await repository.getHistory(page: 2, limit: 5);
    final session = await repository.createSession(
      civilDate: '2026-09-17',
      operationId: 'session-operation',
    );
    final photoResponse = await repository.associatePhoto(
      sessionId: session.id,
      uploadId: 'upload-existing',
      view: 'SIDE',
      operationId: 'association-operation',
      replacesPhotoId: 'photo-active',
    );

    expect(history.single.photos.single.imageUrl, 'r2://history');
    expect(session.id, 'session-created');
    expect(photoResponse.replacesPhotoId, 'photo-active');
    expect(adapter.requests.first.queryParameters, {'page': 2, 'limit': 5});
    expect(adapter.requests[1].data, {
      'session_date': '2026-09-17',
      'operation_id': 'session-operation',
    });
    expect(adapter.requests[2].data, {
      'upload_id': 'upload-existing',
      'view': 'SIDE',
      'operation_id': 'association-operation',
      'replaces_photo_id': 'photo-active',
    });
    for (final request in adapter.requests.skip(1)) {
      expect((request.data as Map).containsKey('owner_id'), isFalse);
      expect((request.data as Map).containsKey('purpose'), isFalse);
    }
  });

  test('proxy upload uses PROGRESS_PHOTO and a stable client operation identity', () async {
    final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
    var completionCalls = 0;
    final adapter = _RecordingAdapter((options) {
      if (options.path == '/uploads/sessions') {
        return {
          'status': 200,
          'data': {
            'data': {
              'upload_id': 'upload-proxy',
              'upload_url': 'https://api.exom.test/uploads/proxy/photo',
              'transport': 'proxy',
            },
          },
        };
      }
      if (options.path == '/uploads/sessions/upload-proxy/complete') {
        completionCalls++;
        return completionCalls == 1
            ? {
                'status': 404,
                'data': {'code': 'UPLOAD_OBJECT_MISSING'},
              }
            : {
                'status': 200,
                'data': {
                  'data': {'file_url': 'r2://proxy-photo'},
                },
              };
      }
      if (options.path == 'https://api.exom.test/uploads/proxy/photo') {
        return {'status': 204, 'data': null};
      }
      throw StateError('Unexpected request: ${options.method} ${options.path}');
    });
    api.dio.httpClientAdapter = adapter;
    final remote = ProgressPhotoRemoteDataSourceImpl(api);
    final checkpoints = <Map<String, dynamic>>[];

    final result = await remote.uploadPhoto(
      photo,
      'image/jpeg',
      context: ManagedUploadContext(
        operationId: 'photo-operation',
        checkpoint: const {},
        saveCheckpoint: (value) async => checkpoints.add(value),
        isCurrent: () => true,
      ),
    );

    final sessionRequests = adapter.requests
        .where((request) => request.path == '/uploads/sessions')
        .toList();
    final proxyRequest = adapter.requests.singleWhere(
      (request) => request.path == 'https://api.exom.test/uploads/proxy/photo',
    );
    expect(result.uploadId, 'upload-proxy');
    expect((sessionRequests.single.data as Map)['purpose'], 'PROGRESS_PHOTO');
    expect((sessionRequests.single.data as Map)['client_operation_id'], 'photo-operation:0');
    expect(proxyRequest.method, 'POST');
    expect(proxyRequest.data, isA<FormData>());
    expect(adapter.transferredBytes[adapter.requests.indexOf(proxyRequest)], greaterThan(3));
    expect(checkpoints.last['phase'], 'completion_confirmed');
  });

  test('signed transfer PUT keeps the same progress-photo operation identity', () async {
    final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
    final transfer = Dio();
    final transferAdapter = _RecordingAdapter((options) => {'status': 200, 'data': null});
    transfer.httpClientAdapter = transferAdapter;
    var completionCalls = 0;
    final apiAdapter = _RecordingAdapter((options) {
      if (options.path == '/uploads/sessions') {
        return {
          'status': 200,
          'data': {
            'data': {
              'upload_id': 'upload-signed',
              'upload_url': 'https://storage.exom.test/progress-photo',
              'transport': 'signed',
            },
          },
        };
      }
      if (options.path == '/uploads/sessions/upload-signed/complete') {
        completionCalls++;
        return completionCalls == 1
            ? {
                'status': 404,
                'data': {'code': 'UPLOAD_OBJECT_MISSING'},
              }
            : {
                'status': 200,
                'data': {
                  'data': {'file_url': 'r2://signed-photo'},
                },
              };
      }
      throw StateError('Unexpected API request: ${options.method} ${options.path}');
    });
    api.dio.httpClientAdapter = apiAdapter;
    final remote = ProgressPhotoRemoteDataSourceImpl(
      api,
      managedUploadTransport: ManagedUploadTransport(api, transferClient: transfer),
    );

    final result = await remote.uploadPhoto(
      photo,
      'image/jpeg',
      context: ManagedUploadContext(
        operationId: 'photo-operation',
        checkpoint: const {},
        saveCheckpoint: (_) async {},
        isCurrent: () => true,
      ),
    );

    final sessionRequest = apiAdapter.requests.singleWhere(
      (request) => request.path == '/uploads/sessions',
    );
    expect(result.fileUrl, 'r2://signed-photo');
    expect((sessionRequest.data as Map)['purpose'], 'PROGRESS_PHOTO');
    expect((sessionRequest.data as Map)['client_operation_id'], 'photo-operation:0');
    expect(transferAdapter.requests.single.method, 'PUT');
    expect(transferAdapter.requests.single.headers[Headers.contentTypeHeader], 'image/jpeg');
    expect(transferAdapter.transferredBytes.single, 3);
  });
}
