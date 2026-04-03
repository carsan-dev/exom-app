import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';

abstract class ChallengesRepository {
  Future<List<ChallengeEntity>> getMyChallenges();
  Future<void> updateProgress(String challengeId, double value);
  Future<List<AchievementEntity>> getMyAchievements();
  Future<int> getMyStreakDays();
}
