import 'dart:io';
import 'package:dio/dio.dart';
import 'package:exom_app/core/storage/local_storage.dart';
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
      // The metric calls throw on network and server errors (L4-I1). The
      // profile does not depend on them: it still loads, without the weight
      // chart or the latest record, as it did when the datasource returned
      // [] / null. A session change keeps failing the whole load.
      final results = await Future.wait([
        _getProfileUseCase(),
        _orFallback(
          _metricsRepository.getWeightHistory(),
          const <BodyMetricEntity>[],
        ),
        _orFallback(_metricsRepository.getLatestMetric(), null),
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

  /// Never turns a session change into loaded data: LocalSessionChanged and a
  /// request cancelled by the auth interceptor (session changed in flight)
  /// still fail the whole load.
  static Future<T> _orFallback<T>(Future<T> request, T fallback) async {
    try {
      return await request;
    } on LocalSessionChanged {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      return fallback;
    } catch (_) {
      return fallback;
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
