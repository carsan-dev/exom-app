import 'package:exom_app/features/challenges/data/datasources/challenges_remote_datasource.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';

class ChallengesRepositoryImpl implements ChallengesRepository {
  final ChallengesRemoteDataSource _remoteDataSource;

  const ChallengesRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<ChallengeEntity>> getMyChallenges() {
    return _remoteDataSource.getMyChallenges();
  }

  @override
  Future<void> updateProgress(String challengeId, double value) {
    return _remoteDataSource.updateProgress(challengeId, value);
  }

  @override
  Future<List<AchievementEntity>> getMyAchievements() {
    return _remoteDataSource.getMyAchievements();
  }

  @override
  Future<List<AchievementEntity>> getAchievementCatalog() {
    return _remoteDataSource.getAchievementCatalog();
  }

  @override
  Future<int> getMyStreakDays() {
    return _remoteDataSource.getMyStreakDays();
  }
}
