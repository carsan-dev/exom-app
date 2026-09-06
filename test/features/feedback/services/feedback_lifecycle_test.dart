import 'dart:io';
import 'package:dio/dio.dart';

import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_upload_queue_service_test.dart';

void main() {
  test('48 hours offline never authorizes deleting pending evidence', () async {
    final dir = await Directory.systemTemp.createTemp('exom-retention-');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}/evidence.mp4').writeAsBytes([0]);
    final storage = FakeFeedbackQueueStorage([
      {
        'id': 'retained',
        'file_path': file.path,
        'status': 'failed',
        'queued_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 48))
            .toIso8601String(),
      },
    ]);
    final service = FeedbackUploadQueueService(
      FakeFeedbackRepository(),
      storage,
      FakeOfflineSyncService(storage),
      isAuthenticated: () => true,
    );
    await service.processQueue();
    expect(await file.exists(), isTrue);
    expect(storage.queue.single['status'], 'failed');
  });

  test('confirmation is durable BEFORE physical cleanup starts', () async {
    final dir = await Directory.systemTemp.createTemp('exom-confirm-');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}/evidence.mp4').writeAsBytes([0]);
    final storage = FakeFeedbackQueueStorage([
      {
        'id': 'confirmed',
        'file_path': file.path,
        'status': 'queued',
        'media_type': 'VIDEO',
        'content_type': 'video/mp4',
      },
    ]);
    String? statusAtDelete;
    final service = FeedbackUploadQueueService(
      FakeFeedbackRepository(),
      storage,
      FakeOfflineSyncService(storage),
      isAuthenticated: () => true,
      deleteFile: (_) async {
        statusAtDelete = storage.queue.single['status'] as String?;
      },
    );
    await service.processQueue();
    expect(statusAtDelete, 'completed');
  });
  test(
    'crash after verified upload resumes feedback; recoverable retry never uploads again',
    () async {
      final dir = await Directory.systemTemp.createTemp('exom-checkpoint-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/evidence.mp4').writeAsBytes([1]);
      final storage = FakeFeedbackQueueStorage([
        {
          'id': 'stable-operation',
          'status': 'uploading',
          'claimed_at': DateTime.now().toUtc().toIso8601String(),
          'file_path': file.path,
          'media_type': 'VIDEO',
          'content_type': 'video/mp4',
          'verified_upload_id': 'verified-1',
          'verified_file_url': 'r2://feedback/verified.mp4',
        },
      ]);
      final repository = FakeFeedbackRepository()
        ..createError = DioException.connectionError(
          requestOptions: RequestOptions(path: '/feedback'),
          reason: 'response lost',
        );
      final queue = FeedbackUploadQueueService(
        repository,
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => true,
      );
      await queue.processQueue();
      expect(repository.uploadCalls, 0);
      expect(repository.createCalls, 1);
      expect(storage.queue.single['status'], 'queued');
      expect(storage.queue.single['id'], 'stable-operation');
      expect(await file.exists(), true);
      repository.createError = null;
      storage.queue.single.remove('next_attempt_at');
      await queue.processQueue();
      expect(repository.uploadCalls, 0);
      expect(repository.createCalls, 2);
      expect(storage.queue.single['status'], 'completed');
      expect(await file.exists(), false);
    },
  );
}
