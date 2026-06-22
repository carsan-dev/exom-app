import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';

enum FeedbackUploadNoticeKind { queued, completed, failed }

class FeedbackUploadNotice {
  final String id;
  final FeedbackUploadNoticeKind kind;

  const FeedbackUploadNotice(this.id, this.kind);
}

class FeedbackUploadQueueService {
  final FeedbackRepository _repository;
  final LocalStorage _storage;
  final StreamController<FeedbackUploadNotice> _notices =
      StreamController<FeedbackUploadNotice>.broadcast();

  bool _processing = false;
  bool _initialized = false;

  FeedbackUploadQueueService(this._repository, this._storage);

  Stream<FeedbackUploadNotice> get notices => _notices.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final recovered = _storage
        .getFeedbackUploadQueue()
        .map(
          (item) => item['status'] == 'failed' || item['status'] == 'uploading'
              ? {...item, 'status': 'queued'}
              : item,
        )
        .toList();
    await _storage.saveFeedbackUploadQueue(recovered);
    Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(processQueue()),
    );
    await processQueue();
  }

  Future<String> enqueue({
    required File file,
    required String contentType,
    required String mediaType,
    String? notes,
    String? exerciseId,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/feedback_uploads',
    );
    await directory.create(recursive: true);
    final extension = file.path.split('.').last.toLowerCase();
    final stableFile = await file.copy('${directory.path}/$id.$extension');
    final queue = _storage.getFeedbackUploadQueue();
    queue.add({
      'id': id,
      'file_path': stableFile.path,
      'content_type': contentType,
      'media_type': mediaType,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (exerciseId != null && exerciseId.isNotEmpty)
        'exercise_id': exerciseId,
      'status': 'queued',
      'attempts': 0,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _storage.saveFeedbackUploadQueue(queue);
    _notices.add(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.queued));
    unawaited(processQueue());
    return id;
  }

  Future<void> retry(String id) async {
    final queue = _storage.getFeedbackUploadQueue();
    final index = queue.indexWhere((item) => item['id'] == id);
    if (index < 0) return;
    queue[index] = {...queue[index], 'status': 'queued'};
    await _storage.saveFeedbackUploadQueue(queue);
    await processQueue();
  }

  Future<void> processQueue() async {
    if (_processing || FirebaseAuth.instance.currentUser == null) return;
    _processing = true;
    try {
      final queue = _storage.getFeedbackUploadQueue();
      for (var index = 0; index < queue.length; index++) {
        final item = Map<String, dynamic>.from(queue[index]);
        if (item['status'] == 'completed' || item['status'] == 'failed') {
          continue;
        }
        final id = item['id'] as String;
        final file = File(item['file_path'] as String);
        if (!await file.exists()) {
          queue[index] = {...item, 'status': 'failed'};
          _notices.add(
            FeedbackUploadNotice(id, FeedbackUploadNoticeKind.failed),
          );
          continue;
        }

        queue[index] = {
          ...item,
          'status': 'uploading',
          'attempts': (item['attempts'] as int? ?? 0) + 1,
        };
        await _storage.saveFeedbackUploadQueue(queue);

        try {
          final fileUrl = await _repository.uploadMedia(
            file,
            item['content_type'] as String,
          );
          await _repository.createFeedback(
            mediaType: item['media_type'] as String,
            mediaUrl: fileUrl,
            notes: item['notes'] as String?,
            exerciseId: item['exercise_id'] as String?,
            clientUploadId: id,
          );
          if (await file.exists()) {
            await file.delete();
          }
          queue[index] = {...item, 'status': 'completed'};
          _notices.add(
            FeedbackUploadNotice(id, FeedbackUploadNoticeKind.completed),
          );
        } catch (_) {
          queue[index] = {...item, 'status': 'failed'};
          _notices.add(
            FeedbackUploadNotice(id, FeedbackUploadNoticeKind.failed),
          );
        }
        await _storage.saveFeedbackUploadQueue(queue);
      }
      queue.removeWhere((item) => item['status'] == 'completed');
      await _storage.saveFeedbackUploadQueue(queue);
    } finally {
      _processing = false;
    }
  }
}
