import 'dart:io';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/utils/image_compressor.dart';
import 'package:exom_app/core/utils/video_compressor.dart';
import 'package:exom_app/features/feedback/data/models/feedback_model.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';

abstract class FeedbackRemoteDataSource {
  Future<List<FeedbackModel>> getMyFeedback();
  Future<FeedbackModel> createFeedback({
    required String mediaType,
    required String mediaUrl,
    String? uploadId,
    String? notes,
    String? exerciseId,
    String? clientUploadId,
    String? feedbackKind,
    String? trainingId,
    String? trainingExerciseId,
    String? assignmentDate,
  });
  Future<ManagedFeedbackUpload> uploadMedia(File file, String contentType);
}

class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  final ApiClient _apiClient;

  const FeedbackRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<FeedbackModel>> getMyFeedback() async {
    final response = await _apiClient.dio.get<dynamic>('/feedback/my');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final wrapper = data['data'];
      if (wrapper is Map<String, dynamic>) {
        final items = wrapper['data'];
        if (items is List) {
          return items
              .map((e) => FeedbackModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      if (wrapper is List) {
        return wrapper
            .map((e) => FeedbackModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<FeedbackModel> createFeedback({
    required String mediaType,
    required String mediaUrl,
    String? uploadId,
    String? notes,
    String? exerciseId,
    String? clientUploadId,
    String? feedbackKind,
    String? trainingId,
    String? trainingExerciseId,
    String? assignmentDate,
  }) async {
    final body = <String, dynamic>{
      'media_type': mediaType,
      if (uploadId != null && uploadId.isNotEmpty) 'upload_id': uploadId,
      if (uploadId == null || uploadId.isEmpty) 'media_url': mediaUrl,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (exerciseId != null && exerciseId.isNotEmpty)
        'exercise_id': exerciseId,
      if (clientUploadId != null && clientUploadId.isNotEmpty)
        'client_upload_id': clientUploadId,
      'feedback_kind': ?feedbackKind,
      'training_id': ?trainingId,
      'training_exercise_id': ?trainingExerciseId,
      'assignment_date': ?assignmentDate,
    };
    final response = await _apiClient.dio.post<dynamic>(
      '/feedback',
      data: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return FeedbackModel.fromJson(inner);
      }
    }
    throw Exception('Invalid create feedback response');
  }

  @override
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType,
  ) async {
    final isImage = contentType.startsWith('image/');
    final isVideo = contentType.startsWith('video/');
    final File uploadFile;
    if (isImage) {
      uploadFile = await ImageCompressor.compress(file);
    } else if (isVideo) {
      uploadFile = await VideoCompressor.compress(file);
    } else {
      uploadFile = file;
    }
    final ext = uploadFile.path.split('.').last.toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileKey = 'feedback/$timestamp.$ext';
    final uploadContentType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' when isImage => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'webm' when isVideo => 'video/webm',
      _ => contentType,
    };

    try {
      try {
        final bytes = await uploadFile.length();
        final presignedResponse = await _apiClient.dio.post<dynamic>(
          '/uploads/sessions',
          data: {
            'purpose': isVideo ? 'FEEDBACK_VIDEO' : 'FEEDBACK_IMAGE',
            'content_type': uploadContentType,
            'bytes': bytes,
          },
        );
        final responseData = presignedResponse.data as Map<String, dynamic>;
        final presigned =
            (responseData['data'] as Map<String, dynamic>?) ?? responseData;
        final uploadId = presigned['upload_id'] as String;
        await Dio().put<dynamic>(
          presigned['upload_url'] as String,
          data: uploadFile.openRead(),
          options: Options(
            headers: {
              Headers.contentTypeHeader: uploadContentType,
              Headers.contentLengthHeader: bytes,
            },
          ),
        );
        final completeResponse = await _apiClient.dio.post<dynamic>(
          '/uploads/sessions/$uploadId/complete',
        );
        final completeData = completeResponse.data as Map<String, dynamic>;
        final completed =
            (completeData['data'] as Map<String, dynamic>?) ?? completeData;
        return ManagedFeedbackUpload(
          uploadId: uploadId,
          fileUrl: completed['file_url'] as String,
        );
      } on DioException {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            uploadFile.path,
            filename: '$timestamp.$ext',
            contentType: DioMediaType.parse(uploadContentType),
          ),
          'file_key': fileKey,
          'content_type': uploadContentType,
        });
        final response = await _apiClient.dio.post<dynamic>(
          '/uploads/file',
          data: formData,
        );

        final payload = response.data;
        if (payload is! Map<String, dynamic>) {
          throw Exception('Invalid upload response');
        }
        final result = (payload['data'] as Map<String, dynamic>?) ?? payload;
        return ManagedFeedbackUpload(
          uploadId: result['upload_id'] as String,
          fileUrl: result['file_url'] as String,
        );
      }
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final message = statusCode == null
          ? 'No se pudo subir el archivo. Revisa tu conexion e intentalo de nuevo.'
          : 'No se pudo completar la subida del archivo ($statusCode).';
      throw Exception(message);
    } finally {
      if (uploadFile.absolute.path != file.absolute.path) {
        try {
          if (await uploadFile.exists()) await uploadFile.delete();
        } on FileSystemException {
          // Cleanup failure is local and must not turn success into retry.
        }
      }
    }
  }
}
