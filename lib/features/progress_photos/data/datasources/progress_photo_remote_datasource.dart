import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';

abstract class ProgressPhotoRemoteDataSource {
  Future<ProgressPhotoHistory> getHistory({int page = 1, int limit = 20});
  Future<ProgressPhotoSession> getSession(String sessionId);
  Future<ProgressPhotoSession> createSession({
    required String civilDate,
    required String operationId,
  });
  Future<ManagedUploadResult> uploadPhoto(
    File file,
    String contentType, {
    required ManagedUploadContext context,
  });
  Future<ProgressPhoto> associatePhoto({
    required String sessionId,
    required String uploadId,
    required String view,
    required String operationId,
    String? replacesPhotoId,
  });
}

class ProgressPhotoRemoteDataSourceImpl implements ProgressPhotoRemoteDataSource {
  ProgressPhotoRemoteDataSourceImpl(
    this._apiClient, {
    ManagedUploadTransport? managedUploadTransport,
  }) : _managedUploadTransport =
           managedUploadTransport ?? ManagedUploadTransport(_apiClient);

  final ApiClient _apiClient;
  final ManagedUploadTransport _managedUploadTransport;

  Map<String, dynamic> _body(Response<dynamic> response) {
    final value = response.data;
    if (value is! Map<String, dynamic>) throw StateError('Invalid API response');
    return (value['data'] as Map<String, dynamic>?) ?? value;
  }

  @override
  Future<ProgressPhotoHistory> getHistory({int page = 1, int limit = 20}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/progress-photos/sessions',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = _body(response);
    final sessions = ((data['data'] as List?) ?? const [])
        .whereType<Map>()
        .map((session) => ProgressPhotoSession.fromJson(Map<String, dynamic>.from(session)))
        .toList(growable: false);
    return ProgressPhotoHistory(
      sessions: sessions,
      total: data['total'] as int? ?? sessions.length,
      page: data['page'] as int? ?? page,
      limit: data['limit'] as int? ?? limit,
      totalPages: data['totalPages'] as int? ?? 1,
    );
  }

  @override
  Future<ProgressPhotoSession> getSession(String sessionId) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/progress-photos/sessions/$sessionId',
    );
    return ProgressPhotoSession.fromJson(_body(response));
  }

  @override
  Future<ProgressPhotoSession> createSession({
    required String civilDate,
    required String operationId,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/progress-photos/sessions',
      data: {'session_date': civilDate, 'operation_id': operationId},
    );
    return ProgressPhotoSession.fromJson(_body(response));
  }

  @override
  Future<ManagedUploadResult> uploadPhoto(
    File file,
    String contentType, {
    required ManagedUploadContext context,
  }) => _managedUploadTransport.upload(
    file: file,
    contentType: contentType,
    purpose: 'PROGRESS_PHOTO',
    context: context,
  );

  @override
  Future<ProgressPhoto> associatePhoto({
    required String sessionId,
    required String uploadId,
    required String view,
    required String operationId,
    String? replacesPhotoId,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/progress-photos/sessions/$sessionId/photos',
      data: {
        'upload_id': uploadId,
        'view': view,
        'operation_id': operationId,
        'replaces_photo_id': ?replacesPhotoId,
      },
    );
    return ProgressPhoto.fromJson(_body(response));
  }
}
