import 'dart:io';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';

class UploadAvatarUseCase {
  final ProfileRepository _repository;

  const UploadAvatarUseCase(this._repository);

  Future<ProfileEntity> call(File file) => _repository.uploadAvatar(file);
}
