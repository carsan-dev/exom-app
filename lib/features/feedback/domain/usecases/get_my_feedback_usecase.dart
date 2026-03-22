import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';

class GetMyFeedbackUseCase {
  final FeedbackRepository _repository;

  const GetMyFeedbackUseCase(this._repository);

  Future<List<FeedbackEntity>> call() => _repository.getMyFeedback();
}
