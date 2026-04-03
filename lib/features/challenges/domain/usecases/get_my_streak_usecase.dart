import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';

class GetMyStreakUseCase {
  final ChallengesRepository _repository;

  const GetMyStreakUseCase(this._repository);

  Future<int> call() => _repository.getMyStreakDays();
}
