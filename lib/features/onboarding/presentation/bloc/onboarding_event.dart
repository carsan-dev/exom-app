part of 'onboarding_bloc.dart';

abstract class OnboardingEvent {
  const OnboardingEvent();
}

class OnboardingStarted extends OnboardingEvent {
  const OnboardingStarted();
}

class OnboardingStepCompleted extends OnboardingEvent {
  final int step;
  final Map<String, dynamic> data;

  const OnboardingStepCompleted({required this.step, required this.data});
}

class OnboardingAvatarPicked extends OnboardingEvent {
  final String filePath;

  const OnboardingAvatarPicked(this.filePath);
}

class OnboardingSubmitted extends OnboardingEvent {
  const OnboardingSubmitted();
}

class OnboardingSkipped extends OnboardingEvent {
  const OnboardingSkipped();
}
