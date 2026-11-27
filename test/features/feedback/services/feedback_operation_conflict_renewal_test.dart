import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/data/repositories/feedback_repository_impl.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'feedback_upload_queue_service_test.dart'
    show FakeFeedbackQueueStorage, FakeOfflineSyncService;

/// In-process model of the managed-upload API contract: a
/// `client_operation_id` is immutable and replaying it with other bytes or
/// MIME is rejected with 409 `UPLOAD_OPERATION_CONFLICT`.
class _ConflictApi {
  _ConflictApi([Map<String, ({String id, int bytes, String mime})>? sessions])
    : sessions = sessions ?? {};

  final Map<String, ({String id, int bytes, String mime})> sessions;
  final List<String> operations = [];
  final List<String> associations = [];
  final Set<String> uploaded = {};
  var _created = 0;

  /// Called for every session create; may reject instead of answering.
  DioException? Function(RequestOptions options, String operation)? onCreate;

  /// Operations whose create commits on the server but whose response is lost.
  final Set<String> loseCreateResponse = {};

  /// Error answered by the first `POST /feedback`, if any.
  ({int status, String code})? feedbackError;

  /// Error codes answered by `complete` / proxy transfer, per upload id.
  final Map<String, ({int status, String code})> completeErrors = {};
  final Map<String, ({int status, String code})> transferErrors = {};

  /// Sessions answer a presigned direct PUT URL instead of the proxy.
  bool direct = false;

