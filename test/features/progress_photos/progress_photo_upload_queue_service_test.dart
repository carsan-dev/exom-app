import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';
import 'package:exom_app/features/progress_photos/domain/repositories/progress_photo_repository.dart';
import 'package:exom_app/features/progress_photos/services/progress_photo_upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File selected;
  late PhotoStorage storage;
  late FakePhotoRepository repository;
  late bool authenticated;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-progress-photo-');
    selected = await File('${directory.path}/selected.jpg').writeAsBytes([1, 2]);
    storage = PhotoStorage(const LocalAuthSession(uid: 'A', generation: 1));
    repository = FakePhotoRepository();
    authenticated = true;
  });
  tearDown(() => directory.delete(recursive: true));

  ProgressPhotoUploadQueueService service({
    Future<void> Function(String)? deleteFile,
    Future<File> Function(File source, File staging)? copyToStaging,
    Future<void> Function(ProgressPhotoEnqueueStage stage)? enqueueStage,
    Stream<bool>? connectivityChanges,
  }) => ProgressPhotoUploadQueueService(
    repository,
    storage,
    isAuthenticated: () => authenticated,
    applicationSupportDirectory: () async => directory,
    deleteFile: deleteFile,
    copyToStaging: copyToStaging,
    enqueueStage: enqueueStage,
    connectivityChanges: connectivityChanges,
  );

  Future<String> enqueue(ProgressPhotoUploadQueueService queue, {String? replacement}) async {
    // Enqueue always schedules work. Pause only during test setup so each case
    // controls its exact close/restart boundary.
    final wasAuthenticated = authenticated;
    authenticated = false;
    final id = await queue.enqueue(
      file: selected,
      civilSessionDate: '2026-09-16',
      canonicalView: 'FRONT',
      contentType: 'image/jpeg',
      replacesPhotoId: replacement,
    );
    await Future<void>.delayed(Duration.zero);
    authenticated = wasAuthenticated;
    return id;
  }

  test('close before transfer retains an owned copy and complete durable intent', () async {
    authenticated = false;
    final queue = service();
    final id = await enqueue(queue);
    final entry = storage.all.single;
    expect(entry['id'], id);
    expect(await File(entry['file_path'] as String).exists(), isTrue);
    expect(entry['format_version'], 1);
    expect(entry['owner_id'], 'A');
    expect(entry['environment'], 'test');
    expect(entry['session_operation_id'], isNotEmpty);
    expect(entry['upload_operation_id'], isNotEmpty);
    expect(entry['association_operation_id'], isNotEmpty);
    expect(entry['session_checkpoint'], {'state': 'pending'});
    expect(entry['association_checkpoint'], {'state': 'pending'});
    expect(repository.uploadCalls, 0);
  });

  test('pre-copy source loss retains a durable owner-scoped recovery record', () async {
    final queue = service(
      enqueueStage: (stage) async {
        if (stage == ProgressPhotoEnqueueStage.beforeCopy) {
          await selected.delete();
        }
      },
    );

    await expectLater(
      queue.enqueue(
        file: selected,
        civilSessionDate: '2026-09-16',
        canonicalView: 'FRONT',
        contentType: 'image/jpeg',
      ),
      throwsA(isA<StateError>()),
    );

    final entry = storage.all.single;
    expect(entry['status'], 'failed');
    expect(entry['last_error'], 'progress_photo_source_unavailable');
    expect(entry['owner_id'], 'A');
    expect(entry['environment'], 'test');
    expect(entry['format_version'], 1);
    expect(entry['staging_file_path'], isNotEmpty);
    expect(entry['file_path'], isNotEmpty);
    expect(await File(entry['staging_file_path'] as String).exists(), isFalse);
    expect(await File(entry['file_path'] as String).exists(), isFalse);
  });

  test('partial-copy interruption remains indexed and startup replaces it atomically', () async {
    final queue = service(
      copyToStaging: (source, staging) async {
        await staging.writeAsBytes([1]);
        throw StateError('crash during copy');
      },
    );

    await expectLater(enqueue(queue), throwsA(isA<StateError>()));
    final interrupted = storage.all.single;
    expect(interrupted['status'], 'staging');
    expect(await File(interrupted['staging_file_path'] as String).exists(), isTrue);
    expect(await File(interrupted['file_path'] as String).exists(), isFalse);

    final recovered = service();
    await recovered.processQueue();
    final entry = storage.all.single;
    expect(entry['status'], 'queued');
    expect(await File(entry['staging_file_path'] as String).exists(), isFalse);
    expect(await File(entry['file_path'] as String).exists(), isTrue);
  });

  test('rename-before-promotion crash promotes the indexed final file at startup', () async {
    final queue = service(
      enqueueStage: (stage) async {
        if (stage == ProgressPhotoEnqueueStage.afterRename) {
          throw StateError('crash after rename');
        }
      },
    );

    await expectLater(enqueue(queue), throwsA(isA<StateError>()));
    final interrupted = storage.all.single;
    expect(interrupted['status'], 'staging');
    expect(await File(interrupted['staging_file_path'] as String).exists(), isFalse);
    expect(await File(interrupted['file_path'] as String).exists(), isTrue);

    await service().processQueue();
    expect(storage.all.single['status'], 'queued');
  });

  test('switch after journal persistence fails enqueue without losing A recovery record', () async {
    storage.onSaveProgressPhotoQueue = (queue) {
      if (queue.single['status'] == 'staging') {
        scheduleMicrotask(() {
          storage.current = const LocalAuthSession(uid: 'B', generation: 2);
        });
      }
    };

    await expectLater(
      service().enqueue(
        file: selected,
        civilSessionDate: '2026-09-16',
        canonicalView: 'FRONT',
        contentType: 'image/jpeg',
      ),
      throwsA(isA<LocalSessionChanged>()),
    );

    final aEntry = storage.all.single;
    expect(aEntry['owner_id'], 'A');
    expect(aEntry['status'], 'staging');
    expect(await File(aEntry['file_path'] as String).exists(), isFalse);

    storage.onSaveProgressPhotoQueue = null;
    authenticated = false;
    storage.current = const LocalAuthSession(uid: 'A', generation: 3);
    await service().processQueue();
    expect(storage.all.single['status'], 'queued');
  });

  test('startup reconciliation stops before file mutation after a session switch', () async {
    final queue = service();
    await enqueue(queue);
    final entry = storage.all.single;
    entry['status'] = 'staging';
    entry['staging_checkpoint'] = {'state': 'intent'};
    storage.progressPhotoQueueReadCount = 0;
    storage.switchSessionAfterProgressPhotoQueueRead = 2;

    await queue.processQueue();

    expect(storage.current!.uid, 'B');
    expect(storage.all.single['owner_id'], 'A');
    expect(storage.all.single['status'], 'staging');
    expect(await File(entry['file_path'] as String).exists(), isTrue);
  });

  test('cleanup interruption remains retryable without another association', () async {
    var switchOnce = true;
    final queue = service(
      deleteFile: (path) async {
        if (switchOnce) {
          storage.current = const LocalAuthSession(uid: 'B', generation: 2);
          switchOnce = false;
        }
        final file = File(path);
        if (await file.exists()) await file.delete();
      },
    );
    await enqueue(queue);

    await queue.processQueue();

    final interrupted = storage.all.single;
    expect(interrupted['status'], 'completed');
    expect(interrupted['cleanup_pending'], isTrue);
    expect(interrupted['cleanup_checkpoint'], {'state': 'deleting'});
    expect(repository.associateCalls, 1);

    storage.current = const LocalAuthSession(uid: 'A', generation: 3);
    await queue.processQueue();
    expect(storage.all.single['cleanup_pending'], isFalse);
    expect(repository.associateCalls, 1);
  });

  test('session switch during staging never lets B claim A evidence and A resumes it', () async {
    final queue = service(
      enqueueStage: (stage) async {
        if (stage == ProgressPhotoEnqueueStage.beforeCopy) {
          storage.current = const LocalAuthSession(uid: 'B', generation: 2);
        }
      },
    );

    await expectLater(enqueue(queue), throwsA(isA<LocalSessionChanged>()));
    final aEntry = storage.all.single;
    expect(aEntry['owner_id'], 'A');
    expect(aEntry['status'], 'staging');
    expect(storage.getProgressPhotoUploadQueue(), isEmpty);
    expect(await File(aEntry['file_path'] as String).exists(), isFalse);

    storage.current = const LocalAuthSession(uid: 'A', generation: 3);
    await service().processQueue();
    expect(storage.all.single['status'], 'queued');
    expect(await File(aEntry['file_path'] as String).exists(), isTrue);
  });

  test('startup resets interrupted transfer and reuses all stable identities', () async {
    final queue = service();
    await enqueue(queue);
    storage.all.single['status'] = 'processing';
    final ids = stableIds(storage.all.single);
    await queue.processQueue();
    expect(repository.createCalls, 1);
    expect(repository.uploadCalls, 1);
    expect(repository.associateCalls, 1);
    expect(stableIds(storage.all.single), ids);
    expect(storage.all.single['status'], 'completed');
  });

  test('lost upload completion response retries the same upload rather than a new object', () async {
    repository.loseUploadResponseOnce = true;
    final queue = service();
    await enqueue(queue);
    await queue.processQueue();
    final first = storage.all.single;
    expect(first['status'], 'queued');
    final ids = stableIds(first);
    first.remove('next_attempt_at');
    await queue.processQueue();
    expect(repository.createdUploads, hasLength(1));
    expect(repository.associateCalls, 1);
    expect(stableIds(storage.all.single), ids);
  });

  test('lost association response replays the same association without another upload', () async {
    repository.loseAssociationResponseOnce = true;
    final queue = service();
    await enqueue(queue);
    await queue.processQueue();
    storage.all.single.remove('next_attempt_at');
    await queue.processQueue();
    expect(repository.createdUploads, hasLength(1));
    expect(repository.createdAssociations, hasLength(1));
    expect(storage.all.single['association_checkpoint']['state'], 'confirmed');
  });

  test('disconnect leaves local evidence queued and ordinary retry completes it', () async {
    repository.uploadError = offlineError();
    final queue = service();
    await enqueue(queue);
    await queue.processQueue();
    expect(storage.all.single['status'], 'queued');
    expect(await File(storage.all.single['file_path'] as String).exists(), isTrue);
    repository.uploadError = null;
    await queue.retry(storage.all.single['id'] as String);
    expect(storage.all.single['status'], 'completed');
  });

  test('A to B to A quarantines A work and resumes it only for A', () async {
    authenticated = false;
    final queue = service();
    await enqueue(queue);
    final aPath = storage.all.single['file_path'] as String;
    storage.current = const LocalAuthSession(uid: 'B', generation: 2);
    authenticated = true;
    await queue.processQueue();
    expect(repository.uploadCalls, 0);
    expect(storage.getProgressPhotoUploadQueue(), isEmpty);
    expect(await File(aPath).exists(), isTrue);
    storage.current = const LocalAuthSession(uid: 'A', generation: 3);
    await queue.processQueue();
    expect(repository.associateCalls, 1);
    expect(storage.all.single['status'], 'completed');
  });

  test('session generation change during a response retains data and applies no stale result', () async {
    repository.blockUpload = true;
    final queue = service();
    await enqueue(queue);
    final run = queue.processQueue();
    await repository.uploadStarted.future;
    storage.current = const LocalAuthSession(uid: 'A', generation: 2);
    repository.releaseUpload.complete();
    await run;
    expect(repository.associateCalls, 0);
    expect(storage.all.single['status'], 'processing');
    expect(await File(storage.all.single['file_path'] as String).exists(), isTrue);
  });

  test('explicit replacement persists and sends its precondition exactly', () async {
    final queue = service();
    await enqueue(queue, replacement: 'active-photo');
    await queue.processQueue();
    expect(repository.lastReplacement, 'active-photo');
    expect(storage.all.single['replaces_photo_id'], 'active-photo');
  });

  test('several incomplete sessions retain independent session operations', () async {
    final queue = service();
    await enqueue(queue);
    await enqueue(queue);
    await queue.processQueue();
    expect(repository.createdSessions, hasLength(2));
    expect(repository.createdAssociations, hasLength(2));
    expect(storage.all.map((entry) => entry['session_id']).toSet(), hasLength(2));
  });

  test('cleanup failure is retryable and never repeats remote association', () async {
    var deleteCalls = 0;
    final queue = service(deleteFile: (_) async {
      if (deleteCalls++ == 0) throw const FileSystemException('locked');
    });
    await enqueue(queue);
    await queue.processQueue();
    expect(storage.all.single['status'], 'completed');
    expect(storage.all.single['cleanup_pending'], isTrue);
    expect(repository.associateCalls, 1);
    await queue.processQueue();
    expect(storage.all.single['cleanup_pending'], isFalse);
    expect(repository.associateCalls, 1);
  });

  test('never deletes evidence before the remote association is durably confirmed', () async {
    repository.associationError = offlineError();
    var deletes = 0;
    final queue = service(deleteFile: (_) async => deletes++);
    await enqueue(queue);
    await queue.processQueue();
    expect(storage.all.single['status'], 'queued');
    expect(deletes, 0);
    expect(storage.all.single['association_checkpoint']['state'], 'associating');
  });

  test('reconnect accelerates only offline failures and retains server backoff', () async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    final queued = <String, dynamic>{
      'file_path': selected.path,
      'content_type': 'image/jpeg',
      'bytes': 2,
      'civil_session_date': '2026-09-16',
      'view': 'FRONT',
      'session_operation_id': 'session-operation',
      'upload_operation_id': 'upload-operation',
      'association_operation_id': 'association-operation',
      ...storage.progressPhotoQueueIdentity,
      'status': 'queued',
      'attempts': 1,
      'next_attempt_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      'upload_checkpoint': const <String, dynamic>{},
      'association_checkpoint': const <String, dynamic>{'state': 'pending'},
      'cleanup_checkpoint': const <String, dynamic>{'state': 'pending'},
    };
    storage.all = [
      {...queued, 'id': 'offline', 'last_error': 'progress_photo_network_connectionError_0'},
      {...queued, 'id': 'timeout', 'last_error': 'progress_photo_network_receiveTimeout_0'},
      {...queued, 'id': 'limited', 'last_error': 'progress_photo_http_429'},
      {...queued, 'id': 'server', 'last_error': 'progress_photo_http_503'},
    ];
    final queue = service(
      connectivityChanges: connectivity.stream,
      deleteFile: (_) async {},
    );
    addTearDown(queue.dispose);
    await queue.init();
    connectivity
      ..add(false)
      ..add(true);
    await waitUntil(
      () => storage.all.take(2).every((item) => item['status'] == 'completed'),
    );

    expect(repository.uploadCalls, 2);
    expect(storage.all[2]['next_attempt_at'], queued['next_attempt_at']);
    expect(storage.all[3]['next_attempt_at'], queued['next_attempt_at']);
  });
}

