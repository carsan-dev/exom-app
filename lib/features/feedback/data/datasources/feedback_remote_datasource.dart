import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/core/utils/feedback_preparation_files.dart';
import 'package:exom_app/core/utils/image_compressor.dart';
import 'package:exom_app/core/utils/operation_id.dart';
import 'package:exom_app/core/utils/video_compressor.dart';
import 'package:exom_app/features/feedback/data/models/feedback_model.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
    String? sessionId,
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
    this.deleteTemporaryFile,
  });

  final ApiClient _apiClient;
  final Future<File> Function(File file, String contentType)? prepareFile;
  final Dio? transferClient;

  /// Deletes a compressor output once its prepared copy exists. Test seam.
  final Future<void> Function(File file)? deleteTemporaryFile;

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
    String? sessionId,
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
      'training_session_id': ?sessionId,
    };
    final response = await _apiClient.dio.post<dynamic>(
      '/feedback',
      data: body,
    );
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
    String? preparationToken;
    FeedbackPreparationAttempt? ownedAttempt;
    String? ownedPreparedPath;

    Future<void> releasePreparation() async {
      final token = preparationToken;
      preparationToken = null;
      ownedAttempt = null;
      ownedPreparedPath = null;
      if (token != null) await FeedbackPreparationFiles.release(token);
    }

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
      final prepared = value['phase'] == 'prepared';
      final attempt = ownedAttempt;
      if (prepared && attempt != null) {
        if (value['prepared_path'] != ownedPreparedPath) {
          throw StateError('Feedback preparation path changed');
        }
        await context!.adoptPreparation!(attempt);
        guard();
      }
      checkpoint
        ..clear()
        ..addAll(value);
      await context?.saveCheckpoint(Map<String, dynamic>.from(checkpoint));
      guard();
      if (prepared) await releasePreparation();
    }

    guard();
    final isVideo = contentType.startsWith('video/');
    final isImage = contentType.startsWith('image/');

    Future<File> prepareLegacy(String? token) async {
      final compressed = prepareFile != null
          ? await prepareFile!(file, contentType)
          : isVideo
          ? await VideoCompressor.compress(file, preparationToken: token)
          : isImage
          ? await ImageCompressor.compress(file)
          : file;
      final compressedPath = compressed.absolute.path;
      final targetPath =
          '${file.path}.prepared.${compressed.path.split('.').last.toLowerCase()}';
      final disposable =
          compressedPath != file.absolute.path &&
          compressedPath != File(targetPath).absolute.path;
      if (token != null && disposable) {
        await FeedbackPreparationFiles.rejectSource(compressed);
      }
      try {
        guard();
        if (compressedPath == file.absolute.path) return file;
        if (token != null &&
            await FileSystemEntity.type(targetPath, followLinks: false) ==
                FileSystemEntityType.link) {
          throw PlatformException(code: 'compression_invalid_input');
        }
        final prepared = disposable
            ? await compressed.copy(targetPath)
            : compressed;
        guard();
        return prepared;
      } finally {
        if (disposable) await _deleteCompressorOutput(compressed);
      }
    }

    Future<({File file, String contentType})> prepare() async {
      // Transport may reject the first artifact and prepare again in a new
      // generation. Its unpublished attempt stays recoverable in the journal.
      await releasePreparation();
      guard();
      if (FeedbackPreparationFiles.supported) {
        preparationToken = await FeedbackPreparationFiles.acquirePreparation();
        guard();
      }
      final preparedPath = checkpoint['prepared_path'] as String?;
      final preparedExists =
          preparedPath != null && await File(preparedPath).exists();
      guard();
      File uploadFile;
      if (preparedExists) {
        if (preparationToken != null) {
          final support = Directory(
            await (await getApplicationSupportDirectory())
                .resolveSymbolicLinks(),
          );
          if (await FeedbackPreparationFiles.isPrivateFile(
            preparedPath,
            support,
          )) {
            final verify = context?.verifyPreparedReference;
            if (verify == null) {
              throw StateError('Private feedback preparation is not adopted');
            }
            await verify(preparedPath);
            guard();
          }
        }
        uploadFile = File(preparedPath);
      } else if (preparationToken case final token?) {
        await FeedbackPreparationFiles.rejectSource(file);
        guard();
        final identity = context?.preparationIdentity;
        if (identity != null &&
            context!.recordPreparation != null &&
            context.adoptPreparation != null &&
            FeedbackPreparationAttempt.validId(context.operationId) &&
            prepareFile == null &&
            (isVideo || isImage)) {
          final attempt = FeedbackPreparationAttempt(
            owner: identity.owner,
            environment: identity.environment,
            operation: context.operationId,
            attempt: newOperationId(),
            source: file.path,
            kind: isVideo ? 'video' : 'image',
          );
          final directory = await FeedbackPreparationFiles.plan(token, attempt);
          guard();
          await context.recordPreparation!(attempt);
          guard();
          await FeedbackPreparationFiles.open(token);
          guard();
          final target = File('${directory.path}/${attempt.preparedLeaf}');
          if (isVideo) {
            final compressed = await VideoCompressor.compress(
              file,
              preparationToken: token,
              ownedOutput: true,
            );
            guard();
            if (compressed.path !=
                '${directory.path}/${FeedbackPreparationAttempt.compressedLeaf}') {
              throw StateError('Unexpected feedback preparation output');
            }
            await target.create(exclusive: true);
            uploadFile = await compressed.copy(target.path);
          } else {
            uploadFile = await ImageCompressor.compressToPreparation(
              file,
              target,
            );
          }
          guard();
          if (uploadFile.path == target.path) {
            ownedAttempt = attempt;
            ownedPreparedPath = target.path;
          }
        } else {
          uploadFile = await prepareLegacy(token);
        }
      } else {
        uploadFile = await prepareLegacy(null);
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
      return (file: uploadFile, contentType: mime);
    }

    try {
      final managed =
          await ManagedUploadTransport(
            _apiClient,
            transferClient: transferClient,
          ).upload(
            file: file,
            contentType: contentType,
            prepareFile: prepare,
            purpose: isVideo ? 'FEEDBACK_VIDEO' : 'FEEDBACK_IMAGE',
            context: ManagedUploadContext(
              operationId:
                  context?.operationId ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              checkpoint: checkpoint,
              saveCheckpoint: saveCheckpoint,
              isCurrent: () => context?.isCurrent() ?? true,
              onPreparing: context?.onPreparing,
              onProcessing: context?.onProcessing,
              onProgress: context?.onProgress,
            ),
          );
      return ManagedFeedbackUpload(
        uploadId: managed.uploadId,
        fileUrl: managed.fileUrl,
      );
    } finally {
      await releasePreparation();
    }
  }

  /// The source file can always be compressed again, so a failed delete only
  /// leaves cache garbage and must not fail or roll back the upload.
  Future<void> _deleteCompressorOutput(File output) async {
    try {
      final delete = deleteTemporaryFile;
      if (delete != null) {
        await delete(output);
      } else if (await output.exists()) {
        await output.delete();
      }
    } on FileSystemException {
      // Non-fatal: the prepared copy and the source remain intact.
    }
  }
}
