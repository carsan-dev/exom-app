import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/profile/data/models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();
  Future<ProfileModel> updateProfile(Map<String, dynamic> data);
  Future<ProfileModel> uploadAvatar(File file);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  const ProfileRemoteDataSourceImpl(this._apiClient, this._localStorage);

  @override
  Future<ProfileModel> getProfile() async {
    const cacheKey = 'profile_me';

    try {
      final response = await _apiClient.dio.get<dynamic>('/profile/me');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          await _localStorage.cacheData(cacheKey, inner);
          await _localStorage.cacheData('home_profile', inner);
          return ProfileModel.fromJson(inner);
        }
      }
      throw Exception('Invalid profile response');
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedMap(cacheKey);
        if (cached != null) {
          return ProfileModel.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  @override
  Future<ProfileModel> updateProfile(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.put<dynamic>(
      '/profile/me',
      data: data,
    );
    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final inner = payload['data'];
      if (inner is Map<String, dynamic>) {
        await _localStorage.cacheData('profile_me', inner);
        await _localStorage.cacheData('home_profile', inner);
        return ProfileModel.fromJson(inner);
      }
    }
    throw Exception('Invalid profile response');
  }

  @override
  Future<ProfileModel> uploadAvatar(File file) async {
    final fileKey = 'avatars/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final presigned = await _apiClient.post<Map<String, dynamic>>(
      '/uploads/presigned',
      data: {'file_key': fileKey, 'content_type': 'image/jpeg'},
    );

    final uploadUrl = presigned['upload_url'] as String;
    final fileUrl = presigned['file_url'] as String;

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

    return updateProfile({'avatar_url': fileUrl});
  }
}
