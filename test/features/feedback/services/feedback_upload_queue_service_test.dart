import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'does not create feedback or delete evidence after validation is revoked during upload',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exom-auth-upload-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/evidence.mp4');
      await file.writeAsBytes([0]);
      final storage = FakeFeedbackQueueStorage([
        {
          'id': 'pending',
          'file_path': file.path,
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          'status': 'queued',
          'attempts': 0,
        },
      ]);
      var authenticated = true;
      final repository = BlockingFeedbackRepository();
      final service = FeedbackUploadQueueService(
        repository,
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => authenticated,
      );
      final processing = service.processQueue();
      await repository.firstUploadStarted.future;
      authenticated = false;
      repository.releaseFirstUpload.complete();
      await processing;
      expect(repository.createCalls, 0);
      expect(await file.exists(), true);
      expect(storage.queue.single['status'], 'queued');
    },
  );
  test('discard deletes the physical file and its dependent action', () async {
    final directory = await Directory.systemTemp.createTemp(
      'exom-feedback-queue-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}/evidence.mp4');
    await file.writeAsBytes([0, 0, 0, 0]);
    final storage = FakeFeedbackQueueStorage([
      {
        'id': 'feedback-1',
        'file_path': file.path,
        'status': 'failed',
        'attempts': 5,
      },
    ]);
    final offline = FakeOfflineSyncService(storage);
    final service = FeedbackUploadQueueService(
      FakeFeedbackRepository(),
      storage,
      offline,
      isAuthenticated: () => false,
    );

    await service.discard('feedback-1');

    expect(await file.exists(), isFalse);
    expect(storage.queue, isEmpty);
    expect(offline.removedDependencies, ['feedback-1']);
  });

  test('preserves an enqueue while another upload is in flight', () async {
    final directory = await Directory.systemTemp.createTemp(
      'exom-feedback-concurrent-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final first = File('${directory.path}/first.mp4');
    final second = File('${directory.path}/second.mp4');
    await first.writeAsBytes([0, 0, 0, 0]);
    await second.writeAsBytes([0, 0, 0, 1]);
    final storage = FakeFeedbackQueueStorage([]);
    final repository = BlockingFeedbackRepository();
    final service = FeedbackUploadQueueService(
      repository,
      storage,
      FakeOfflineSyncService(storage),
      isAuthenticated: () => true,
      applicationSupportDirectory: () async => directory,
    );

    await service.enqueue(
      file: first,
      contentType: 'video/mp4',
      mediaType: 'VIDEO',
    );
    await repository.firstUploadStarted.future;
    await service.enqueue(
      file: second,
      contentType: 'video/mp4',
      mediaType: 'VIDEO',
    );
    repository.releaseFirstUpload.complete();
    await waitUntil(
      () =>
          storage.queue.length == 2 &&
          storage.queue.every((item) => item['status'] == 'completed'),
    );

    expect(repository.uploadCalls, 2);
    expect(repository.createCalls, 2);
  });

  test('keeps a fifth upload failure visible', () async {
    final directory = await Directory.systemTemp.createTemp(
      'exom-feedback-failed-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}/evidence.mp4');
    await file.writeAsBytes([0, 0, 0, 0]);
    final storage = FakeFeedbackQueueStorage([
      {
        'id': 'feedback-1',
        'file_path': file.path,
        'content_type': 'video/mp4',
        'media_type': 'VIDEO',
        'status': 'queued',
        'attempts': 4,
      },
    ]);
    final service = FeedbackUploadQueueService(
      FakeFeedbackRepository(uploadError: StateError('network failed')),
      storage,
      FakeOfflineSyncService(storage),
      isAuthenticated: () => true,
    );

    await service.processQueue();

    expect(storage.queue.single['status'], 'failed');
    expect(storage.queue.single['attempts'], 5);
    expect(storage.queue.single['last_error'], contains('network failed'));
  });

  test(
    'cleanup failure does not turn a successful upload into failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exom-feedback-cleanup-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File('${directory.path}/evidence.mp4');
      await file.writeAsBytes([0, 0, 0, 0]);
      final storage = FakeFeedbackQueueStorage([
        {
          'id': 'feedback-1',
          'file_path': file.path,
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          'status': 'queued',
          'attempts': 0,
        },
      ]);
      var cleanupCalls = 0;
      final repository = FakeFeedbackRepository();
      final service = FeedbackUploadQueueService(
        repository,
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => true,
        deleteFile: (_) async {
          cleanupCalls++;
          if (cleanupCalls == 1) {
            throw const FileSystemException('locked');
          }
        },
      );

      await service.processQueue();
      expect(storage.queue.single['status'], 'completed');
      expect(storage.queue.single['last_error'], startsWith('cleanup_failed:'));
      expect(repository.createCalls, 1);

      await service.processQueue();
      expect(storage.queue.single['status'], 'completed');
      expect(storage.queue.single['last_error'], isNull);
      expect(repository.createCalls, 1);
      expect(cleanupCalls, 2);
    },
  );

  test('discard keeps an item visible when cleanup fails', () async {
    final storage = FakeFeedbackQueueStorage([
      {'id': 'feedback-1', 'file_path': 'locked.mp4', 'status': 'failed'},
    ]);
    final offline = FakeOfflineSyncService(storage);
    final service = FeedbackUploadQueueService(
      FakeFeedbackRepository(),
      storage,
      offline,
      isAuthenticated: () => false,
      deleteFile: (_) async {
        throw const FileSystemException('locked');
      },
    );

    await expectLater(
      service.discard('feedback-1'),
      throwsA(isA<FileSystemException>()),
    );

    expect(storage.queue.single['status'], 'failed');
    expect(storage.queue.single['last_error'], startsWith('cleanup_failed:'));
    expect(offline.removedDependencies, isEmpty);
  });

  test(
    'preserves pending evidence while the session is not validated regardless of age',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exom-feedback-expired-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File('${directory.path}/expired.mp4');
      await file.writeAsBytes([0, 0, 0, 0]);
      final storage = FakeFeedbackQueueStorage([
        {
          'id': 'feedback-1',
          'file_path': file.path,
          'status': 'failed',
          'queued_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 25))
              .toIso8601String(),
        },
      ]);
      final offline = FakeOfflineSyncService(storage);
      final service = FeedbackUploadQueueService(
        FakeFeedbackRepository(),
        storage,
        offline,
        isAuthenticated: () => false,
      );

      await service.processQueue();

      expect(await file.exists(), isTrue);
      expect(storage.queue.single['id'], 'feedback-1');
      expect(offline.removedDependencies, isEmpty);
    },
  );

  test('keeps completed evidence unblocked when TTL cleanup fails', () async {
    final storage = FakeFeedbackQueueStorage([
      {
        'id': 'feedback-1',
        'file_path': 'locked.mp4',
        'status': 'completed',
        'queued_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 25))
            .toIso8601String(),
      },
    ]);
    final offline = FakeOfflineSyncService(storage);
    final service = FeedbackUploadQueueService(
      FakeFeedbackRepository(),
      storage,
      offline,
      isAuthenticated: () => false,
      deleteFile: (_) async {
        throw const FileSystemException('locked');
      },
    );

    await service.processQueue();

    expect(storage.queue.single['status'], 'completed');
    expect(storage.queue.single['last_error'], startsWith('cleanup_failed:'));
    expect(offline.removedDependencies, isEmpty);
  });
}

