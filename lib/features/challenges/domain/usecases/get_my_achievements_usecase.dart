import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';

class GetMyAchievementsUseCase {
  final ChallengesRepository _repository;

  const GetMyAchievementsUseCase(this._repository);

  Future<List<AchievementEntity>> call() => _repository.getMyAchievements();
}
