import 'dart:io';
import 'package:exom_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:exom_app/features/profile/data/models/profile_model.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  const ProfileRepositoryImpl(this._remoteDataSource);

  @override
  Future<ProfileEntity> getProfile() async {
    final model = await _remoteDataSource.getProfile();
    return _mapToEntity(model);
  }

  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async {
    final model = await _remoteDataSource.updateProfile(data);
    return _mapToEntity(model);
  }

  @override
  Future<ProfileEntity> uploadAvatar(File file) async {
    final model = await _remoteDataSource.uploadAvatar(file);
    return _mapToEntity(model);
  }

  ProfileEntity _mapToEntity(ProfileModel model) {
    return ProfileEntity(
      id: model.id,
      firstName: model.firstName,
      lastName: model.lastName,
      email: model.email,
      phone: model.phone,
      avatarUrl: model.avatarUrl,
      level: model.level,
      goal: model.goal,
      heightCm: model.heightCm,
      sex: model.sex,
      birthDate: model.birthDate,
      totalTrainings: model.totalTrainings,
      streakDays: model.streakDays,
      currentWeightKg: model.currentWeightKg,
      muscleMassGoalKg: model.muscleMassGoalKg,
      currentBmi: model.currentBmi,
      targetCalories: model.targetCalories,
    );
  }
}