  /// Feedback rows by `client_upload_id`; replays return the existing row
  /// (exom-api `FeedbackService.create`).
  final Map<String, ({String id, String uploadId})> feedback = {};

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
            final forced = onCreate?.call(options, operation);
            if (forced != null) {
              handler.reject(forced);
              return;
            }
            final existing = sessions[operation];
            if (existing != null &&
                (existing.bytes != bytes || existing.mime != mime)) {
              handler.reject(
                error(options, 409, 'UPLOAD_OPERATION_CONFLICT'),
              );
              return;
            }
            final session =
                existing ??
                (id: 'upload-${++_created}', bytes: bytes, mime: mime);
            sessions[operation] = session;
            if (loseCreateResponse.remove(operation)) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {
                    'upload_id': session.id,
                    'upload_url': direct
                        ? 'https://storage.invalid/${session.id}'
                        : '/uploads/sessions/${session.id}/file',
                    'transport': direct ? 'direct' : 'proxy',
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
            final failure = completeErrors[id];
            if (failure != null) {
              handler.reject(error(options, failure.status, failure.code));
              return;
            }
            if (!uploaded.contains(id)) {
              handler.reject(error(options, 404, 'UPLOAD_OBJECT_MISSING'));
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {'upload_id': id, 'file_url': 'r2://$id'},
                },
              ),
            );
            return;
          }
          final file = RegExp(
            r'^/uploads/sessions/([^/]+)/file$',
          ).firstMatch(path);
          if (file != null) {
            final failure = transferErrors[file.group(1)!];
            if (failure != null) {
              handler.reject(error(options, failure.status, failure.code));
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
            final clientUploadId = body['client_upload_id'] as String;
            associations.add(clientUploadId);
            final failure = feedbackError;
            if (failure != null) {
              feedbackError = null;
              handler.reject(error(options, failure.status, failure.code));
              return;
            }
            final row = feedback.putIfAbsent(
              clientUploadId,
              () => (
                id: 'feedback-${feedback.length + 1}',
                uploadId: body['upload_id'] as String,
              ),
            );
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {
                    'id': row.id,
                    'media_type': 'VIDEO',
                    'media_url': 'r2://${row.uploadId}',
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

  static DioException error(RequestOptions options, int status, String code) =>
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

/// Records every persisted queue snapshot so a crash can be replayed from the
/// exact durable state at any point.
class _RecordingStorage extends FakeFeedbackQueueStorage {
  _RecordingStorage(super.queue);

  final List<List<Map<String, dynamic>>> snapshots = [];

  @override
  Future<void> saveFeedbackUploadQueue(List<Map<String, dynamic>> value) async {
    await super.saveFeedbackUploadQueue(value);
    snapshots.add(getFeedbackUploadQueue());
  }
}

/// Real owner-scoped storage with a hook that runs right before a write.
class _SwitchingStorage extends LocalStorage {
  _SwitchingStorage(LocalAuthSession? Function() session)
    : super(currentSession: session, environment: 'https://test.exom.invalid');

  void Function(List<Map<String, dynamic>> queue)? beforeSave;

  @override
  Future<void> saveFeedbackUploadQueue(List<Map<String, dynamic>> queue) {
    beforeSave?.call(queue);
    return super.saveFeedbackUploadQueue(queue);
  }
}

Map<String, dynamic> _checkpoint(Map<String, dynamic> row) =>
    Map<String, dynamic>.from(row['upload_checkpoint'] as Map? ?? const {});

void main() {
  late Directory directory;
  late File source;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'exom-feedback-conflict-renewal-',
    );
    source = await File(
      '${directory.path}/stable.mp4',
    ).writeAsBytes([1, 2, 3, 4, 5, 6]);
  });
  tearDown(() => directory.delete(recursive: true));

  Map<String, dynamic> row([Map<String, dynamic> extra = const {}]) => {
    'id': 'stable',
    'file_path': source.path,
    'content_type': 'video/mp4',
    'media_type': 'VIDEO',
    'status': 'queued',
    'attempts': 0,
    ...extra,
  };

  /// Every compression yields 4 bytes; a v1.2.4 session kept 3 bytes.
  ({FeedbackUploadQueueService queue, int Function() compressions}) build(
    FakeFeedbackQueueStorage storage,
    _ConflictApi server, {
    bool Function()? isAuthenticated,
    Dio? transferClient,
  }) {
    final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
    server.attach(api);
    var compressions = 0;
    final offline = FakeOfflineSyncService(storage);
    final queue = FeedbackUploadQueueService(
      FeedbackRepositoryImpl(
        FeedbackRemoteDataSourceImpl(
          api,
          transferClient: transferClient,
          prepareFile: (_, _) async => File(
            '${directory.path}/compressed-${++compressions}.mp4',
          ).writeAsBytes([9, 9, 9, 9]),
        ),
      ),
      storage,
      offline,
      isAuthenticated: isAuthenticated ?? () => true,
      connectivityChanges: const Stream.empty(),
    );
    addTearDown(queue.dispose);
    addTearDown(offline.dispose);
    return (queue: queue, compressions: () => compressions);
  }

  /// Makes a backed-off row due now, as the clock would after the delay.
  void due(FakeFeedbackQueueStorage storage) {
    storage.queue = [
      for (final item in storage.queue)
        Map<String, dynamic>.from(item)..remove('next_attempt_at'),
    ];
  }

  ({String id, int bytes, String mime}) legacy(int index) =>
      (id: 'legacy-$index', bytes: 3, mime: 'video/mp4');

  test(
    'transport renews a create conflict once, reusing the prepared artifact',
    () async {
      final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
      final server = _ConflictApi({'stable:0': legacy(0)})..attach(api);
      final saved = <Map<String, dynamic>>[];
      var compressions = 0;
      final result = await FeedbackRemoteDataSourceImpl(
        api,
        prepareFile: (_, _) async => File(
          '${directory.path}/compressed-${++compressions}.mp4',
        ).writeAsBytes([9, 9, 9, 9]),
      ).uploadMedia(
        source,
        'video/mp4',
        context: FeedbackUploadContext(
          operationId: 'stable',
          checkpoint: {'generation': 0, 'phase': 'session_creating'},
          isCurrent: () => true,
          saveCheckpoint: (value) async => saved.add(value),
        ),
      );

      expect(result.uploadId, 'upload-1');
      expect(server.operations, ['stable:0', 'stable:1']);
      expect(compressions, 1);
      final renewal = saved.firstWhere(
        (value) => value['phase'] == 'operation_conflict',
      );
      expect(renewal['generation'], 1);
      expect(renewal['operation_conflict_renewals'], 1);
      expect(renewal.containsKey('upload_id'), false);
      expect(renewal.containsKey('session_attempted'), false);
      expect(renewal.containsKey('prepared_bytes'), false);
      expect(renewal.containsKey('prepared_content_type'), false);
      expect(renewal['prepared_path'], '${source.path}.prepared.mp4');
      expect(saved.last['generation'], 1);
      expect(saved.last['prepared_bytes'], 4);
      expect(await source.exists(), true);
      expect(await File('${source.path}.prepared.mp4').exists(), true);
    },
  );

  test(
    'a second conflict in one run is renewed durably and backed off',
    () async {
      final storage = FakeFeedbackQueueStorage([row()]);
      final server = _ConflictApi({
        'stable:0': legacy(0),
        'stable:1': legacy(1),
      });
      final queue = build(storage, server);

      await queue.queue.processQueue();
      final item = storage.queue.single;
      expect(item['status'], 'queued', reason: '${item['last_error']}');
      expect(item['last_error'], 'UPLOAD_OPERATION_CONFLICT');
      expect(
        DateTime.parse(item['next_attempt_at'] as String)
            .isAfter(DateTime.now()),
        true,
      );
      final checkpoint = _checkpoint(item);
      expect(checkpoint['generation'], 2);
      expect(checkpoint['phase'], 'operation_conflict');
      expect(checkpoint['operation_conflict_renewals'], 2);
      expect(checkpoint['prepared_path'], '${source.path}.prepared.mp4');
      expect(server.operations, ['stable:0', 'stable:1']);

      due(storage);
      await queue.queue.processQueue();
      expect(storage.queue.single['status'], 'completed');
      expect(storage.queue.single['id'], 'stable');
      expect(server.operations.last, 'stable:2');
      expect(server.associations, ['stable']);
      expect(queue.compressions(), 1);
    },
  );

  test(
    'manual retry of a failed conflict renews before creating a session',
    () async {
      final storage = FakeFeedbackQueueStorage([
        row({
          'status': 'failed',
          'attempts': 2,
          'last_error': 'UPLOAD_OPERATION_CONFLICT',
          'last_http_status': 409,
          'upload_checkpoint': {'generation': 0, 'phase': 'session_creating'},
        }),
      ]);
      final server = _ConflictApi({'stable:0': legacy(0)});
      final queue = build(storage, server);

      await queue.queue.retry('stable');
      expect(storage.queue.single['status'], 'completed');
      expect(server.operations, ['stable:1']);
      expect(server.sessions['stable:0']!.bytes, 3);
      expect(server.associations, ['stable']);
    },
  );

  test(
    'crash after persisting the renewal resumes with the new generation',
    () async {
      final storage = _RecordingStorage([row()]);
      // The process dies before `stable:1` reaches the server.
      final first = _ConflictApi({'stable:0': legacy(0)})
        ..onCreate = (options, operation) => operation == 'stable:1'
            ? DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              )
            : null;
      await build(storage, first).queue.processQueue();
      expect(storage.queue.single['status'], 'queued');
      expect(await source.exists(), true);
      final atCrash = storage.snapshots.firstWhere(
        (queue) => _checkpoint(queue.single)['phase'] == 'operation_conflict',
      );
      expect(_checkpoint(atCrash.single)['generation'], 1);

      // Process restart from the durable state; `stable:1` was never sent.
      final restored = FakeFeedbackQueueStorage(atCrash);
      final server = _ConflictApi({'stable:0': legacy(0)});
      final queue = build(restored, server);
      await queue.queue.processQueue();
      expect(restored.queue.single['status'], 'completed');
      expect(server.operations, ['stable:1']);
      expect(server.sessions.keys, ['stable:0', 'stable:1']);
      expect(server.associations, ['stable']);
      expect(queue.compressions(), 0, reason: 'prepared artifact reused');
    },
  );

  test(
    'lost create response after renewal replays the same new operation',
    () async {
      final storage = FakeFeedbackQueueStorage([row()]);
      final server = _ConflictApi({'stable:0': legacy(0)})
        ..loseCreateResponse.add('stable:1');
      final queue = build(storage, server);

      await queue.queue.processQueue();
      final item = storage.queue.single;
      expect(item['status'], 'queued');
      expect(_checkpoint(item)['generation'], 1);
      expect(_checkpoint(item)['session_attempted'], true);

      due(storage);
      await queue.queue.processQueue();
      expect(storage.queue.single['status'], 'completed');
      expect(server.operations, ['stable:0', 'stable:1', 'stable:1']);
      expect(server.sessions['stable:1']!.id, 'upload-1');
      expect(server.sessions.length, 2);
      expect(server.associations, ['stable']);
      expect(queue.compressions(), 1);
    },
  );

  test(
    'signing out while a conflict arrives does not renew or send',
    () async {
      var authenticated = true;
      final storage = FakeFeedbackQueueStorage([row()]);
      final server = _ConflictApi({'stable:0': legacy(0)});
      server.onCreate = (options, operation) {
        if (operation != 'stable:0') return null;
        authenticated = false;
        return _ConflictApi.error(options, 409, 'UPLOAD_OPERATION_CONFLICT');
      };
      final queue = build(
        storage,
        server,
        isAuthenticated: () => authenticated,
      );

      await queue.queue.processQueue();
      expect(server.operations, ['stable:0']);
      final item = storage.queue.single;
      expect(item['status'], 'queued');
      expect(_checkpoint(item)['generation'], 0);
      expect(_checkpoint(item)['operation_conflict_renewals'], isNull);
      expect(await source.exists(), true);
    },
  );

  group('account switch during renewal', () {
    late LocalAuthSession? session;
    late _SwitchingStorage storage;
    late Map<String, dynamic> sentinel;

    setUp(() async {
      Hive.init(directory.path);
      if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
        Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
      }
      await Hive.openBox('auth_box');
      await Hive.openBox('cache_box');
      await Hive.openBox('settings_box');
      await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
      storage = _SwitchingStorage(() => session);
      // B already owns unrelated failed evidence that must stay untouched.
      session = const LocalAuthSession(uid: 'B', generation: 2);
      sentinel = {
        'id': 'b-sentinel',
        'file_path': '${directory.path}/b.mp4',
        'content_type': 'video/mp4',
        'media_type': 'VIDEO',
        'status': 'failed',
        'last_error': 'UPLOAD_OPERATION_CONFLICT',
        'upload_checkpoint': {'generation': 7, 'phase': 'session_creating'},
        ...storage.queueIdentity,
      };
      await storage.saveFeedbackUploadQueue([sentinel]);
      session = const LocalAuthSession(uid: 'A', generation: 1);
      await storage.saveFeedbackUploadQueue([
        {...row(), ...storage.queueIdentity},
      ]);
    });
    tearDown(Hive.close);

    ({FeedbackUploadQueueService queue, _ConflictApi server}) start(
      _ConflictApi server,
    ) {
      final api = ApiClient(useAuth: false, baseUrl: 'https://api.invalid');
      server.attach(api);
      final offline = FakeOfflineSyncService(storage);
      final queue = FeedbackUploadQueueService(
        FeedbackRepositoryImpl(
          FeedbackRemoteDataSourceImpl(
            api,
            prepareFile: (_, _) async => File(
              '${directory.path}/compressed.mp4',
            ).writeAsBytes([9, 9, 9, 9]),
          ),
        ),
        storage,
        offline,
        isAuthenticated: () => session != null,
        applicationSupportDirectory: () async => directory,
        connectivityChanges: const Stream.empty(),
      );
      addTearDown(queue.dispose);
      addTearDown(offline.dispose);
      return (queue: queue, server: server);
    }

    Future<Map<String, dynamic>> expectIsolated() async {
      session = const LocalAuthSession(uid: 'B', generation: 4);
      expect(storage.getFeedbackUploadQueue(), [sentinel]);
      session = const LocalAuthSession(uid: 'A', generation: 3);
      expect(await source.exists(), true);
      return storage.getFeedbackUploadQueue().single;
    }

    test('A conflict is never renewed into or sent for B', () async {
      final server = _ConflictApi({'stable:0': legacy(0)});
      var switched = false;
      server.onCreate = (options, operation) {
        if (operation != 'stable:0' || switched) return null;
        switched = true;
        session = const LocalAuthSession(uid: 'B', generation: 2);
        return _ConflictApi.error(options, 409, 'UPLOAD_OPERATION_CONFLICT');
      };
      final queue = start(server).queue;

      await queue.processQueue();
      expect(server.operations, ['stable:0']);
      final item = await expectIsolated();
      expect(_checkpoint(item)['generation'], 0);
      expect(_checkpoint(item)['operation_conflict_renewals'], isNull);

      await queue.processQueue();
      expect(storage.getFeedbackUploadQueue().single['status'], 'completed');
      expect(server.operations, ['stable:0', 'stable:0', 'stable:1']);
      expect(server.associations, ['stable']);
    });

    for (final (renewals, owner) in [(1, 'transport'), (2, 'queue')]) {
      test('switch immediately before the $owner renewal persist', () async {
        final server = _ConflictApi({
          'stable:0': legacy(0),
          'stable:1': legacy(1),
        });
        storage.beforeSave = (queue) {
          final renewal = queue.any(
            (row) =>
                _checkpoint(row)['operation_conflict_renewals'] == renewals,
          );
          if (!renewal) return;
          storage.beforeSave = null;
          session = const LocalAuthSession(uid: 'B', generation: 2);
        };
        await start(server).queue.processQueue();

        expect(
          server.operations,
          renewals == 1 ? ['stable:0'] : ['stable:0', 'stable:1'],
        );
        final item = await expectIsolated();
        // The stale renewal was never written; the last durable A state stays.
        final checkpoint = _checkpoint(item);
        expect(checkpoint['generation'], renewals - 1);
        expect(
          checkpoint['operation_conflict_renewals'],
          renewals == 1 ? isNull : 1,
        );
        expect(checkpoint['phase'], 'session_creating');
        expect(item['id'], 'stable');
      });
    }

    test('switch during the second-create conflict', () async {
      final server = _ConflictApi({
        'stable:0': legacy(0),
        'stable:1': legacy(1),
      });
      server.onCreate = (options, operation) {
        if (operation != 'stable:1') return null;
        session = const LocalAuthSession(uid: 'B', generation: 2);
        return _ConflictApi.error(options, 409, 'UPLOAD_OPERATION_CONFLICT');
      };
      await start(server).queue.processQueue();

      expect(server.operations, ['stable:0', 'stable:1']);
      final item = await expectIsolated();
      final checkpoint = _checkpoint(item);
      expect(checkpoint['generation'], 1);
      expect(checkpoint['operation_conflict_renewals'], 1);
      expect(checkpoint['phase'], 'session_creating');
    });
  });

  group('terminal controls keep their generation', () {
    for (final (status, code) in [
      (409, 'FEEDBACK_UPLOAD_CONFLICT'),
      (409, 'TRAINING_SESSION_CONFLICT'),
      (409, 'UPLOAD_OPERATION_CONFLICT'),
    ]) {
      test('POST /feedback $status $code stays failed', () async {
        final storage = FakeFeedbackQueueStorage([row()]);
        final server = _ConflictApi()
          ..feedbackError = (status: status, code: code);
        await build(storage, server).queue.processQueue();
        final item = storage.queue.single;
        expect(item['status'], 'failed');
        expect(item['last_error'], code);
        expect(_checkpoint(item)['generation'], 0);
        expect(_checkpoint(item)['operation_conflict_renewals'], isNull);
        expect(item['verified_upload_id'], 'upload-1');
        expect(server.operations, ['stable:0']);
      });
    }

    for (final (status, code) in [
      (413, 'UPLOAD_TOO_LARGE'),
      (400, 'UPLOAD_MIME_NOT_ALLOWED'),
      (409, 'UPLOAD_SESSION_LIMIT'),
    ]) {
      test('POST /uploads/sessions $status $code stays failed', () async {
        final storage = FakeFeedbackQueueStorage([row()]);
        final server = _ConflictApi()
          ..onCreate = (options, _) =>
              _ConflictApi.error(options, status, code);
        await build(storage, server).queue.processQueue();
        final item = storage.queue.single;
        expect(item['status'], 'failed');
        expect(item['last_error'], code);
        expect(_checkpoint(item)['generation'], 0);
        expect(server.operations, ['stable:0']);
      });
    }
  });

  test('renewals stop at the persisted bound with a clear code', () async {
    final storage = FakeFeedbackQueueStorage([row()]);
    final server = _ConflictApi()
      ..onCreate = (options, _) =>
          _ConflictApi.error(options, 409, 'UPLOAD_OPERATION_CONFLICT');
    final queue = build(storage, server);

    await queue.queue.processQueue();
    expect(storage.queue.single['status'], 'queued');
    due(storage);
    await queue.queue.processQueue();

    final item = storage.queue.single;
    expect(item['status'], 'failed');
    expect(item['last_error'], 'upload_operation_conflict_exhausted');
    expect(item['last_http_status'], 409);
    expect(
      _checkpoint(item)['operation_conflict_renewals'],
      maxManagedUploadConflictRenewals,
    );
    expect(server.operations, [
      'stable:0',
      'stable:1',
      'stable:2',
      'stable:3',
    ]);
    expect(item['id'], 'stable');
    expect(await source.exists(), true);
    expect(await File('${source.path}.prepared.mp4').exists(), true);

    // Automatic work stops; only an explicit owner retry starts a new bound.
    due(storage);
    await queue.queue.processQueue();
    expect(server.operations, hasLength(4));

    await queue.queue.retry('stable');
    expect(server.operations.skip(4), ['stable:4', 'stable:5']);
    final retried = storage.queue.single;
    expect(retried['status'], 'queued');
    expect(_checkpoint(retried)['generation'], 6);
    expect(
      _checkpoint(retried)['operation_conflict_renewals'],
      maxManagedUploadConflictRenewals,
    );
  });

  test(
    'feedback created before a lost response is replayed after renewal',
    () async {
      // A previous attempt committed feedback for `stable` with `old`, but its
      // response and verified upload were lost (legacy row state).
      final storage = FakeFeedbackQueueStorage([
        row({
          'status': 'failed',
          'last_error': 'UPLOAD_OPERATION_CONFLICT',
          'upload_checkpoint': {'generation': 0, 'phase': 'session_creating'},
        }),
      ]);
      final server = _ConflictApi({'stable:0': legacy(0)});
      server.feedback['stable'] = (id: 'feedback-original', uploadId: 'old');
      await build(storage, server).queue.retry('stable');

      final item = storage.queue.single;
      expect(item['status'], 'completed');
      expect(server.operations, ['stable:1']);
      expect(server.associations, ['stable']);
      expect(server.feedback, hasLength(1));
      expect(server.feedback['stable']!.id, 'feedback-original');
    },
  );

  test('a verified upload bypasses conflict renewal on retry', () async {
    final storage = FakeFeedbackQueueStorage([
      row({
        'status': 'failed',
        'last_error': 'UPLOAD_OPERATION_CONFLICT',
        'verified_upload_id': 'verified',
        'verified_file_url': 'r2://verified',
        'upload_checkpoint': {'generation': 2, 'phase': 'completion_confirmed'},
      }),
    ]);
    final server = _ConflictApi();
    await build(storage, server).queue.retry('stable');

    final item = storage.queue.single;
    expect(item['status'], 'completed');
    expect(server.operations, isEmpty);
    expect(_checkpoint(item)['generation'], 2);
    expect(_checkpoint(item)['operation_conflict_renewals'], isNull);
    expect(server.feedback['stable']!.uploadId, 'verified');
  });

  test('expiry renewal then a conflict counts the bound once', () async {
    final storage = FakeFeedbackQueueStorage([
      row({
        'status': 'queued',
        'attempts': 1,
        'upload_checkpoint': {
          'generation': 0,
          'phase': 'transfer_uncertain',
          'upload_id': 'old',
          'session_attempted': true,
        },
      }),
    ]);
    final server = _ConflictApi({'stable:1': legacy(1)})
      ..completeErrors['old'] = (status: 409, code: 'UPLOAD_EXPIRED');
    final queue = build(storage, server);

    await queue.queue.processQueue();
    final item = storage.queue.single;
    expect(item['status'], 'queued');
    expect(item['last_error'], 'UPLOAD_OPERATION_CONFLICT');
    expect(server.operations, ['stable:1']);
    expect(_checkpoint(item)['generation'], 2);
    expect(_checkpoint(item)['operation_conflict_renewals'], 1);

    due(storage);
    await queue.queue.processQueue();
    expect(storage.queue.single['status'], 'completed');
    expect(server.operations, ['stable:1', 'stable:2']);
    expect(queue.compressions(), 1);
  });

  group('conflict code outside session creation is not renewed', () {
    const conflict = (status: 409, code: 'UPLOAD_OPERATION_CONFLICT');

    void expectTerminal(FakeFeedbackQueueStorage storage, _ConflictApi server) {
      final item = storage.queue.single;
      expect(item['status'], 'failed');
      expect(item['last_error'], 'UPLOAD_OPERATION_CONFLICT');
      expect(_checkpoint(item)['generation'], 0);
      expect(_checkpoint(item)['operation_conflict_renewals'], isNull);
      expect(server.operations, ['stable:0']);
      expect(server.associations, isEmpty);
    }

    test('from complete', () async {
      final storage = FakeFeedbackQueueStorage([row()]);
      final server = _ConflictApi()..completeErrors['upload-1'] = conflict;
      await build(storage, server).queue.processQueue();
      expectTerminal(storage, server);
    });

    test('from the proxy transfer', () async {
      final storage = FakeFeedbackQueueStorage([row()]);
      final server = _ConflictApi()..transferErrors['upload-1'] = conflict;
      await build(storage, server).queue.processQueue();
      expectTerminal(storage, server);
    });

    test('from the direct PUT', () async {
      final storage = FakeFeedbackQueueStorage([row()]);
      final server = _ConflictApi()..direct = true;
      final transfer = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              _ConflictApi.error(options, 409, 'UPLOAD_OPERATION_CONFLICT'),
            ),
          ),
        );
      addTearDown(transfer.close);
      await build(
        storage,
        server,
        transferClient: transfer,
      ).queue.processQueue();
      expectTerminal(storage, server);
    });

    for (final status in [400, 413]) {
      test('from create with status $status', () async {
        final storage = FakeFeedbackQueueStorage([row()]);
        final server = _ConflictApi()
          ..onCreate = (options, _) =>
              _ConflictApi.error(options, status, 'UPLOAD_OPERATION_CONFLICT');
        await build(storage, server).queue.processQueue();
        expectTerminal(storage, server);
      });
    }
  });

  group('isManagedUploadOperationConflict', () {
    DioException response(
      String method,
      String path, {
      String baseUrl = 'https://api.invalid/api/v1',
      int status = 409,
    }) => _ConflictApi.error(
      RequestOptions(method: method, path: path, baseUrl: baseUrl),
      status,
      'UPLOAD_OPERATION_CONFLICT',
    );

    test('accepts only POST to the create endpoint', () {
      for (final accepted in [
        response('POST', '/uploads/sessions'),
        response(
          'post',
          'uploads/sessions',
          baseUrl: 'https://api.invalid/api/v1/',
        ),
        response(
          'POST',
          'https://api.invalid/api/v1/uploads/sessions/',
          baseUrl: '',
        ),
      ]) {
        expect(
          isManagedUploadOperationConflict(accepted),
          true,
          reason: '${accepted.requestOptions.uri}',
        );
      }
      for (final rejected in [
        response('PUT', '/uploads/sessions'),
        response('GET', '/uploads/sessions'),
        response('POST', '/uploads/sessions/upload-1/complete'),
        response('POST', '/uploads/sessions/upload-1/file'),
        response('POST', '/feedback'),
        response('POST', 'https://storage.invalid/upload-1', baseUrl: ''),
        response('POST', '/uploads/sessions', status: 400),
        response('POST', '/uploads/sessions', status: 413),
      ]) {
        expect(
          isManagedUploadOperationConflict(rejected),
          false,
          reason:
              '${rejected.requestOptions.method} '
              '${rejected.requestOptions.uri} '
              '${rejected.response?.statusCode}',
        );
      }
    });
  });
}
