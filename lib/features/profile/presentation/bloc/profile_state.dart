part of 'profile_bloc.dart';

abstract class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final ProfileEntity profile;
  final List<BodyMetricEntity> weightHistory;
  final BodyMetricEntity? latestMetric;
  const ProfileLoaded(
    this.profile, {
    this.weightHistory = const [],
    this.latestMetric,
  });
}

class ProfileAvatarUploading extends ProfileState {
  final ProfileEntity profile;
  final List<BodyMetricEntity> weightHistory;
  final BodyMetricEntity? latestMetric;
  const ProfileAvatarUploading(
    this.profile, {
    this.weightHistory = const [],
    this.latestMetric,
  });
}

/// A failed load, goal update or avatar upload.
///
/// EX-Q7 (L5-D28): when a profile was already shown, the error keeps it
/// ([profile], [weightHistory], [latestMetric]) so the page goes on painting
/// it with the error in line. [profile] is null after a first load that
/// failed, and after a session change in flight (the profile belongs to the
/// previous session, R12): the page then shows the full-screen error. The
/// kept data always comes from this bloc's own previous state; the bloc is a
/// factory created per page (`injection_container.dart`), so it never
/// outlives the page nor crosses sessions.
class ProfileError extends ProfileState {
  final String message;
  final ProfileEntity? profile;
  final List<BodyMetricEntity> weightHistory;
  final BodyMetricEntity? latestMetric;
  const ProfileError(
    this.message, {
    this.profile,
    this.weightHistory = const [],
    this.latestMetric,
  });
}
