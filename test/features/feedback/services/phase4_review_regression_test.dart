import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import '../../../core/services/offline_sync_service_test.dart';
import 'feedback_upload_queue_service_test.dart';

class BlockFirstSave extends FakeFeedbackQueueStorage {
  BlockFirstSave() : super([]);
  final entered = Completer<void>();
  final release = Completer<void>();
  bool blocked = false;
  @override
  Future<void> saveFeedbackUploadQueue(List<Map<String, dynamic>> value) async {
    if (!blocked) {
      blocked = true;
      entered.complete();
      await release.future;
    }
    await super.saveFeedbackUploadQueue(value);
  }
}

class FailingFollowUp extends FakeOfflineSyncService {
  FailingFollowUp(super.storage);
  @override
  Future<void> syncPendingActions() async {
    throw StateError('follow-up unavailable');
  }
}

class ConcurrentProgressReader extends FakeSyncStorage {
  bool overwrite = false;
  @override
  Future<void> cacheData(String key, dynamic value) async {
    await super.cacheData(key, value);
    if (overwrite && key.startsWith('completed_meals_')) {
      // A real GET can complete at this await boundary and update shared cache.
      cache['day_progress_2026-09-06'] = {
        'sync_revision': 99,
        'exercises_completed': [],
        'meals_completed': [],
      };
    }
  }
}

void main() {
  test(
    'review: recovering claims cannot overwrite an enqueue holding the queue mutex',
    () async {
      final dir = await Directory.systemTemp.createTemp('p4-review-enqueue-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/original.mp4').writeAsBytes([1]);
      final storage = BlockFirstSave();
      final queue = FeedbackUploadQueueService(
        FakeFeedbackRepository(),
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => false,
        applicationSupportDirectory: () => Future.value(dir),
      );
      final enqueue = queue.enqueue(
        file: file,
        contentType: 'video/mp4',
        mediaType: 'VIDEO',
      );
      await storage.entered.future;
      final recovery = queue.processQueue();
      await Future<void>.delayed(Duration.zero);
      storage.release.complete();
      final id = await enqueue;
      await recovery;
      await queue.processQueue();
      expect(storage.queue.map((item) => item['id']), contains(id));
      expect(
        await File(storage.queue.single['file_path'] as String).exists(),
        true,
      );
    },
  );
  test(
    'review: failure after durable feedback confirmation cannot regress completed',
    () async {
      final dir = await Directory.systemTemp.createTemp('p4-review-confirm-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/original.mp4').writeAsBytes([1]);
      final storage = FakeFeedbackQueueStorage([
        {
          'id': 'confirmed',
          'status': 'queued',
          'file_path': file.path,
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
        },
      ]);
      final repository = FakeFeedbackRepository();
      final queue = FeedbackUploadQueueService(
        repository,
        storage,
        FailingFollowUp(storage),
        isAuthenticated: () => true,
      );
      await queue.processQueue();
      expect(storage.queue.single['status'], 'completed');
      await queue.processQueue();
      expect(repository.createCalls, 1);
      expect(repository.uploadCalls, 1);
    },
  );
  test(
    'review: recoverable upload error emits queued status instead of leaving processing visible',
    () async {
      final dir = await Directory.systemTemp.createTemp('p4-review-progress-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/original.mp4').writeAsBytes([1]);
      final storage = FakeFeedbackQueueStorage([
        {
          'id': 'network',
          'status': 'queued',
          'file_path': file.path,
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
        },
      ]);
      final repository = FakeFeedbackRepository(
        uploadError: DioException.connectionError(
          requestOptions: RequestOptions(path: '/uploads/sessions'),
          reason: 'offline',
        ),
      );
      final queue = FeedbackUploadQueueService(
        repository,
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => true,
      );
      final notices = <FeedbackUploadNoticeKind>[];
      final subscription = queue.notices.listen(
        (notice) => notices.add(notice.kind),
      );
      await queue.processQueue();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(storage.queue.single['status'], 'queued');
      expect(notices.last, FeedbackUploadNoticeKind.queued);
    },
  );
  test(
    'review: a concurrent GET cannot replace a receipt revision used by an old successor',
    () async {
      final storage = ConcurrentProgressReader();
      final revisions = <Object?>[];
      final client = respondingClient((options, handler) {
        revisions.add(options.headers['x-exom-revision']);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'sync_revision': revisions.length,
              'operation_revision': revisions.length,
              'exercises_completed': [],
              'meals_completed': [],
            },
          ),
        );
      });
      final sync = OfflineSyncService(
        client,
        storage,
        isAuthenticated: () => true,
      );
      await sync.queueExerciseCompletion(
        'te',
        '2026-09-06',
        completed: true,
        exerciseId: 'e',
      );
      await sync.queueExerciseCompletion('te', '2026-09-06', completed: false);
      storage.overwrite = true;
      await sync.syncPendingActions();
      expect(revisions, [0, 1]);
    },
  );
  for (final malformed in [
    null,
    <String, dynamic>{'exercises_completed': []},
  ]) {
    test(
      'review: missing v2 receipt retains operation identity (response=$malformed)',
      () async {
        final storage = FakeSyncStorage();
        final client = respondingClient(
          (options, handler) => handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: malformed),
          ),
        );
        final sync = OfflineSyncService(
          client,
          storage,
          isAuthenticated: () => true,
        );
        await sync.queueExerciseCompletion(
          'te',
          '2026-09-06',
          completed: true,
          exerciseId: 'e',
        );
        final id = storage.actions.single['id'];
        await sync.syncPendingActions();
        expect(storage.actions.single['id'], id);
        expect(storage.actions.single['status'], 'failed');
      },
    );
  }
}
