import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';

class GetMyChallengesUseCase {
  final ChallengesRepository _repository;

  const GetMyChallengesUseCase(this._repository);

  Future<List<ChallengeEntity>> call() => _repository.getMyChallenges();
}
