import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';

class MarkRecapFeedbackReadUseCase {
  final RecapRepository _repository;

  const MarkRecapFeedbackReadUseCase(this._repository);

  Future<void> call(String id) => _repository.markFeedbackRead(id);
}
