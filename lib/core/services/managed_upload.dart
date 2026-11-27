import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';

/// API code for a replayed `client_operation_id` whose bytes or MIME differ.
/// The server keeps that operation forever, so only a new generation recovers.
const managedUploadOperationConflict = 'UPLOAD_OPERATION_CONFLICT';

/// Persisted per upload checkpoint; counts automatic conflict renewals.
const managedUploadConflictRenewalsKey = 'operation_conflict_renewals';

/// Automatic conflict renewals allowed before the queue needs the owner.
const maxManagedUploadConflictRenewals = 3;

/// Local queue code once automatic conflict renewals are exhausted.
const managedUploadConflictExhausted = 'upload_operation_conflict_exhausted';

/// True only for a 409 operation conflict answered by `POST /uploads/sessions`.
/// The same body from `complete`, a transfer or any other endpoint is not
/// proof that this operation must move to a new generation.
bool isManagedUploadOperationConflict(Object error) {
  if (error is! DioException || error.response?.statusCode != 409) {
    return false;
  }
  final data = error.response?.data;
  if (data is! Map || data['code'] != managedUploadOperationConflict) {
    return false;
  }
  final options = error.requestOptions;
  if (options.method.toUpperCase() != 'POST') return false;
  String path;
  try {
    // Joins baseUrl with relative paths; absolute paths win unchanged.
    path = options.uri.path;
  } on FormatException {
    path = Uri.tryParse(options.path)?.path ?? options.path;
  }
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path == 'uploads/sessions' || path.endsWith('/uploads/sessions');
}

