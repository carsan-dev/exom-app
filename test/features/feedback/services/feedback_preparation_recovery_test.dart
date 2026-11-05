import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'feedback_upload_queue_service_test.dart'
    show FakeFeedbackRepository, FakeOfflineSyncService;

const _owner = 'synthetic-A';
const _environment = 'synthetic-test';
const _operation = '11111111111111111111111111111111';
const _attempt = '22222222222222222222222222222222';
const _channel = MethodChannel('com.exommethod.exom/video_compression');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

class _ImagePlatform extends UnsupportedFlutterImageCompress {
  _ImagePlatform(this.onCompress);
  final Uint8List? Function() onCompress;

  @override
  Future<Uint8List?> compressWithFile(
    String path, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    expect([minWidth, minHeight, quality, rotate], [1200, 1200, 75, 0]);
    expect(autoCorrectionAngle, isTrue);
    expect(format, CompressFormat.jpeg);
    expect(keepExif, isFalse);
    return onCompress();
  }
}

class _Storage extends LocalStorage {
  _Storage()
    : super(
        currentSession: () =>
            const LocalAuthSession(uid: _owner, generation: 1),
        environment: _environment,
      );

  bool throwAfterPreparedSave = false;
  bool throwAfterAdoption = false;

  @override
  Future<void> saveFeedbackUploadQueue(List<Map<String, dynamic>> queue) async {
    await super.saveFeedbackUploadQueue(queue);
    if (throwAfterPreparedSave &&
        queue.any(
          (row) => (row['upload_checkpoint'] as Map?)?['phase'] == 'prepared',
        )) {
      throwAfterPreparedSave = false;
      throw StateError('Synthetic lost checkpoint acknowledgement');
    }
    if (throwAfterAdoption &&
        queue.any(
          (row) => ((row['preparation_attempts'] as List?) ?? const [])
              .whereType<Map>()
              .any((attempt) => attempt['prepared'] == 'adopted'),
        )) {
      throwAfterAdoption = false;
      throw StateError('Synthetic lost adoption acknowledgement');
    }
  }
}

class _Repository extends FakeFeedbackRepository {
  _Repository(this.datasource);
  final FeedbackRemoteDataSource datasource;