Future<void> waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not reached');
}

class FakeFeedbackQueueStorage extends LocalStorage {
  FakeFeedbackQueueStorage(this.queue);

  List<Map<String, dynamic>> queue;

  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() =>
      queue.map(Map<String, dynamic>.from).toList();

  @override
  Future<void> saveFeedbackUploadQueue(List<Map<String, dynamic>> value) async {
    queue = value.map(Map<String, dynamic>.from).toList();
  }
}

class FakeOfflineSyncService extends OfflineSyncService {
  FakeOfflineSyncService(LocalStorage storage)
    : super(ApiClient(useAuth: false), storage, isAuthenticated: () => false);

  final List<String> removedDependencies = [];

  @override
  Future<void> removeActionsDependingOnFeedback(String feedbackId) async {
    removedDependencies.add(feedbackId);
  }
}

class FakeFeedbackRepository implements FeedbackRepository {
  FakeFeedbackRepository({this.uploadError});

  final Object? uploadError;
  int uploadCalls = 0;
  int createCalls = 0;

  @override
  Future<FeedbackEntity> createFeedback({
    required String mediaType,
    required String mediaUrl,
    String? uploadId,
    String? notes,
    String? exerciseId,
    String? clientUploadId,
    String? feedbackKind,
    String? trainingId,
    String? trainingExerciseId,
    String? assignmentDate,
  }) async {
    createCalls++;
    return FeedbackEntity(
      id: clientUploadId ?? 'feedback',
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      status: 'PENDING',
      createdAt: DateTime.utc(2026, 9, 1),
    );
  }

  @override
  Future<List<FeedbackEntity>> getMyFeedback() => throw UnimplementedError();

  @override
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType,
  ) async {
    uploadCalls++;
    if (uploadError case final error?) throw error;
    return const ManagedFeedbackUpload(
      uploadId: 'upload-1',
      fileUrl: 'r2://feedback/evidence.mp4',
    );
  }
}

class BlockingFeedbackRepository extends FakeFeedbackRepository {
  final firstUploadStarted = Completer<void>();
  final releaseFirstUpload = Completer<void>();

  @override
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType,
  ) async {
    uploadCalls++;
    if (uploadCalls == 1) {
      firstUploadStarted.complete();
      await releaseFirstUpload.future;
    }
    return ManagedFeedbackUpload(
      uploadId: 'upload-$uploadCalls',
      fileUrl: 'r2://feedback/evidence-$uploadCalls.mp4',
    );
  }
}
