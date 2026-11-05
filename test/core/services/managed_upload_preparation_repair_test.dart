import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File source;
  late File prepared;
  late ApiClient api;
  late Map<String, dynamic> saved;
  late List<Map<String, dynamic>> snapshots;
  late List<RequestOptions> requests;
  late bool current;
  late int preparations;
  FutureOr<void> Function(Map<String, dynamic>)? afterSave;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'exom-preparation-repair-',
    );
    source = await File('${directory.path}/source.mov').writeAsBytes([1, 2, 3]);
    prepared = await File('${source.path}.prepared.mp4').writeAsBytes([9]);
    saved = {
      'generation': 3,
      'phase': 'prepared',
      'prepared_path': prepared.path,
      'prepared_content_type': 'video/mp4',
      'prepared_bytes': 4,
      'owner_id': 'owner-one',
      'environment': 'isolated',
      'association_operation_id': 'association-one',
      'session_id': 'session-one',
    };
    snapshots = [];
    requests = [];
    current = true;
    preparations = 0;
    afterSave = null;
    api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.path == '/uploads/sessions/old/complete') {
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
                data: options.path == '/uploads/sessions'
                    ? {'upload_id': 'new'}
                    : {'file_url': 'r2://new'},
              ),
            );
          }
        },
      ),
    );
  });
  tearDown(() => directory.delete(recursive: true));

  Future<ManagedFeedbackUpload> upload() =>
      FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (_, _) async {
          preparations++;
          return File(
            '${directory.path}/compressed.mp4',
          ).writeAsBytes([4, 5, 6, 7]);
        },
      ).uploadMedia(
        source,
        'video/quicktime',
        context: FeedbackUploadContext(
          operationId: 'stable',
          checkpoint: saved,
          isCurrent: () => current,
          saveCheckpoint: (value) async {
            saved = value;
            snapshots.add({...value});
            await afterSave?.call(value);
          },
        ),
      );

  for (final phase in [
    'prepared',
    'session_creating',
    'session_created',
    'unknown_legacy_phase',
  ]) {
    test('repair truncated prepared file durably; phase=$phase', () async {
      saved['phase'] = phase;
      if (phase == 'session_created') saved['upload_id'] = 'old';
      expect((await upload()).uploadId, 'new');
      final generation = phase == 'prepared' ? 3 : 4;
      expect(preparations, 1);
      final repair = snapshots.singleWhere(
        (s) => s['phase'] == 'preparation_changed',
      );
      expect(repair['generation'], generation);
      for (final key in [
        'upload_id',
        'file_url',
        'prepared_path',
        'prepared_content_type',
        'prepared_bytes',
      ]) {
        expect(repair.containsKey(key), false, reason: key);
      }
      expect(
        (requests.firstWhere((r) => r.path == '/uploads/sessions').data
            as Map)['client_operation_id'],
        'stable:$generation',
      );
      expect(saved['prepared_bytes'], 4);
      expect(await prepared.readAsBytes(), [4, 5, 6, 7]);
      expect(await source.readAsBytes(), [1, 2, 3]);
      expect(saved['owner_id'], 'owner-one');
      expect(saved['environment'], 'isolated');
      expect(saved['association_operation_id'], 'association-one');
      expect(saved['session_id'], 'session-one');
    });
  }

  test(
    'crash after repair save reuses durable renewed generation on restart',
    () async {
      saved.addAll({'phase': 'session_creating'});
      afterSave = (value) {
        if (value['phase'] == 'preparation_changed') throw StateError('crash');
      };
      await expectLater(
        upload(),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'crash')),
      );
      expect(saved['generation'], 4);
      expect(preparations, 0);
      expect(requests, isEmpty);
      afterSave = null;
      expect((await upload()).uploadId, 'new');
      expect(saved['generation'], 4);
      expect(preparations, 1);
    },
  );

  test(
    'create-response-loss survives crash at replayed prepared checkpoint',
    () async {
      await prepared.writeAsBytes([4, 5, 6, 7]);
      saved['phase'] = 'session_creating';
      afterSave = (value) {
        if (value['phase'] == 'prepared') {
          throw StateError('crash before replay');
        }
      };
      await expectLater(
        upload(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'crash before replay',
          ),
        ),
      );
      expect(saved['phase'], 'prepared');
      expect(saved['generation'], 3);
      expect(requests, isEmpty);
      await prepared.writeAsBytes([9]);
      afterSave = null;
      expect((await upload()).uploadId, 'new');
      expect(saved['generation'], 4);
      expect(
        (requests.firstWhere((r) => r.path == '/uploads/sessions').data
            as Map)['client_operation_id'],
        'stable:4',
      );
      expect(preparations, 1);
    },
  );

  test(
    'owner switch after repair save prevents preparation and network',
    () async {
      saved['upload_id'] = 'old';
      afterSave = (value) {
        if (value['phase'] == 'preparation_changed') current = false;
      };
      await expectLater(
        upload(),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(preparations, 0);
      expect(requests.map((r) => r.path), ['/uploads/sessions/old/complete']);
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );

  test('remote confirmation wins over corrupt preparation', () async {
    saved['upload_id'] = 'confirmed';
    expect((await upload()).uploadId, 'confirmed');
    expect(preparations, 0);
    expect(saved['generation'], 3);
    expect(requests.map((r) => r.path), [
      '/uploads/sessions/confirmed/complete',
    ]);
    expect(await prepared.readAsBytes(), [9]);
  });
}
