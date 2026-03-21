part of 'profile_bloc.dart';

abstract class ProfileEvent {
  const ProfileEvent();
}

class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

class ProfileAvatarUploadRequested extends ProfileEvent {
  final File file;
  const ProfileAvatarUploadRequested(this.file);
}
