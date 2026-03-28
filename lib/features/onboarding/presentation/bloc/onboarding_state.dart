part of 'onboarding_bloc.dart';

abstract class OnboardingState {
  const OnboardingState();
}

class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

class OnboardingLoading extends OnboardingState {
  const OnboardingLoading();
}

class OnboardingStepActive extends OnboardingState {
  final int currentStep;
  final int totalSteps;
  final Map<String, dynamic> accumulatedData;
  final String? avatarUrl;
  final bool avatarUploading;

  const OnboardingStepActive({
    required this.currentStep,
    required this.totalSteps,
    required this.accumulatedData,
    this.avatarUrl,
    this.avatarUploading = false,
  });

  OnboardingStepActive copyWith({
    int? currentStep,
    Map<String, dynamic>? accumulatedData,
    String? avatarUrl,
    bool? avatarUploading,
  }) {
    return OnboardingStepActive(
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps,
      accumulatedData: accumulatedData ?? this.accumulatedData,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarUploading: avatarUploading ?? this.avatarUploading,
    );
  }
}

class OnboardingSubmitting extends OnboardingState {
  const OnboardingSubmitting();
}

class OnboardingCompleted extends OnboardingState {
  const OnboardingCompleted();
}

class OnboardingLoadError extends OnboardingState {
  final String message;
  final ApiException? apiException;

  const OnboardingLoadError({required this.message, this.apiException});
}

class OnboardingSubmitError extends OnboardingState {
  final String message;
  final ApiException? apiException;

  const OnboardingSubmitError({required this.message, this.apiException});
}
