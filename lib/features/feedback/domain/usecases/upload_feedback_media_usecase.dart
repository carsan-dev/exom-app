import 'dart:io';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';

class UploadFeedbackMediaUseCase {
  final FeedbackRepository _repository;

  const UploadFeedbackMediaUseCase(this._repository);

  Future<ManagedFeedbackUpload> call(File file, String contentType) =>
      _repository.uploadMedia(file, contentType);
}
