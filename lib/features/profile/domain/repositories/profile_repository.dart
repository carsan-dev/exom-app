import 'dart:io';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<ProfileEntity> getProfile();
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data);
  Future<ProfileEntity> uploadAvatar(File file);
}
