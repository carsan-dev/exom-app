import 'dart:io';

import 'package:exom_app/features/progress_photos/services/progress_photo_upload_queue_service.dart';

/// Presentation boundary for the durable P2-T4 queue. The UI can observe and
/// enqueue work but cannot access the managed-upload transport directly.
abstract interface class ProgressPhotoQueue {
  List<Map<String, dynamic>> get pendingItems;

  Future<String> enqueue({
    required File file,
    required String civilSessionDate,
    required String canonicalView,
    required String contentType,
    String? resolvedSessionId,
    String? replacesPhotoId,
    String? expectedSession,
  });

  Future<void> retry(String id);
  Future<void> rebaseReplacement(String id, String activePhotoId);
  Future<void> discard(String id);
}

class ProgressPhotoQueueAdapter implements ProgressPhotoQueue {
  const ProgressPhotoQueueAdapter(this._queue);

  final ProgressPhotoUploadQueueService _queue;

  @override
  List<Map<String, dynamic>> get pendingItems => _queue.pendingItems;

  @override
  Future<String> enqueue({
    required File file,
    required String civilSessionDate,
    required String canonicalView,
    required String contentType,
    String? resolvedSessionId,
    String? replacesPhotoId,
    String? expectedSession,
  }) => _queue.enqueue(
    file: file,
    civilSessionDate: civilSessionDate,
    canonicalView: canonicalView,
    contentType: contentType,
    resolvedSessionId: resolvedSessionId,
    replacesPhotoId: replacesPhotoId,
    expectedSession: expectedSession,
  );

  @override
  Future<void> retry(String id) => _queue.retry(id);

  @override
  Future<void> rebaseReplacement(String id, String activePhotoId) =>
      _queue.rebaseReplacement(id, activePhotoId);

  @override
  Future<void> discard(String id) => _queue.discard(id);
}