Map<String, Object?> stableIds(Map<String, dynamic> entry) => {
  'session': entry['session_operation_id'],
  'upload': entry['upload_operation_id'],
  'association': entry['association_operation_id'],
};

DioException offlineError() => DioException.connectionError(
  requestOptions: RequestOptions(path: '/progress-photos'),
  reason: 'offline',
);

Future<void> waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not reached');
}

class PhotoStorage extends LocalStorage {
  PhotoStorage(this.current) : super(environment: 'test');

  LocalAuthSession? current;
  List<Map<String, dynamic>> all = [];
  void Function(List<Map<String, dynamic>> queue)? onSaveProgressPhotoQueue;
  int progressPhotoQueueReadCount = 0;
  int? switchSessionAfterProgressPhotoQueueRead;

  @override
  String? get ownerId => current?.uid;
  @override
  String? get sessionStamp => current == null
      ? null
      : '${current!.uid}:${current!.generation}:$environment';
  @override
  Map<String, Object?> get progressPhotoQueueIdentity => {
    'format_version': 1,
    'owner_id': current?.uid,
    'environment': environment,
  };
  @override
  bool ownsProgressPhotoQueueEntry(Map<String, dynamic> item) =>
      current != null &&
      item['owner_id'] == current!.uid &&
      item['environment'] == environment &&
      item['format_version'] == 1;
  @override
  List<Map<String, dynamic>> getProgressPhotoUploadQueue() {
    progressPhotoQueueReadCount++;
    if (progressPhotoQueueReadCount == switchSessionAfterProgressPhotoQueueRead) {
      scheduleMicrotask(() {
        current = const LocalAuthSession(uid: 'B', generation: 2);
      });
    }
    return all
        .where(ownsProgressPhotoQueueEntry)
        .map(Map<String, dynamic>.from)
        .toList();
  }

