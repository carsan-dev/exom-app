import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';

class CreateFeedbackUseCase {
  final FeedbackRepository _repository;

  const CreateFeedbackUseCase(this._repository);

  Future<FeedbackEntity> call({
    required String mediaType,
    required String mediaUrl,
    String? notes,
    String? exerciseId,
    String? clientUploadId,
  }) => _repository.createFeedback(
    mediaType: mediaType,
    mediaUrl: mediaUrl,
    notes: notes,
    exerciseId: exerciseId,
    clientUploadId: clientUploadId,
  );
}
