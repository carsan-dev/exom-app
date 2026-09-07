import 'dart:io';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';

class ManagedFeedbackUpload {
  final String uploadId;
  final String fileUrl;

  const ManagedFeedbackUpload({required this.uploadId, required this.fileUrl});
}

/// Durable stage updates, while byte progress stays in memory only.
class FeedbackUploadContext {
  final String operationId;
  final Map<String, dynamic> checkpoint;
  final Future<void> Function(Map<String, dynamic>) saveCheckpoint;
  final bool Function() isCurrent;
  final void Function(int sent, int total)? onProgress;
  final void Function()? onPreparing;
  final void Function()? onProcessing;

  const FeedbackUploadContext({
    required this.operationId,
    required this.checkpoint,
    required this.saveCheckpoint,
    required this.isCurrent,
    this.onProgress,
    this.onPreparing,
    this.onProcessing,
  });
}

abstract class FeedbackRepository {
  Future<List<FeedbackEntity>> getMyFeedback();
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
  });
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType, {
    FeedbackUploadContext? context,
  });
}
