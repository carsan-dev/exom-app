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

  const ChallengesLoaded({
    required this.mainGoals,
    required this.weeklyChallenges,
    required this.achievements,
  });
}

class ChallengesError extends ChallengesState {
  final String message;
  const ChallengesError(this.message);
}