/// Moves [checkpoint] to a fresh upload generation after an operation
/// conflict. Keeps `prepared_path` (the artifact stays owned by the row) and
/// drops metadata bound to the conflicting generation. Returns false, leaving
/// [checkpoint] untouched, once the persisted renewal bound is reached.
bool renewManagedUploadAfterConflict(Map<String, dynamic> checkpoint) {
  final previous = checkpoint[managedUploadConflictRenewalsKey];
  final renewals = previous is int ? previous : 0;
  if (renewals >= maxManagedUploadConflictRenewals) return false;
  final generation = checkpoint['generation'];
  checkpoint
    ..['generation'] = (generation is int ? generation : 0) + 1
    ..[managedUploadConflictRenewalsKey] = renewals + 1
    ..['phase'] = 'operation_conflict'
    ..remove('upload_id')
    ..remove('file_url')
    ..remove('session_attempted')
    ..remove('prepared_content_type')
    ..remove('prepared_bytes');
  return true;
}

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
    Future<({File file, String contentType})> Function()? prepareFile,
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
        final verified = body(
          await _apiClient.dio.post<dynamic>('/uploads/sessions/$uploadId/complete'),
        );
        guard();
        return verified;
      } on DioException catch (error) {
        guard();
        final data = error.response?.data;
        if (data is Map && data['code'] == 'UPLOAD_OBJECT_MISSING') return null;
        rethrow;
      }
    }

    Future<ManagedUploadResult> confirmed(String uploadId, Map<String, dynamic> verified) async {
      guard();
      checkpoint['file_url'] = verified['file_url'] as String;
      await save('completion_confirmed');
      return ManagedUploadResult(uploadId: uploadId, fileUrl: checkpoint['file_url'] as String);
    }

    guard();
    ({File file, String contentType})? prepared;
    int? preparedBytes;
    for (var renewal = 0; renewal < 2; renewal++) {
      guard();
      var generation = checkpoint['generation'] as int? ?? 0;
      final phase = checkpoint['phase'] as String?;
      final sessionMayExist =
          checkpoint['session_attempted'] == true ||
          (checkpoint['upload_id'] as String?)?.isNotEmpty == true ||
          (phase != null &&
              !const [
                'prepared',
                'preparation_changed',
                'session_expired',
                'operation_conflict',
              ].contains(phase));
      checkpoint['generation'] = generation;
      if (sessionMayExist) checkpoint['session_attempted'] = true;
      Map<String, dynamic>? session;
      var transferring = false;
      // Only this run's create may prove that its own operation conflicts.
      var creatingSession = false;
      try {
        // Remote completion survives missing local bytes and lost preparation metadata.
        final knownId = checkpoint['upload_id'] as String?;
        if (knownId != null && knownId.isNotEmpty) {
          final verified = await reconcile(knownId);
          guard();
          if (verified != null) return await confirmed(knownId, verified);
        }
        Future<void> prepare() async {
          context.onPreparing?.call();
          guard();
          prepared = prepareFile == null
              ? (file: file, contentType: contentType)
              : await prepareFile();
          guard();
          preparedBytes = await prepared!.file.length();
          guard();
        }

        if (prepared == null) {
          await prepare();
          if ((checkpoint['prepared_content_type'] != null &&
                  checkpoint['prepared_content_type'] !=
                      prepared!.contentType) ||
              (checkpoint['prepared_bytes'] != null &&
                  checkpoint['prepared_bytes'] != preparedBytes)) {
            // A create response may have been lost: never reuse that operation
            // with different bytes, even when its upload ID was not saved.
            if (sessionMayExist) generation++;
            checkpoint['generation'] = generation;
            checkpoint.remove('upload_id');
            checkpoint.remove('file_url');
            checkpoint.remove('session_attempted');
            checkpoint.remove('prepared_path');
            checkpoint.remove('prepared_content_type');
            checkpoint.remove('prepared_bytes');
            await save('preparation_changed');
            await prepare();
          }
        }
        final artifact = prepared!;
        checkpoint.addAll({
          'prepared_path': artifact.file.path,
          'prepared_content_type': artifact.contentType,
          'prepared_bytes': preparedBytes,
        });
        await save('prepared');
        final uploadFile = artifact.file;
        final mime = artifact.contentType;
        final bytes = preparedBytes!;
        checkpoint['session_attempted'] = true;
        await save('session_creating');
        creatingSession = true;
        session = body(
          await _apiClient.dio.post<dynamic>(
            '/uploads/sessions',
            data: {
              'purpose': purpose,
              'content_type': mime,
              'bytes': bytes,
              'client_operation_id': '${context.operationId}:$generation',
            },
          ),
        );
        creatingSession = false;
        guard();
        final uploadId = session['upload_id'] as String;
        checkpoint['upload_id'] = uploadId;
        await save('session_created');
        var verified = await reconcile(uploadId);
        guard();
        if (verified == null) {
          await save('transfer_uncertain');
          final uploadUrl = session['upload_url'] as String;
          transferring = true;
          if (session['transport'] == 'proxy') {
            final part = await MultipartFile.fromFile(
              uploadFile.path,
              contentType: DioMediaType.parse(mime),
            );
            guard();
            await _apiClient.dio.post<dynamic>(
              uploadUrl,
              data: FormData.fromMap({'file': part}),
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
            // A private clone preserves caller interceptors without sharing this request's guard.
            final cancellation = CancelToken();
            void transferGuard() {
              try {
                guard();
              } catch (_) {
                cancellation.cancel('upload_session_changed');
                rethrow;
              }
            }
            final guardedTransfer = transfer.clone(
              httpClientAdapter: _GuardedTransferAdapter(transfer.httpClientAdapter, transferGuard),
            );
            try {
              await guardedTransfer.put<dynamic>(
                uploadUrl,
                data: uploadFile.openRead(),
                cancelToken: cancellation,
                onSendProgress: context.onProgress,
                options: Options(
                  headers: {
                    Headers.contentTypeHeader: mime,
                    Headers.contentLengthHeader: bytes,
                  },
                ),
              );
            } finally {
              guardedTransfer.close();
              if (transferClient == null) transfer.close();
            }
          }
          guard();
          transferring = false;
          await save('transfer_completed');
          context.onProcessing?.call();
          guard();
          verified = body(
            await _apiClient.dio.post<dynamic>('/uploads/sessions/$uploadId/complete'),
          );
        }
        return await confirmed(uploadId, verified);
      } on DioException catch (error) {
        guard();
        final data = error.response?.data;
        final code = data is Map ? data['code'] : null;
        final expiry = DateTime.tryParse(session?['presigned_expires_at'] as String? ?? '');
        final expiredUrl =
            transferring &&
            session?['transport'] != 'proxy' &&
            error.response?.statusCode == 403 &&
            ((expiry != null && !expiry.isAfter(DateTime.now())) ||
                (data is String && data.contains('<Code>ExpiredRequest</Code>')));
        if (expiredUrl && renewal == 0) continue;
        if (creatingSession && isManagedUploadOperationConflict(error)) {
          // The server keeps `<operation>:<generation>` with other bytes or
          // MIME forever. Retry once here under a new generation, reusing the
          // prepared artifact; a later conflict is left to the queue's bound.
          if (renewal == 1 || !renewManagedUploadAfterConflict(checkpoint)) {
            rethrow;
          }
          await save('operation_conflict');
          continue;
        }
        if (code != 'UPLOAD_EXPIRED' || renewal == 1) rethrow;
        checkpoint['generation'] = generation + 1;
        checkpoint.remove('upload_id');
        checkpoint.remove('file_url');
        checkpoint.remove('session_attempted');
        // Preparation metadata is immutable only within this upload generation.
        checkpoint.remove('prepared_content_type');
        checkpoint.remove('prepared_bytes');
        await save('session_expired');
      }
    }
    throw StateError('Upload renewal exhausted');
  }
}

class _GuardedTransferAdapter implements HttpClientAdapter {
  const _GuardedTransferAdapter(this.delegate, this.guard);

  final HttpClientAdapter delegate;
  final void Function() guard;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    guard();
    return delegate.fetch(
      options,
      requestStream?.map((chunk) {
        guard();
        return chunk;
      }),
      cancelFuture,
    );
  }

  // The original client owns this adapter, including concurrent transfers.
  @override
  void close({bool force = false}) {}
}
