import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';

class UpdateChallengeProgressUseCase {
  final ChallengesRepository _repository;

  const UpdateChallengeProgressUseCase(this._repository);

  Future<void> call(String challengeId, double value) {
    return _repository.updateProgress(challengeId, value);
  }
}
