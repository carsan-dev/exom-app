import 'dart:convert';
import 'dart:io';

import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_upload_queue_service_test.dart'
    show
        FakeFeedbackQueueStorage,
        FakeFeedbackRepository,
        FakeOfflineSyncService;

void main() {
  for (final code in [
    'compression_timeout',
    'compression_busy',
    'compression_cancelled',
    'compression_failed',
    'compression_invalid_input',
    'compression_unknown',
  ]) {
    final retryable = const [
      'compression_timeout',
      'compression_busy',
      'compression_cancelled',
    ].contains(code);
    test(
      '$code retains source and retries only known transient failures',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'exom-timeout-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = await File(
          '${directory.path}/source.mov',
        ).writeAsBytes([1, 2, 3]);
        final storage = FakeFeedbackQueueStorage([
          {
            'id': 'stable',
            'status': 'queued',
            'attempts': 0,
            'file_path': file.path,
            'content_type': 'video/quicktime',
            'media_type': 'VIDEO',
            'training_session_id': 'execution-one',
          },
        ]);
        final repository = FakeFeedbackRepository(
          uploadError: PlatformException(code: code),
        );
        final offline = FakeOfflineSyncService(storage);
        final queue = FeedbackUploadQueueService(
          repository,
          storage,
          offline,
          isAuthenticated: () => true,
          connectivityChanges: const Stream.empty(),
        );
        addTearDown(queue.dispose);
        addTearDown(offline.dispose);
        await queue.processQueue();
        final item = storage.queue.single;
        expect(item['status'], retryable ? 'queued' : 'failed');
        expect(item['next_attempt_at'] != null, retryable);
        expect(item['training_session_id'], 'execution-one');
        expect(repository.createCalls, 0);
        expect(await file.readAsBytes(), [1, 2, 3]);
        if (retryable) {
          expect(item['last_error'], code);
          expect(
            DateTime.parse(
              item['next_attempt_at'] as String,
            ).isAfter(DateTime.now()),
            isTrue,
          );
        }
        await queue.processQueue();
        expect(repository.uploadCalls, 1, reason: 'No immediate retry loop');
      },
    );
  }

  for (final code in ['compression_busy', 'compression_cancelled']) {
    test(
      '$code resumes after reload and backoff with unchanged identity',
      () async {
        final directory = await Directory.systemTemp.createTemp('exom-retry-');
        addTearDown(() => directory.delete(recursive: true));
        final file = await File(
          '${directory.path}/source.mov',
        ).writeAsBytes([1, 2, 3]);
        final original = <String, dynamic>{
          'id': 'stable',
          'status': 'queued',
          'attempts': 0,
          'file_path': file.path,
          'content_type': 'video/quicktime',
          'media_type': 'VIDEO',
          'owner_id': 'A',
          'training_session_id': 'execution-one',
          'upload_checkpoint': {'generation': 3, 'phase': 'preparing'},
        };
        final storage = FakeFeedbackQueueStorage([original]);
        final offline = FakeOfflineSyncService(storage);
        addTearDown(offline.dispose);
        final queue = FeedbackUploadQueueService(
          FakeFeedbackRepository(uploadError: PlatformException(code: code)),
          storage,
          offline,
          isAuthenticated: () => true,
          connectivityChanges: const Stream.empty(),
        );
        await queue.processQueue();
        await queue.dispose();
        final persisted = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(storage.queue.single)) as Map,
        );
        expect(persisted['status'], 'queued');
        for (final key in original.keys.where(
          (key) => key != 'status' && key != 'attempts',
        )) {
          expect(
            persisted[key],
            original[key],
            reason: '$key survives interruption',
          );
        }
        final reloaded = FakeFeedbackQueueStorage([persisted]);
        final reloadedOffline = FakeOfflineSyncService(reloaded);
        addTearDown(reloadedOffline.dispose);
        final repository = _RecordingRepository();
        var authenticated = true;
        final resumed = FeedbackUploadQueueService(
          repository,
          reloaded,
          reloadedOffline,
          isAuthenticated: () => authenticated,
          connectivityChanges: const Stream.empty(),
          deleteFile: (path) async {
            expect(repository.createCalls, 1);
            expect(reloaded.queue.single['status'], 'completed');
            await File(path).delete();
          },
        );
        addTearDown(resumed.dispose);
        await resumed.processQueue();
        expect(repository.uploadCalls, 0, reason: 'Reload preserves backoff');
        reloaded.queue.single['next_attempt_at'] = DateTime.utc(
          2000,
        ).toIso8601String();
        authenticated = false;
        await resumed.processQueue();
        expect(
          repository.uploadCalls,
          0,
          reason: 'Due work waits for authentication',
        );
        expect(await file.readAsBytes(), [1, 2, 3]);
        authenticated = true;
        await resumed.processQueue();
        expect(repository.uploadCalls, 1);
        expect(repository.createCalls, 1);
        expect(repository.contexts.single.operationId, 'stable');
        expect(
          repository.contexts.single.checkpoint,
          original['upload_checkpoint'],
        );
        expect(repository.createdSessionId, 'execution-one');
        expect(reloaded.queue.single['status'], 'completed');
        await resumed.processQueue();
        expect(repository.uploadCalls, 1);
        expect(repository.createCalls, 1);
      },
    );

    test(
      '$code cannot apply an old session failure to another owner',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'exom-owner-retry-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = await File(
          '${directory.path}/source.mov',
        ).writeAsBytes([1, 2, 3]);
        final storage = _OwnedStorage([
          {
            'id': 'stable',
            'owner_id': 'A',
            'status': 'queued',
            'attempts': 0,
            'file_path': file.path,
            'content_type': 'video/quicktime',
            'media_type': 'VIDEO',
          },
        ]);
        final repository = _RecordingRepository(
          uploadError: PlatformException(code: code),
          beforeUpload: () => storage.session = 'B:2:test',
        );
        final offline = FakeOfflineSyncService(storage);
        addTearDown(offline.dispose);
        final queue = FeedbackUploadQueueService(
          repository,
          storage,
          offline,
          isAuthenticated: () => true,
          connectivityChanges: const Stream.empty(),
        );
        addTearDown(queue.dispose);
        await queue.processQueue();
        expect(repository.contexts.single.isCurrent(), isFalse);
        expect(storage.queue.single['status'], 'uploading');
        expect(storage.queue.single['last_error'], isNull);
        await queue.processQueue();
        expect(repository.uploadCalls, 1);
        expect(repository.createCalls, 0);
        expect(storage.queue.single['status'], 'uploading');
        expect(await file.readAsBytes(), [1, 2, 3]);
      },
    );
  }

  test('explicit discard never becomes a compression retry', () async {
    final directory = await Directory.systemTemp.createTemp(
      'exom-discard-retry-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/source.mov').writeAsBytes([1]);
    final storage = FakeFeedbackQueueStorage([
      {
        'id': 'discarded',
        'status': 'queued',
        'discard_requested': true,
        'file_path': file.path,
        'last_error': 'compression_cancelled',
      },
    ]);
    final repository = FakeFeedbackRepository();
    final offline = FakeOfflineSyncService(storage);
    addTearDown(offline.dispose);
    final queue = FeedbackUploadQueueService(
      repository,
      storage,
      offline,
      isAuthenticated: () => true,
      connectivityChanges: const Stream.empty(),
    );
    addTearDown(queue.dispose);
    await queue.processQueue();
    expect(repository.uploadCalls, 0);
    expect(repository.createCalls, 0);
    expect(storage.queue, isEmpty);
    expect(offline.removedDependencies, ['discarded']);
  });
}

class _RecordingRepository extends FakeFeedbackRepository {
  _RecordingRepository({super.uploadError, this.beforeUpload});

  final void Function()? beforeUpload;
  final contexts = <FeedbackUploadContext>[];

  @override
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType, {
    FeedbackUploadContext? context,
  }) async {
    contexts.add(context!);
    beforeUpload?.call();
    return super.uploadMedia(file, contentType, context: context);
  }
}

class _OwnedStorage extends FakeFeedbackQueueStorage {
  _OwnedStorage(super.queue);

  String session = 'A:1:test';

  @override
  String get sessionStamp => session;

  @override
  bool ownsEntry(Map<String, dynamic> item) =>
      item['owner_id'] == session.split(':').first;

  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() =>
      super.getFeedbackUploadQueue().where(ownsEntry).toList();

  @override
  Future<void> saveFeedbackUploadQueue(List<Map<String, dynamic>> value) async {
    queue = [
      ...queue.where((item) => !ownsEntry(item)),
      ...value.map(Map<String, dynamic>.from),
    ];
  }
}
