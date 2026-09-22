import 'dart:io';

import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';

abstract class ProgressPhotoRepository {
  Future<List<ProgressPhotoSession>> getHistory({int page = 1, int limit = 20});

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
