import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/managed_upload.dart';
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
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType, {
    FeedbackUploadContext? context,
  });
}

class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  const FeedbackRemoteDataSourceImpl(
    this._apiClient, {
    this.prepareFile,
    this.transferClient,
  });

  final ApiClient _apiClient;
  final Future<File> Function(File file, String contentType)? prepareFile;
  final Dio? transferClient;

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
      if (exerciseId != null && exerciseId.isNotEmpty) 'exercise_id': exerciseId,
      if (clientUploadId != null && clientUploadId.isNotEmpty)
        'client_upload_id': clientUploadId,
      'feedback_kind': ?feedbackKind,
      'training_id': ?trainingId,
      'training_exercise_id': ?trainingExerciseId,
      'assignment_date': ?assignmentDate,
    };
    final response = await _apiClient.dio.post<dynamic>('/feedback', data: body);
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return FeedbackModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw StateError('Invalid create feedback response');
  }

  @override
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType, {
    FeedbackUploadContext? context,
  }) async {
    final checkpoint = <String, dynamic>{...?context?.checkpoint};

    void guard() {
      if (context != null && !context.isCurrent()) {
        throw DioException(
          requestOptions: RequestOptions(path: '/uploads/sessions'),
          type: DioExceptionType.cancel,
          message: 'upload_session_changed',
        );
      }
    }

    Future<void> saveCheckpoint(Map<String, dynamic> value) async {
      guard();
      checkpoint
        ..clear()
        ..addAll(value);
      await context?.saveCheckpoint(Map<String, dynamic>.from(checkpoint));
      guard();
    }

    guard();
    context?.onPreparing?.call();
    final isVideo = contentType.startsWith('video/');
    final preparedPath = checkpoint['prepared_path'] as String?;
    File uploadFile;
    if (preparedPath != null && await File(preparedPath).exists()) {
      uploadFile = File(preparedPath);
    } else {
      final compressed = prepareFile != null
          ? await prepareFile!(file, contentType)
          : isVideo
          ? await VideoCompressor.compress(file)
          : contentType.startsWith('image/')
          ? await ImageCompressor.compress(file)
          : file;
      guard();
      if (compressed.absolute.path != file.absolute.path) {
        final extension = compressed.path.split('.').last.toLowerCase();
        uploadFile = await compressed.copy('${file.path}.prepared.$extension');
        checkpoint['prepared_path'] = uploadFile.path;
        await saveCheckpoint(checkpoint);
      } else {
        uploadFile = file;
      }
    }
    final extension = uploadFile.path.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'webm' => 'video/webm',
      _ => contentType,
    };
    final managed = await ManagedUploadTransport(
      _apiClient,
      transferClient: transferClient,
    ).upload(
      file: uploadFile,
      contentType: mime,
      purpose: isVideo ? 'FEEDBACK_VIDEO' : 'FEEDBACK_IMAGE',
      context: ManagedUploadContext(
        operationId: context?.operationId ?? DateTime.now().microsecondsSinceEpoch.toString(),
        checkpoint: checkpoint,
        saveCheckpoint: saveCheckpoint,
        isCurrent: () => context?.isCurrent() ?? true,
        onPreparing: null,
        onProcessing: context?.onProcessing,
        onProgress: context?.onProgress,
      ),
    );
    return ManagedFeedbackUpload(uploadId: managed.uploadId, fileUrl: managed.fileUrl);
  }
}
