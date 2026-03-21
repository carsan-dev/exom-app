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
  const ProfileLoaded(this.profile);
}

class ProfileAvatarUploading extends ProfileState {
  final ProfileEntity profile;
  const ProfileAvatarUploading(this.profile);
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
}
