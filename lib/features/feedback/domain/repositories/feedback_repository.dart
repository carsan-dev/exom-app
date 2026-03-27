import 'dart:io';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';

abstract class FeedbackRepository {
  Future<List<FeedbackEntity>> getMyFeedback();
  Future<FeedbackEntity> createFeedback({
    required String mediaType,
    required String mediaUrl,
    String? notes,
    String? exerciseId,
  });
  Future<String> uploadMedia(File file, String contentType);
}
