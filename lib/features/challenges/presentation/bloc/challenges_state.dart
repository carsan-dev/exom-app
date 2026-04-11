part of 'challenges_bloc.dart';

abstract class ChallengesState {
  const ChallengesState();
}

class ChallengesInitial extends ChallengesState {
  const ChallengesInitial();
}

class ChallengesLoading extends ChallengesState {
  const ChallengesLoading();
}

class ChallengesLoaded extends ChallengesState {
  final List<ChallengeEntity> mainGoals;
  final List<ChallengeEntity> weeklyChallenges;
  final List<AchievementEntity> achievements;
  final List<AchievementEntity> achievementCatalog;
  final int streakDays;

  const ChallengesLoaded({
    required this.mainGoals,
    required this.weeklyChallenges,
    required this.achievements,
    required this.achievementCatalog,
    required this.streakDays,
  });
}

class ChallengesEmpty extends ChallengesState {
  final List<AchievementEntity> achievements;
  final List<AchievementEntity> achievementCatalog;
  final int streakDays;

  const ChallengesEmpty({
    required this.achievements,
    required this.achievementCatalog,
    required this.streakDays,
  });
}

class ChallengesError extends ChallengesState {
  final String message;
  final ApiException? apiException;

  const ChallengesError({required this.message, this.apiException});
}