  @override
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType, {
    FeedbackUploadContext? context,
  }) => datasource.uploadMedia(file, contentType, context: context);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  late Directory attemptDirectory;
  late File source;
  late File compressed;
  late File prepared;
  late _Storage storage;
  late FakeOfflineSyncService offline;
  late FeedbackUploadQueueService queue;
  late bool maintenanceBusy;
  late bool deleteFails;
  late Future<void> Function()? onMaintenance;
  late Future<void> Function()? onPlan;
  late Directory? planned;
  late String? lease;
  late List<String> events;

  Map<String, dynamic> row({
    String status = 'failed',
    String preparedState = 'unadopted',
  }) => {
    ...storage.queueIdentity,
    'id': _operation,
    'file_path': source.path,
    'status': status,
    'content_type': 'video/mp4',
    'media_type': 'VIDEO',
    'preparation_attempts': [
      {
        'version': 1,
        'owner_id': _owner,
        'environment': _environment,
        'operation_id': _operation,
        'attempt_id': _attempt,
        'source_path': source.path,
        'kind': 'video',
        'compressed': 'unadopted',
        'prepared': preparedState,
      },
    ],
  };

  Map<String, dynamic> receipt() => {
    ...row(status: 'completed', preparedState: 'adopted'),
    'cleanup_pending': true,
    'verified_upload_id': 'synthetic-receipt',
    'queued_at': '2020-01-01T00:00:00.000Z',
    'upload_checkpoint': {'prepared_path': prepared.path},
  };

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final temporaryRoot = await Directory.systemTemp.resolveSymbolicLinks();
    final created = await Directory(temporaryRoot).createTemp('exom-l2-test-');
    sandbox = Directory(await created.resolveSymbolicLinks());
    expect(sandbox.parent.path, Directory(temporaryRoot).path);
    final scope = sha256
        .convert(utf8.encode(jsonEncode([_environment, _owner])))
        .toString();
    attemptDirectory = await Directory(
      '${sandbox.path}/feedback_preparation_v1/$scope/$_operation/$_attempt',
    ).create(recursive: true);
    source = await File('${sandbox.path}/original.mp4').writeAsBytes([1, 2]);
    compressed = await File(
      '${attemptDirectory.path}/compressed.mp4',
    ).writeAsBytes([3]);
    prepared = await File(
      '${attemptDirectory.path}/prepared.mp4',
    ).writeAsBytes([4]);
    Hive.init(sandbox.path);
    await Hive.openBox('cache_box');
    storage = _Storage();
    maintenanceBusy = false;
    deleteFails = false;
    onMaintenance = null;
    onPlan = null;
    planned = null;
    lease = null;
    events = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProvider,
      (call) async => sandbox.path,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      events.add(call.method);
      final args = call.arguments as Map?;
      switch (call.method) {
        case 'acquireMaintenance':
          await onMaintenance?.call();
          if (maintenanceBusy || lease != null) return null;
          return lease = 'maintenance';
        case 'acquirePreparation':
          if (lease != null) return null;
          return lease = 'preparation';
        case 'releasePreparationLease':
          expect(args!['token'], lease);
          lease = null;
          return null;
        case 'planPreparation':
          expect(lease, 'preparation');
          final base = attemptDirectory.parent.path;
          planned = Directory('$base/${args!['attempt']}');
          expect(await planned!.exists(), isFalse);
          await onPlan?.call();
          return planned!.path;
        case 'openPreparation':
          expect(lease, 'preparation');
          final journal =
              storage.getFeedbackUploadQueue().single['preparation_attempts']
                  as List;
          expect((journal.last as Map)['prepared'], 'unadopted');
          await planned!.create();
          return null;
        case 'compress':
          expect(args!['token'], 'preparation');
          final directory = planned;
          final output = File(
            directory == null
                ? '${sandbox.path}/direct-compressed.mp4'
                : '${directory.path}/compressed.mp4',
          );
          await output.writeAsBytes([3, 4, 5, 6]);
          return output.path;
        case 'deletePreparationFile':
          expect(args!['token'], 'maintenance');
          if (deleteFails) return false;
          final base = attemptDirectory.parent.path;
          final file = File('$base/${args['attempt']}/${args['leaf']}');
          if (await file.exists()) await file.delete();
          return true;
        default:
          throw StateError('Unexpected method: ${call.method}');
      }
    });
    offline = FakeOfflineSyncService(storage);
    queue = FeedbackUploadQueueService(
      FakeFeedbackRepository(),
      storage,
      offline,
      isAuthenticated: () => true,
      connectivityChanges: const Stream.empty(),
      applicationSupportDirectory: () async => sandbox,
    );
  });

  tearDown(() async {
    await queue.dispose();
    await offline.dispose();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProvider,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
    await Hive.close();
    await sandbox.delete(recursive: true);
  });

  test(
    'restart sweeps both unadopted leaves without touching source',
    () async {
      await storage.saveFeedbackUploadQueue([row()]);

      await queue.processQueue();

      expect(await source.readAsBytes(), [1, 2]);
      expect(await compressed.exists(), isFalse);
      expect(await prepared.exists(), isFalse);
    },
  );

  test(
    'reopened Hive retains ownership and can sweep journaled leaves',
    () async {
      await storage.saveFeedbackUploadQueue([row()]);
      await Hive.close();
      Hive.init(sandbox.path);
      await Hive.openBox('cache_box');

      await queue.processQueue();

      expect(await compressed.exists(), isFalse);
      expect(await prepared.exists(), isFalse);
      expect(storage.getFeedbackUploadQueue(), hasLength(1));
      expect(await source.readAsBytes(), [1, 2]);
    },
  );

  test('discard preserves unsettled intent while a writer may live', () async {
    await storage.saveFeedbackUploadQueue([row()]);
    maintenanceBusy = true;

    await queue.discard(_operation);

    expect(await source.exists(), isTrue);
    expect(await compressed.exists(), isTrue);
    expect(await prepared.exists(), isTrue);
    final persisted = storage.getFeedbackUploadQueue().single;
    expect(persisted['discard_requested'], isTrue);
    expect(persisted['preparation_attempts'], row()['preparation_attempts']);
    maintenanceBusy = false;
    await queue.processQueue();
    expect(storage.getFeedbackUploadQueue(), isEmpty);
    expect(await source.exists(), isFalse);
    expect(await compressed.exists(), isFalse);
    expect(await prepared.exists(), isFalse);
  });

  test(
    'adoption while maintenance waits cannot become a stale candidate',
    () async {
      await storage.saveFeedbackUploadQueue([row()]);
      final entered = Completer<void>();
      final release = Completer<void>();
      onMaintenance = () async {
        if (entered.isCompleted) return;
        entered.complete();
        await release.future;
      };
      final processing = queue.processQueue();
      await entered.future;
      await storage.saveFeedbackUploadQueue([
        {
          ...row(preparedState: 'adopted'),
          'status': 'completed',
          'cleanup_pending': false,
          'verified_upload_id': 'receipt',
        },
      ]);
      release.complete();
      await processing;
      expect(await compressed.exists(), isFalse);
      expect(await prepared.readAsBytes(), [4]);
      expect(
        storage.getFeedbackUploadQueue().single['verified_upload_id'],
        'receipt',
      );
    },
  );

  test(
    'failed deletion and foreign raw pending references veto cleanup',
    () async {
      final foreign = LocalStorage(
        currentSession: () =>
            const LocalAuthSession(uid: 'foreign', generation: 1),
        environment: 'foreign-environment',
      );
      await foreign.cacheData('progress_photo_upload_queue', [
        {'source_file_path': prepared.path, 'journal_version': 9000},
      ]);
      await storage.saveFeedbackUploadQueue([row()]);
      deleteFails = true;
      await queue.processQueue();
      expect(
        storage.getFeedbackUploadQueue().single['preparation_attempts'],
        row()['preparation_attempts'],
      );
      expect(await compressed.exists(), isTrue);
      expect(await prepared.exists(), isTrue);

      deleteFails = false;
      await queue.processQueue();
      expect(await compressed.exists(), isFalse);
      expect(await prepared.exists(), isTrue);
      expect(
        foreign.getCachedList('progress_photo_upload_queue'),
        hasLength(1),
      );
    },
  );

  test('unknown journal and unknown legacy files remain untouched', () async {
    final original = row();
    final record = (original['preparation_attempts'] as List).single as Map;
    original['preparation_attempts'] = [
      {...record, 'version': 99},
    ];
    final legacy = await File(
      '${sandbox.path}/legacy.prepared.mp4',
    ).writeAsBytes([10]);
    await storage.saveFeedbackUploadQueue([original]);
    await queue.processQueue();
    expect(await compressed.readAsBytes(), [3]);
    expect(await prepared.readAsBytes(), [4]);
    expect(await legacy.readAsBytes(), [10]);
    expect(storage.getFeedbackUploadQueue().single, original);
  });

  test('unknown sibling in owned journal vetoes reclamation', () async {
    final original = row();
    final journal = original['preparation_attempts'] as List;
    original['preparation_attempts'] = [
      ...journal,
      {'version': 99, 'future_address': _attempt},
    ];
    await storage.saveFeedbackUploadQueue([original]);

    await queue.processQueue();

    expect(await compressed.readAsBytes(), [3]);
    expect(await prepared.readAsBytes(), [4]);
    expect(storage.getFeedbackUploadQueue().single, original);
  });

  test(
    'quarantined same-scope operation collision vetoes reclamation',
    () async {
      await storage.cacheData('feedback_upload_queue', [
        row(),
        {...row(), 'format_version': 99},
      ]);

      await queue.processQueue();

      expect(await compressed.readAsBytes(), [3]);
      expect(await prepared.readAsBytes(), [4]);
      expect(storage.getCachedList('feedback_upload_queue'), hasLength(2));
    },
  );

  test('raw local file URIs veto cleanup like direct paths', () async {
    await storage.saveFeedbackUploadQueue([row()]);
    await storage.savePendingSyncActions([
      {
        ...storage.queueIdentity,
        'id': 'synthetic-pending',
        'type': 'future_format',
        'attachment': prepared.uri.toString(),
      },
    ]);
    await queue.processQueue();
    expect(await compressed.exists(), isFalse);
    expect(await prepared.readAsBytes(), [4]);
    expect(storage.getPendingSyncActions().single['id'], 'synthetic-pending');
  });

  test(
    'malformed local file URI vetoes cleanup without crashing the queue',
    () async {
      await storage.saveFeedbackUploadQueue([row()]);
      await storage.savePendingSyncActions([
        {
          ...storage.queueIdentity,
          'id': 'synthetic-pending',
          'attachment': '${prepared.uri}?unexpected=true',
        },
      ]);

      await queue.processQueue();

      expect(await prepared.readAsBytes(), [4]);
      expect(await source.readAsBytes(), [1, 2]);
      expect(storage.getPendingSyncActions(), hasLength(1));
    },
  );

  test('adopted cleanup preserves a live foreign raw alias', () async {
    final foreign = LocalStorage(
      currentSession: () =>
          const LocalAuthSession(uid: 'foreign', generation: 1),
      environment: 'foreign-environment',
    );
    await foreign.cacheData('progress_photo_upload_queue', [
      {'source_file_path': prepared.uri.toString(), 'journal_version': 9000},
    ]);
    await storage.saveFeedbackUploadQueue([receipt()]);

    await queue.processQueue();

    expect(await prepared.exists(), isTrue);
    expect(storage.getFeedbackUploadQueue().single['cleanup_pending'], isTrue);
    expect(foreign.getCachedList('progress_photo_upload_queue'), hasLength(1));
  });

  test('adopted cleanup refuses a conflicting duplicate attempt', () async {
    final original = receipt();
    final journal = original['preparation_attempts'] as List;
    original['preparation_attempts'] = [
      ...journal,
      {...journal.single as Map, 'prepared': 'removed'},
    ];
    await storage.saveFeedbackUploadQueue([original]);

    await queue.processQueue();

    expect(await prepared.exists(), isTrue);
    expect(
      storage.getFeedbackUploadQueue().single['preparation_attempts'],
      original['preparation_attempts'],
    );
  });

  test('noncanonical checkpoint cannot authorize adopted cleanup', () async {
    await Directory('${attemptDirectory.path}/alias').create();
    final alias = File('${attemptDirectory.path}/alias/../prepared.mp4');
    expect(await alias.readAsBytes(), [4]);
    await storage.saveFeedbackUploadQueue([
      {
        ...receipt(),
        'upload_checkpoint': {'prepared_path': alias.path},
      },
    ]);

    await queue.processQueue();

    expect(await prepared.exists(), isTrue);
    expect(storage.getFeedbackUploadQueue().single['cleanup_pending'], isTrue);
  });

  test('busy old completed receipt keeps the private cleanup retry', () async {
    await storage.saveFeedbackUploadQueue([receipt()]);
    maintenanceBusy = true;

    await queue.processQueue();

    expect(await prepared.exists(), isTrue);
    expect(storage.getFeedbackUploadQueue().single['cleanup_pending'], isTrue);
    expect(
      storage.getFeedbackUploadQueue().single['verified_upload_id'],
      'synthetic-receipt',
    );
    maintenanceBusy = false;
    await queue.processQueue();
    expect(await prepared.exists(), isFalse);
    expect(storage.getFeedbackUploadQueue().single['cleanup_pending'], isFalse);
  });

  test('queue refuses to import a private prepared file as source', () async {
    await expectLater(
      queue.enqueue(
        file: prepared,
        contentType: 'video/mp4',
        mediaType: 'VIDEO',
      ),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'compression_invalid_input',
        ),
      ),
    );
    expect(storage.getFeedbackUploadQueue(), isEmpty);
    expect(await prepared.readAsBytes(), [4]);
  });

  const knownComplete = '/uploads/sessions/known/complete';

  ApiClient fakeApi({bool knownMissing = false, List<String>? requests}) {
    final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(
            lease,
            isNull,
            reason: 'Lease covers preparation, not network',
          );
          requests?.add(options.path);
          if (knownMissing && options.path == knownComplete) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                  data: {'code': 'UPLOAD_OBJECT_MISSING'},
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: options.path == '/uploads/sessions'
                  ? {
                      'upload_id': 'synthetic',
                      'upload_url': 'https://storage.exom.test/synthetic',
                    }
                  : {'file_url': 'r2://synthetic'},
            ),
          );
        },
      ),
    );
    return api;
  }

  FeedbackUploadQueueService realQueue({
    bool knownMissing = false,
    List<String>? requests,
  }) {
    final transfer = Dio();
    transfer.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests?.add('transfer:${options.path}');
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    addTearDown(transfer.close);
    final service = FeedbackUploadQueueService(
      _Repository(
        FeedbackRemoteDataSourceImpl(
          fakeApi(knownMissing: knownMissing, requests: requests),
          transferClient: transfer,
        ),
      ),
      storage,
      offline,
      isAuthenticated: () => true,
      connectivityChanges: const Stream.empty(),
      applicationSupportDirectory: () async => sandbox,
    );
    addTearDown(service.dispose);
    return service;
  }

  test('resumed private checkpoint requires same-row adoption proof', () async {
    await storage.saveFeedbackUploadQueue([
      {
        ...row(status: 'queued'),
        'upload_checkpoint': {
          'phase': 'prepared',
          'prepared_path': prepared.path,
          'prepared_content_type': 'video/mp4',
          'prepared_bytes': 1,
        },
      },
    ]);

    await realQueue().processQueue();

    expect(
      storage.getFeedbackUploadQueue().single['verified_upload_id'],
      isNull,
    );
    expect(await source.readAsBytes(), [1, 2]);
    expect(await prepared.readAsBytes(), [4]);
  });

  Map<String, Object> knownCheckpoint() => {
    'upload_id': 'known',
    'phase': 'prepared',
    'prepared_path': prepared.path,
    'prepared_content_type': 'video/mp4',
    'prepared_bytes': 1,
  };

  for (final adopted in [false, true]) {
    test('known remote missing, private checkpoint adopted=$adopted', () async {
      await storage.saveFeedbackUploadQueue([
        {
          ...row(
            status: 'queued',
            preparedState: adopted ? 'adopted' : 'unadopted',
          ),
          'upload_checkpoint': knownCheckpoint(),
        },
      ]);
      final requests = <String>[];
      await realQueue(knownMissing: true, requests: requests).processQueue();

      final persisted = storage.getFeedbackUploadQueue().single;
      expect(events, contains('acquirePreparation'));
      expect(events, isNot(contains('planPreparation')));
      expect(events, isNot(contains('compress')));
      if (adopted) {
        expect(requests, [
          knownComplete,
          '/uploads/sessions',
          '/uploads/sessions/synthetic/complete',
        ]);
        expect(persisted['status'], 'completed');
        expect(await prepared.exists(), isFalse);
      } else {
        expect(requests, [knownComplete]);
        expect(persisted['verified_upload_id'], isNull);
        expect(await prepared.readAsBytes(), [4]);
        expect(await source.readAsBytes(), [1, 2]);
      }
    });
  }

  test(
    'conflict renewals, exhaustion and restart keep the adopted journal',
    () async {
      await compressed.delete();
      final attempt = Map<String, dynamic>.from(
        (row()['preparation_attempts'] as List).single as Map,
      );
      final journal = [
        {...attempt, 'compressed': 'removed', 'prepared': 'adopted'},
      ];
      await storage.saveFeedbackUploadQueue([
        {
          ...row(status: 'queued'),
          'preparation_attempts': journal,
          'upload_checkpoint': {
            'generation': 0,
            'phase': 'prepared',
            'prepared_path': prepared.path,
            'prepared_content_type': 'video/mp4',
            'prepared_bytes': 1,
          },
        },
      ]);
      final operations = <String>[];
      final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(lease, isNull, reason: 'Lease covers preparation only');
            expect(options.path, '/uploads/sessions');
            operations.add(
              (options.data as Map)['client_operation_id'] as String,
            );
            handler.reject(
              DioException.badResponse(
                statusCode: 409,
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 409,
                  data: {'code': 'UPLOAD_OPERATION_CONFLICT'},
                ),
              ),
            );
          },
        ),
      );
      FeedbackUploadQueueService start() {
        final service = FeedbackUploadQueueService(
          _Repository(FeedbackRemoteDataSourceImpl(api)),
          storage,
          offline,
          isAuthenticated: () => true,
          connectivityChanges: const Stream.empty(),
          applicationSupportDirectory: () async => sandbox,
        );
        addTearDown(service.dispose);
        return service;
      }

      final first = start();
      await first.processQueue();
      final renewed = storage.getFeedbackUploadQueue().single;
      expect(renewed['status'], 'queued');
      expect(renewed['preparation_attempts'], journal);
      await storage.saveFeedbackUploadQueue([
        Map<String, dynamic>.from(renewed)..remove('next_attempt_at'),
      ]);
      await first.processQueue();
      final exhausted = storage.getFeedbackUploadQueue().single;
      expect(exhausted['status'], 'failed');
      expect(exhausted['last_error'], 'upload_operation_conflict_exhausted');

      // Process restart: a new runner sweeps with the maintenance lease.
      await start().processQueue();
      final persisted = storage.getFeedbackUploadQueue().single;
      expect(persisted['preparation_attempts'], journal);
      expect(
        (persisted['upload_checkpoint'] as Map)['prepared_path'],
        prepared.path,
      );
      expect(operations, [
        '$_operation:0',
        '$_operation:1',
        '$_operation:2',
        '$_operation:3',
      ]);
      expect(events, contains('acquireMaintenance'));
      expect(events, isNot(contains('planPreparation')));
      expect(events, isNot(contains('compress')));
      expect(await source.readAsBytes(), [1, 2]);
      expect(await prepared.readAsBytes(), [4]);
    },
  );

  for (final verified in [false, true]) {
    test(
      'remote confirmation with ambiguous private path, verified=$verified',
      () async {
        await storage.saveFeedbackUploadQueue([
          {
            ...row(status: 'queued'),
            'upload_checkpoint': knownCheckpoint(),
            if (verified) 'verified_upload_id': 'known',
            if (verified) 'verified_file_url': 'r2://known',
          },
        ]);
        final requests = <String>[];
        await realQueue(requests: requests).processQueue();

        final persisted = storage.getFeedbackUploadQueue().single;
        expect(requests, verified ? isEmpty : [knownComplete]);
        expect(events, isNot(contains('acquirePreparation')));
        expect(persisted['status'], 'completed');
        expect(persisted['verified_upload_id'], 'known');
        expect(persisted['cleanup_pending'], isTrue);
        expect(await prepared.readAsBytes(), [4]);
      },
    );
  }

  test(
    'checkpoint commits then throws: adopted file survives idle cleanup',
    () async {
      final queued = row(status: 'queued')..remove('preparation_attempts');
      await storage.saveFeedbackUploadQueue([queued]);
      storage.throwAfterPreparedSave = true;
      await realQueue().processQueue();
      final persisted = storage.getFeedbackUploadQueue().single;
      final checkpoint = persisted['upload_checkpoint'] as Map;
      final journal = persisted['preparation_attempts'] as List;
      final adopted = journal.single as Map;
      expect(checkpoint['phase'], 'prepared');
      expect(adopted['prepared'], 'adopted');
      expect(adopted['compressed'], 'removed');
      expect(await File(checkpoint['prepared_path'] as String).readAsBytes(), [
        3,
        4,
        5,
        6,
      ]);
      expect(await File('${planned!.path}/compressed.mp4').exists(), isFalse);
      expect(await source.readAsBytes(), [1, 2]);
    },
  );

  test(
    'lost adoption acknowledgement retains the unreferenced prepared copy',
    () async {
      final queued = row(status: 'queued')..remove('preparation_attempts');
      await storage.saveFeedbackUploadQueue([
        {
          ...queued,
          'training_id': 'synthetic-training',
          'training_session_id': 'synthetic-session',
          'assignment_date': '2026-11-05',
        },
      ]);
      storage.throwAfterAdoption = true;
      await realQueue().processQueue();

      final persisted = storage.getFeedbackUploadQueue().single;
      expect(persisted['upload_checkpoint'], isNull);
      expect(
        (persisted['preparation_attempts'] as List).single['prepared'],
        'adopted',
      );
      final retained = File('${planned!.path}/prepared.mp4');
      expect(await retained.readAsBytes(), [3, 4, 5, 6]);
      expect(await File('${planned!.path}/compressed.mp4').exists(), isFalse);

      await queue.discard(_operation);
      expect(await retained.readAsBytes(), [3, 4, 5, 6]);
      expect(
        await source.exists(),
        isFalse,
        reason: 'Source was explicitly discarded',
      );
      expect(
        storage.getFeedbackUploadQueue().single['discard_cleanup_complete'],
        isTrue,
      );
      expect(queue.pendingItems, isEmpty);
      expect(
        offline.hasPendingFeedbackForTraining(
          'synthetic-training',
          '2026-11-05',
        ),
        isFalse,
      );
      expect(
        storage.getFeedbackUploadQueue().single['training_session_id'],
        isNull,
      );
    },
  );

  test(
    'guard after copy prevents publication and permits idle cleanup',
    () async {
      final original = row()..remove('preparation_attempts');
      await storage.saveFeedbackUploadQueue([original]);
      await expectLater(
        FeedbackRemoteDataSourceImpl(fakeApi()).uploadMedia(
          source,
          'video/mp4',
          context: FeedbackUploadContext(
            operationId: _operation,
            checkpoint: const {},
            isCurrent: () =>
                planned == null ||
                !File('${planned!.path}/prepared.mp4').existsSync(),
            saveCheckpoint: (_) async =>
                fail('Stale preparation was published'),
            preparationIdentity: (owner: _owner, environment: _environment),
            recordPreparation: (attempt) async {
              await storage.saveFeedbackUploadQueue([
                {
                  ...original,
                  'preparation_attempts': [attempt.record],
                },
              ]);
            },
            adoptPreparation: (_) async =>
                fail('Stale preparation was adopted'),
          ),
        ),
        throwsA(isA<DioException>()),
      );
      final copy = File('${planned!.path}/prepared.mp4');
      expect(await copy.readAsBytes(), [3, 4, 5, 6]);
      await queue.processQueue();
      expect(await copy.exists(), isFalse);
      expect(await source.readAsBytes(), [1, 2]);
    },
  );

  test(
    'missing row cannot acknowledge intent or create reserved files',
    () async {
      final queued = row(status: 'queued')..remove('preparation_attempts');
      await storage.saveFeedbackUploadQueue([queued]);
      onPlan = () => storage.saveFeedbackUploadQueue([]);

      await realQueue().processQueue();

      expect(events, contains('planPreparation'));
      expect(events, isNot(contains('openPreparation')));
      expect(events, isNot(contains('compress')));
      expect(await planned!.exists(), isFalse);
      expect(await source.readAsBytes(), [1, 2]);
    },
  );

  test('owned image uses bytes, then adopts its Dart-written JPEG', () async {
    final queued = row(status: 'queued')..remove('preparation_attempts');
    await storage.saveFeedbackUploadQueue([
      {...queued, 'content_type': 'image/png', 'media_type': 'IMAGE'},
    ]);
    var calls = 0;
    final platform = FlutterImageCompressPlatform.instance;
    FlutterImageCompressPlatform.instance = _ImagePlatform(() {
      calls++;
      expect(lease, 'preparation');
      return Uint8List.fromList([5, 6, 7]);
    });
    addTearDown(() => FlutterImageCompressPlatform.instance = platform);
    storage.throwAfterPreparedSave = true;
    await realQueue().processQueue();

    expect(calls, 1);
    final persisted = storage.getFeedbackUploadQueue().single;
    final adopted = (persisted['preparation_attempts'] as List).single as Map;
    expect(adopted['prepared'], 'adopted');
    expect(adopted.containsKey('compressed'), isFalse);
    final checkpoint = persisted['upload_checkpoint'] as Map;
    expect(checkpoint['prepared_content_type'], 'image/jpeg');
    expect(await File(checkpoint['prepared_path'] as String).readAsBytes(), [
      5,
      6,
      7,
    ]);
    expect(await source.readAsBytes(), [1, 2]);
  });

  test(
    'M2 re-prepares with a fresh lease and preserves the owned source until receipt',
    () async {
      final queued = row(status: 'queued')..remove('preparation_attempts');
      await storage.saveFeedbackUploadQueue([
        {
          ...queued,
          'upload_checkpoint': {
            'phase': 'prepared',
            'generation': 2,
            'session_attempted': true,
            'prepared_bytes': 99,
            'prepared_content_type': 'video/mp4',
          },
        },
      ]);
      await realQueue().processQueue();
      final persisted = storage.getFeedbackUploadQueue().single;
      expect(persisted['status'], 'completed');
      expect((persisted['upload_checkpoint'] as Map)['generation'], 3);
      expect(events.where((event) => event == 'planPreparation'), hasLength(2));
      expect(
        events.where((event) => event == 'acquirePreparation'),
        hasLength(2),
      );
      expect(
        (persisted['preparation_attempts'] as List).single['prepared'],
        'adopted',
      );
      expect(
        await source.exists(),
        isFalse,
        reason: 'Confirmed cleanup can now delete source',
      );
    },
  );

  test(
    'direct feedback uses exclusion without a queue-owned reservation',
    () async {
      await FeedbackRemoteDataSourceImpl(
        fakeApi(),
      ).uploadMedia(source, 'video/mp4');
      expect(events, [
        'acquirePreparation',
        'compress',
        'releasePreparationLease',
      ]);
      expect(await source.readAsBytes(), [1, 2]);
      expect(await File('${source.path}.prepared.mp4').readAsBytes(), [
        3,
        4,
        5,
        6,
      ]);
      expect(storage.getFeedbackUploadQueue(), isEmpty);
    },
  );
}
