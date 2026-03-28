import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final GetProfileUseCase getProfile;
  final UpdateProfileUseCase updateProfile;
  final UploadAvatarUseCase uploadAvatar;
  final LocalStorage localStorage;

  static const int _totalSteps = 5; // 0=welcome, 1=basics, 2=body, 3=goals, 4=summary

  OnboardingBloc({
    required this.getProfile,
    required this.updateProfile,
    required this.uploadAvatar,
    required this.localStorage,
  }) : super(const OnboardingInitial()) {
    on<OnboardingStarted>(_onStarted);
    on<OnboardingStepCompleted>(_onStepCompleted);
    on<OnboardingAvatarPicked>(_onAvatarPicked);
    on<OnboardingSubmitted>(_onSubmitted);
    on<OnboardingSkipped>(_onSkipped);
  }

  Future<void> _onStarted(
    OnboardingStarted event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(const OnboardingLoading());
    try {
      final profile = await getProfile();
      final preloaded = <String, dynamic>{};

      if (profile.firstName != null) preloaded['first_name'] = profile.firstName;
      if (profile.lastName != null) preloaded['last_name'] = profile.lastName;
      if (profile.birthDate != null) {
        preloaded['birth_date'] = profile.birthDate!.toIso8601String();
      }
      if (profile.heightCm != null) preloaded['height'] = profile.heightCm;
      if (profile.currentWeightKg != null) {
        preloaded['current_weight'] = profile.currentWeightKg;
      }
      if (profile.level != null) preloaded['level'] = profile.level;
      if (profile.goal != null) preloaded['main_goal'] = profile.goal;
      if (profile.muscleMassGoalKg != null) {
        preloaded['muscle_mass_goal'] = profile.muscleMassGoalKg;
      }

      emit(OnboardingStepActive(
        currentStep: 0,
        totalSteps: _totalSteps,
        accumulatedData: preloaded,
        avatarUrl: profile.avatarUrl,
      ));
    } catch (_) {
      emit(OnboardingStepActive(
        currentStep: 0,
        totalSteps: _totalSteps,
        accumulatedData: const {},
      ));
    }
  }

  Future<void> _onStepCompleted(
    OnboardingStepCompleted event,
    Emitter<OnboardingState> emit,
  ) async {
    final current = state;
    if (current is! OnboardingStepActive) return;

    final merged = {...current.accumulatedData, ...event.data};
    final nextStep = current.currentStep + 1;

    emit(current.copyWith(currentStep: nextStep, accumulatedData: merged));
  }

  Future<void> _onAvatarPicked(
    OnboardingAvatarPicked event,
    Emitter<OnboardingState> emit,
  ) async {
    final current = state;
    if (current is! OnboardingStepActive) return;

    emit(current.copyWith(avatarUploading: true));
    try {
      final file = File(event.filePath);
      final profile = await uploadAvatar(file);
      emit(current.copyWith(avatarUrl: profile.avatarUrl, avatarUploading: false));
    } catch (e) {
      emit(current.copyWith(avatarUploading: false));
    }
  }

  Future<void> _onSubmitted(
    OnboardingSubmitted event,
    Emitter<OnboardingState> emit,
  ) async {
    final current = state;
    if (current is! OnboardingStepActive) return;

    emit(const OnboardingSubmitting());
    try {
      await updateProfile(current.accumulatedData);
      await localStorage.setOnboardingComplete();
      emit(const OnboardingCompleted());
    } catch (e) {
      emit(OnboardingError(e.toString()));
      emit(current); // restore summary step so user can retry
    }
  }

  Future<void> _onSkipped(
    OnboardingSkipped event,
    Emitter<OnboardingState> emit,
  ) async {
    await localStorage.setOnboardingComplete();
    emit(const OnboardingCompleted());
  }
}
