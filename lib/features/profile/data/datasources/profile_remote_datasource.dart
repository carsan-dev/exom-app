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
    try {
      final extension = compressed.path.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => throw UnsupportedError('Unsupported avatar image format'),
      };
      final bytes = await compressed.length();
      final sessionResponse = await _apiClient.dio.post<dynamic>(
        '/uploads/sessions',
        data: {
          'purpose': 'AVATAR',
          'content_type': contentType,
          'bytes': bytes,
        },
      );
      final payload = sessionResponse.data as Map<String, dynamic>;
      final session = (payload['data'] as Map<String, dynamic>?) ?? payload;
      final uploadId = session['upload_id'] as String;
      await Dio().put<dynamic>(
        session['upload_url'] as String,
        data: compressed.openRead(),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes,
          },
        ),
      );
      await _apiClient.dio.post<dynamic>(
        '/uploads/sessions/$uploadId/complete',
      );
      return updateProfile({'avatar_upload_id': uploadId});
    } finally {
      if (compressed.absolute.path != file.absolute.path) {
        try {
          if (await compressed.exists()) await compressed.delete();
        } on FileSystemException {
          // Upload result must not be reported as a network failure.
        }
      }
    }
  }
}
