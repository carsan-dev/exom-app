part of 'challenges_bloc.dart';

abstract class ChallengesEvent {
  const ChallengesEvent();
}

class ChallengesLoadRequested extends ChallengesEvent {
  const ChallengesLoadRequested();
}

class ChallengeProgressUpdated extends ChallengesEvent {
  final String challengeId;
  final double newValue;

  const ChallengeProgressUpdated({
    required this.challengeId,
    required this.newValue,
  });
}
