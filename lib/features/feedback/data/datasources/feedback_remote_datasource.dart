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
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType, {
    FeedbackUploadContext? context,
  });
}

class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  final ApiClient _apiClient;

  const FeedbackRemoteDataSourceImpl(
    this._apiClient, {
    this.prepareFile,
    this.transferClient,
  });
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

    Future<void> save() async {
      guard();
      await context?.saveCheckpoint(Map<String, dynamic>.from(checkpoint));
      guard();
    }

    Map<String, dynamic> body(Response<dynamic> response) {
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw StateError('Invalid upload response');
      }
      return (data['data'] as Map<String, dynamic>?) ?? data;
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
        // The compressor's temporary output must survive restart/OS cache purge.
        final ext = compressed.path.split('.').last.toLowerCase();
        uploadFile = await compressed.copy('${file.path}.prepared.$ext');
        checkpoint['prepared_path'] = uploadFile.path;
        await save();
      } else {
        uploadFile = file;
      }
    }
    final ext = uploadFile.path.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'webm' => 'video/webm',
      _ => contentType,
    };
    final bytes = await uploadFile.length();
    final operationId =
        context?.operationId ??
        DateTime.now().microsecondsSinceEpoch.toString();
    // At most one renewal in a run; persistent generation survives a lost response.
    for (var renewal = 0; renewal < 2; renewal++) {
      guard();
      final generation = checkpoint['generation'] as int? ?? 0;
      checkpoint['generation'] = generation;
      await save();
      final session = body(
        await _apiClient.dio.post<dynamic>(
          '/uploads/sessions',
          data: {
            'purpose': isVideo ? 'FEEDBACK_VIDEO' : 'FEEDBACK_IMAGE',
            'content_type': mime,
            'bytes': bytes,
            'client_operation_id': '$operationId:$generation',
          },
        ),
      );
      guard();
      final uploadId = session['upload_id'] as String;
      checkpoint['upload_id'] = uploadId;
      await save();
      try {
        // Reconcile first, including a PUT or confirmation whose response was lost.
        // The API distinguishes a missing object from a transient inspection error.
        Map<String, dynamic>? verified;
        try {
          context?.onProcessing?.call();
          verified = body(
            await _apiClient.dio.post<dynamic>(
              '/uploads/sessions/$uploadId/complete',
            ),
          );
        } on DioException catch (error) {
          final data = error.response?.data;
          if (data is! Map || data['code'] != 'UPLOAD_OBJECT_MISSING') rethrow;
        }
        guard();
        if (verified == null) {
          final url = session['upload_url'] as String;
          if (session['transport'] == 'proxy') {
            await _apiClient.dio.post<dynamic>(
              url,
              data: FormData.fromMap({
                'file': await MultipartFile.fromFile(
                  uploadFile.path,
                  contentType: DioMediaType.parse(mime),
                ),
              }),
              onSendProgress: (sent, total) {
                guard();
                context?.onProgress?.call(sent, total);
              },
              options: Options(
                sendTimeout: const Duration(minutes: 10),
                receiveTimeout: const Duration(minutes: 2),
              ),
            );
          } else {
            final transfer =
                transferClient ??
                Dio(
                  BaseOptions(
                    connectTimeout: const Duration(seconds: 15),
                    sendTimeout: const Duration(minutes: 10),
                    receiveTimeout: const Duration(seconds: 60),
                  ),
                );
            try {
              await transfer.put<dynamic>(
                url,
                data: uploadFile.openRead(),
                onSendProgress: (sent, total) {
                  guard();
                  context?.onProgress?.call(sent, total);
                },
                options: Options(
                  headers: {
                    Headers.contentTypeHeader: mime,
                    Headers.contentLengthHeader: bytes,
                  },
                ),
              );
            } finally {
              if (transferClient == null) transfer.close();
            }
          }
          guard();
          context?.onProcessing?.call();
          verified = body(
            await _apiClient.dio.post<dynamic>(
              '/uploads/sessions/$uploadId/complete',
            ),
          );
        }
        guard();
        return ManagedFeedbackUpload(
          uploadId: uploadId,
          fileUrl: verified['file_url'] as String,
        );
      } on DioException catch (error) {
        final data = error.response?.data;
        final code = data is Map ? data['code'] : null;
        final urlExpiry = DateTime.tryParse(
          session['presigned_expires_at'] as String? ?? '',
        );
        final expiredUrl =
            session['transport'] != 'proxy' &&
            error.response?.statusCode == 403 &&
            ((urlExpiry != null && !urlExpiry.isAfter(DateTime.now())) ||
                (data is String &&
                    data.contains('<Code>ExpiredRequest</Code>')));
        if (expiredUrl && renewal == 0) {
          // Renew the capability for the same object. Reconcile before another PUT.
          continue;
        }
        if (code != 'UPLOAD_EXPIRED' || renewal == 1) rethrow;
        checkpoint['generation'] = generation + 1;
        checkpoint.remove('upload_id');
        await save();
      }
    }
    throw StateError('Upload renewal exhausted');
  }
}
