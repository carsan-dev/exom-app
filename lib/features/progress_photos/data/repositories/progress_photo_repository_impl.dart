import 'dart:io';

import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/features/progress_photos/data/datasources/progress_photo_remote_datasource.dart';
import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';
import 'package:exom_app/features/progress_photos/domain/repositories/progress_photo_repository.dart';

class ProgressPhotoRepositoryImpl implements ProgressPhotoRepository {
  const ProgressPhotoRepositoryImpl(this._remote);

  final ProgressPhotoRemoteDataSource _remote;

  @override
  Future<List<ProgressPhotoSession>> getHistory({int page = 1, int limit = 20}) =>
      _remote.getHistory(page: page, limit: limit);

  @override
  Future<ProgressPhotoSession> createSession({
    required String civilDate,
    required String operationId,
  }) => _remote.createSession(civilDate: civilDate, operationId: operationId);

  @override
  Future<ManagedUploadResult> uploadPhoto(
    File file,
    String contentType, {
    required ManagedUploadContext context,
  }) => _remote.uploadPhoto(file, contentType, context: context);

  @override
  Future<ProgressPhoto> associatePhoto({
    required String sessionId,
    required String uploadId,
    required String view,
    required String operationId,
    String? replacesPhotoId,
  }) => _remote.associatePhoto(
    sessionId: sessionId,
    uploadId: uploadId,
    view: view,
    operationId: operationId,
    replacesPhotoId: replacesPhotoId,
  );
}
