import 'dart:io';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';

class ManagedFeedbackUpload {
  final String uploadId;
  final String fileUrl;

  const ManagedFeedbackUpload({required this.uploadId, required this.fileUrl});
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
  Future<ManagedFeedbackUpload> uploadMedia(File file, String contentType);
}
