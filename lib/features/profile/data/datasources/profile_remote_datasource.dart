import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/utils/image_compressor.dart';
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
    final normalizedData = Map<String, dynamic>.from(data);
    final level = normalizedData['level'];
    if (level is String) {
      normalizedData['level'] = ProfileModel.normalizeLevelValue(level);
    }

    final response = await _apiClient.dio.put<dynamic>(
      '/profile/me',
      data: normalizedData,
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
    final compressed = await ImageCompressor.compressAvatar(file);
    final fileKey =
        'avatars/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        compressed.path,
        filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
      'file_key': fileKey,
      'content_type': 'image/jpeg',
    });

    final response = await _apiClient.dio.post<dynamic>(
      '/uploads/file',
      data: formData,
    );

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw Exception('Invalid upload response');
    }
    final fileUrl =
        ((payload['data'] as Map<String, dynamic>)['file_url'] as String?) ??
        (payload['file_url'] as String);

    return updateProfile({'avatar_url': fileUrl});
  }
}
