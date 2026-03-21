import 'dart:io';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/profile/data/models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();
  Future<ProfileModel> updateProfile(Map<String, dynamic> data);
  Future<ProfileModel> uploadAvatar(File file);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiClient _apiClient;

  const ProfileRemoteDataSourceImpl(this._apiClient);

  @override
  Future<ProfileModel> getProfile() async {
    return await _apiClient.get<ProfileModel>(
      '/profile/me',
      fromJson: ProfileModel.fromJson,
    );
  }

  @override
  Future<ProfileModel> updateProfile(Map<String, dynamic> data) async {
    return await _apiClient.put<ProfileModel>(
      '/profile/me',
      data: data,
      fromJson: ProfileModel.fromJson,
    );
  }

  @override
  Future<ProfileModel> uploadAvatar(File file) async {
    final fileKey = 'avatars/${DateTime.now().millisecondsSinceEpoch}.jpg';

    // 1. Get presigned URL from backend
    final presigned = await _apiClient.post<Map<String, dynamic>>(
      '/uploads/presigned',
      data: {'file_key': fileKey, 'content_type': 'image/jpeg'},
    );

    final uploadUrl = presigned['upload_url'] as String;
    final fileUrl = presigned['file_url'] as String;

    // 2. Upload directly to R2 (no auth header)
    final bytes = await file.readAsBytes();
    await Dio().put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': 'image/jpeg',
          'Content-Length': bytes.length.toString(),
        },
        contentType: 'image/jpeg',
      ),
    );

    // 3. Update profile with new avatar URL
    return updateProfile({'avatar_url': fileUrl});
  }
}