  @override
  Future<void> saveProgressPhotoUploadQueue(List<Map<String, dynamic>> value) async {
    onSaveProgressPhotoQueue?.call(value);
    all = [...all.where((entry) => !ownsProgressPhotoQueueEntry(entry)), ...value]
        .map(Map<String, dynamic>.from)
        .toList();
  }
  @override
  Future<void> withSession(Future<void> Function() action) async {
    if (current == null) return;
    try {
      await action();
    } on LocalSessionChanged {
      // Matches production LocalStorage: stale work stays durable.
    }
  }
}

class FakePhotoRepository implements ProgressPhotoRepository {
  int createCalls = 0;
  int uploadCalls = 0;
  int associateCalls = 0;
  bool loseUploadResponseOnce = false;
  bool loseAssociationResponseOnce = false;
  bool blockUpload = false;
  Object? uploadError;
  Object? associationError;
  String? lastReplacement;
  final Map<String, String> createdSessions = {};
  final Map<String, String> createdUploads = {};
  final Map<String, String> createdAssociations = {};
  final uploadStarted = Completer<void>();
  final releaseUpload = Completer<void>();

  @override
  Future<ProgressPhotoSession> createSession({required String civilDate, required String operationId}) async {
    createCalls++;
    final id = createdSessions.putIfAbsent(operationId, () => 'session-${createdSessions.length + 1}');
    return ProgressPhotoSession(id: id, sessionDate: civilDate, isComplete: false, photos: const []);
  }

