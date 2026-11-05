import 'dart:io';

import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_upload_queue_service_test.dart';

class ProgressRepository extends FakeFeedbackRepository {
  ProgressRepository(this.total);

  final int total;
  void Function(int)? afterProgress;

  @override
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType, {
    FeedbackUploadContext? context,
  }) async {
    context!.onPreparing!();
    for (var sent = 0; sent <= 1000; sent++) {
      context.onProgress!(sent, total);
      afterProgress?.call(sent);
    }
    context.onProcessing!();
    return super.uploadMedia(file, contentType, context: context);
  }
}

void main() {
  for (final total in [1000, 0, -1]) {
    test(
      'progress bounds known percentages and retains unknown totals ($total)',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'exom-progress-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = await File(
          '${directory.path}/evidence.mp4',
        ).writeAsBytes([1]);
        final storage = FakeFeedbackQueueStorage([
          {
            'id': 'progress',
            'file_path': file.path,
            'content_type': 'video/mp4',
            'media_type': 'VIDEO',
            'status': 'queued',
          },
        ]);
        final offline = FakeOfflineSyncService(storage);
        final repository = ProgressRepository(total);
        final queue = FeedbackUploadQueueService(
          repository,
          storage,
          offline,
          isAuthenticated: () => true,
        );
        repository.afterProgress = (sent) =>
            expect(queue.progressOf('progress')?.sentBytes, sent);
        final notices = <FeedbackUploadNotice>[];
        final subscription = queue.notices.listen(notices.add);
        addTearDown(() async {
          await subscription.cancel();
          await queue.dispose();
          await offline.dispose();
        });
        await queue.processQueue();
        await Future<void>.delayed(Duration.zero);
        final progress = notices
            .where((notice) => notice.sentBytes != null)
            .toList();
        final count = total > 0 ? 101 : 1001;
        expect(progress, hasLength(count));
        expect(
          progress.map((notice) => notice.sentBytes),
          List.generate(count, (index) => index * (total > 0 ? 10 : 1)),
        );
        expect(
          notices.map((notice) => notice.kind),
          containsAllInOrder([
            FeedbackUploadNoticeKind.preparing,
            FeedbackUploadNoticeKind.uploading,
            FeedbackUploadNoticeKind.processing,
            FeedbackUploadNoticeKind.completed,
          ]),
        );
        expect(
          queue.progressOf('progress')?.kind,
          FeedbackUploadNoticeKind.completed,
        );
        expect(storage.queue.single['status'], 'completed');
      },
    );
  }
}
