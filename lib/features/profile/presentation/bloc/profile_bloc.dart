import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase _getProfileUseCase;
  final UploadAvatarUseCase _uploadAvatarUseCase;

  ProfileBloc({
    required GetProfileUseCase getProfileUseCase,
    required UploadAvatarUseCase uploadAvatarUseCase,
  })  : _getProfileUseCase = getProfileUseCase,
        _uploadAvatarUseCase = uploadAvatarUseCase,
        super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileAvatarUploadRequested>(_onAvatarUploadRequested);
  }

  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final profile = await _getProfileUseCase();
      emit(ProfileLoaded(profile));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onAvatarUploadRequested(
    ProfileAvatarUploadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final current = state;
    if (current is ProfileLoaded) {
      emit(ProfileAvatarUploading(current.profile));
    }
    try {
      final updated = await _uploadAvatarUseCase(event.file);
      emit(ProfileLoaded(updated));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
