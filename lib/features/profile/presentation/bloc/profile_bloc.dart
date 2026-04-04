import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase _getProfileUseCase;
  final UpdateProfileUseCase _updateProfileUseCase;
  final UploadAvatarUseCase _uploadAvatarUseCase;
  final MetricsRepository _metricsRepository;

  ProfileBloc({
    required GetProfileUseCase getProfileUseCase,
    required UpdateProfileUseCase updateProfileUseCase,
    required UploadAvatarUseCase uploadAvatarUseCase,
    required MetricsRepository metricsRepository,
  }) : _getProfileUseCase = getProfileUseCase,
       _updateProfileUseCase = updateProfileUseCase,
       _uploadAvatarUseCase = uploadAvatarUseCase,
       _metricsRepository = metricsRepository,
       super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileAvatarUploadRequested>(_onAvatarUploadRequested);
    on<ProfileMuscleGoalUpdated>(_onMuscleGoalUpdated);
  }

  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final results = await Future.wait([
        _getProfileUseCase(),
        _metricsRepository.getWeightHistory(),
        _metricsRepository.getLatestMetric(),
      ]);
      final profile = results[0] as ProfileEntity;
      final history = results[1] as List<BodyMetricEntity>;
      final latest = results[2] as BodyMetricEntity?;
      emit(
        ProfileLoaded(profile, weightHistory: history, latestMetric: latest),
      );
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onAvatarUploadRequested(
    ProfileAvatarUploadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final current = state;
    final history = current is ProfileLoaded
        ? current.weightHistory
        : <BodyMetricEntity>[];
    final latest = current is ProfileLoaded ? current.latestMetric : null;
    if (current is ProfileLoaded) {
      emit(ProfileAvatarUploading(
        current.profile,
        weightHistory: history,
        latestMetric: latest,
      ));
    }
    try {
      final updated = await _uploadAvatarUseCase(event.file);
      emit(ProfileLoaded(updated, weightHistory: history, latestMetric: latest));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onMuscleGoalUpdated(
    ProfileMuscleGoalUpdated event,
    Emitter<ProfileState> emit,
  ) async {
    final current = state;
    if (current is! ProfileLoaded) {
      return;
    }

    emit(const ProfileLoading());

    try {
      final updatedProfile = await _updateProfileUseCase({
        'muscle_mass_goal': event.goalKg,
      });
      emit(
        ProfileLoaded(
          updatedProfile,
          weightHistory: current.weightHistory,
          latestMetric: current.latestMetric,
        ),
      );
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