  @override
  Future<ManagedUploadResult> uploadPhoto(File file, String contentType, {required ManagedUploadContext context}) async {
    uploadCalls++;
    if (blockUpload) {
      uploadStarted.complete();
      await releaseUpload.future;
    }
    if (uploadError case final error?) throw error;
    final id = createdUploads.putIfAbsent(context.operationId, () => 'upload-${createdUploads.length + 1}');
    await context.saveCheckpoint({'upload_id': id, 'phase': 'completion_confirmed'});
    if (loseUploadResponseOnce) {
      loseUploadResponseOnce = false;
      throw offlineError();
    }
    return ManagedUploadResult(uploadId: id, fileUrl: 'r2://$id');
  }

  @override
  Future<ProgressPhoto> associatePhoto({
    required String sessionId,
    required String uploadId,
    required String view,
    required String operationId,
    String? replacesPhotoId,
  }) async {
    associateCalls++;
    lastReplacement = replacesPhotoId;
    if (associationError case final error?) throw error;
    final id = createdAssociations.putIfAbsent(operationId, () => 'photo-${createdAssociations.length + 1}');
    if (loseAssociationResponseOnce) {
      loseAssociationResponseOnce = false;
      throw offlineError();
    }
    return ProgressPhoto(id: id, view: view, imageUrl: 'r2://$uploadId');
  }

  @override
  Future<List<ProgressPhotoSession>> getHistory({int page = 1, int limit = 20}) async => const [];
}
