import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';

class ManagedUploadResult {
  const ManagedUploadResult({required this.uploadId, required this.fileUrl});

  final String uploadId;
  final String fileUrl;
}

/// Durable stage updates, while byte progress remains deliberately in-memory.
class ManagedUploadContext {
  const ManagedUploadContext({
    required this.operationId,
    required this.checkpoint,
    required this.saveCheckpoint,
    required this.isCurrent,
    this.onPreparing,
    this.onProcessing,
    this.onProgress,
  });

  final String operationId;
  final Map<String, dynamic> checkpoint;
  final Future<void> Function(Map<String, dynamic>) saveCheckpoint;
  final bool Function() isCurrent;
  final void Function()? onPreparing;
  final void Function()? onProcessing;
  final void Function(int sent, int total)? onProgress;
}

/// Generic managed-upload transport shared by durable media queues.
///
/// Session creation is replayed with the same stable operation ID. Every run
/// reconciles before a PUT, so a lost transfer/completion response cannot make
/// the queue create a second object.
class ManagedUploadTransport {
  const ManagedUploadTransport(this._apiClient, {this.transferClient});

  final ApiClient _apiClient;
  final Dio? transferClient;

  Future<ManagedUploadResult> upload({
    required File file,
    required String contentType,
    required String purpose,
    required ManagedUploadContext context,
  }) async {
    final checkpoint = <String, dynamic>{...context.checkpoint};

    void guard() {
      if (!context.isCurrent()) {
        throw DioException(
          requestOptions: RequestOptions(path: '/uploads/sessions'),
          type: DioExceptionType.cancel,
          message: 'upload_session_changed',
        );
      }
    }

    Future<void> save(String phase) async {
      guard();
      checkpoint['phase'] = phase;
      await context.saveCheckpoint(Map<String, dynamic>.from(checkpoint));
      guard();
    }

    Map<String, dynamic> body(Response<dynamic> response) {
      final data = response.data;
      if (data is! Map<String, dynamic>) throw StateError('Invalid upload response');
      return (data['data'] as Map<String, dynamic>?) ?? data;
    }

    Future<Map<String, dynamic>?> reconcile(String uploadId) async {
      context.onProcessing?.call();
      await save('completion_reconciling');
      try {
        return body(
          await _apiClient.dio.post<dynamic>('/uploads/sessions/$uploadId/complete'),
        );
      } on DioException catch (error) {
        final data = error.response?.data;
        if (data is Map && data['code'] == 'UPLOAD_OBJECT_MISSING') return null;
        rethrow;
      }
    }

    guard();
    context.onPreparing?.call();
    final bytes = await file.length();
    for (var renewal = 0; renewal < 2; renewal++) {
      guard();
      final generation = checkpoint['generation'] as int? ?? 0;
      checkpoint['generation'] = generation;
      await save('session_creating');
      final session = body(
        await _apiClient.dio.post<dynamic>(
          '/uploads/sessions',
          data: {
            'purpose': purpose,
            'content_type': contentType,
            'bytes': bytes,
            'client_operation_id': '${context.operationId}:$generation',
          },
        ),
      );
      guard();
      final uploadId = session['upload_id'] as String;
      checkpoint['upload_id'] = uploadId;
      await save('session_created');
      try {
        var verified = await reconcile(uploadId);
        guard();
        if (verified == null) {
          await save('transfer_uncertain');
          final uploadUrl = session['upload_url'] as String;
          if (session['transport'] == 'proxy') {
            await _apiClient.dio.post<dynamic>(
              uploadUrl,
              data: FormData.fromMap({
                'file': await MultipartFile.fromFile(
                  file.path,
                  contentType: DioMediaType.parse(contentType),
                ),
              }),
              onSendProgress: context.onProgress,
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
                    receiveTimeout: const Duration(minutes: 1),
                  ),
                );
            try {
              await transfer.put<dynamic>(
                uploadUrl,
                data: file.openRead(),
                onSendProgress: context.onProgress,
                options: Options(
                  headers: {
                    Headers.contentTypeHeader: contentType,
                    Headers.contentLengthHeader: bytes,
                  },
                ),
              );
            } finally {
              if (transferClient == null) transfer.close();
            }
          }
          guard();
          await save('transfer_completed');
          context.onProcessing?.call();
          verified = body(
            await _apiClient.dio.post<dynamic>('/uploads/sessions/$uploadId/complete'),
          );
        }
        guard();
        checkpoint['file_url'] = verified['file_url'] as String;
        await save('completion_confirmed');
        return ManagedUploadResult(uploadId: uploadId, fileUrl: checkpoint['file_url'] as String);
      } on DioException catch (error) {
        final data = error.response?.data;
        final code = data is Map ? data['code'] : null;
        final expiry = DateTime.tryParse(session['presigned_expires_at'] as String? ?? '');
        final expiredUrl =
            session['transport'] != 'proxy' &&
            error.response?.statusCode == 403 &&
            ((expiry != null && !expiry.isAfter(DateTime.now())) ||
                (data is String && data.contains('<Code>ExpiredRequest</Code>')));
        if (expiredUrl && renewal == 0) continue;
        if (code != 'UPLOAD_EXPIRED' || renewal == 1) rethrow;
        checkpoint['generation'] = generation + 1;
        checkpoint.remove('upload_id');
        await save('session_expired');
      }
    }
    throw StateError('Upload renewal exhausted');
  }
}
