import 'package:exom_app/core/utils/operation_id.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/utils/async_mutex.dart';
import 'package:exom_app/core/utils/feedback_preparation_files.dart';

enum FeedbackUploadNoticeKind {
  queued,
  uploading,
  preparing,
  processing,
  completed,
  failed,
  discarded,
}

class FeedbackUploadNotice {
  final String id;
  final FeedbackUploadNoticeKind kind;
  final int? sentBytes;
  final int? totalBytes;

  const FeedbackUploadNotice(
    this.id,
    this.kind, {
    this.sentBytes,
    this.totalBytes,
  });
}

class FeedbackUploadQueueService {
  final FeedbackRepository _repository;
  final LocalStorage _storage;
  final OfflineSyncService _offlineSync;
  final bool Function() _isAuthenticated;
  final Future<Directory> Function() _applicationSupportDirectory;
  final Future<void> Function(String) _deleteFile;
  final Stream<bool> _connectivityChanges;
  final StreamController<FeedbackUploadNotice> _notices =
      StreamController<FeedbackUploadNotice>.broadcast();
  static final AsyncMutex _queueMutex = AsyncMutex();
  static final AsyncMutex _runnerMutex = AsyncMutex();

  bool _processing = false;
  bool _initialized = false;
  Timer? _timer;
  StreamSubscription<bool>? _connectivitySubscription;
  final Map<String, FeedbackUploadNotice> _progress = {};

  FeedbackUploadNotice? progressOf(String id) => _progress[id];

  void _report(FeedbackUploadNotice notice) {
    _storage.guardSession();
    final previous = _progress[notice.id];
    _progress[notice.id] = notice;
    // The UI shows whole percentages; retain exact bytes without rebuilding per chunk.
    final total = notice.totalBytes;
    final sent = notice.sentBytes;
    final previousSent = previous?.sentBytes;
    if (notice.kind == FeedbackUploadNoticeKind.uploading &&
        previous?.kind == notice.kind &&
        total != null &&
        total > 0 &&
        previous?.totalBytes == total &&
        sent != null &&
        previousSent != null &&
        sent * 100 ~/ total == previousSent * 100 ~/ total) {
      return;
    }
    if (!_notices.isClosed) _notices.add(notice);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _connectivitySubscription?.cancel();
    await _notices.close();
  }

  FeedbackUploadQueueService(
    this._repository,
    this._storage,
    this._offlineSync, {
    bool Function()? isAuthenticated,
    Future<Directory> Function()? applicationSupportDirectory,
    Future<void> Function(String)? deleteFile,
    Stream<bool>? connectivityChanges,
  }) : _isAuthenticated =
           isAuthenticated ?? (() => FirebaseAuth.instance.currentUser != null),
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory,
       _deleteFile = deleteFile ?? _deleteExistingFile,
       _connectivityChanges =
           connectivityChanges ??
           Connectivity().onConnectivityChanged.map(
             (results) =>
                 results.any((result) => result != ConnectivityResult.none),
           );

  bool get hasUnattributedData => _storage.hasUnattributedData;

  Stream<FeedbackUploadNotice> get notices => _notices.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _connectivitySubscription = _connectivityChanges.distinct().listen((
      connected,
    ) {
      if (connected) {
        unawaited(_processAfterReconnect());
      }
    });
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(processQueue()),
    );
    await processQueue();
  }

  Future<String> enqueue({
    required File file,
    String? expectedSession,
    required String contentType,
    required String mediaType,
    String? notes,
    String? exerciseId,
    String? feedbackKind,
    String? trainingId,
    String? trainingExerciseId,
    String? assignmentDate,
    String? sessionId,
  }) async {
    final session = _storage.sessionStamp;
    if (session == null ||
        (expectedSession != null && expectedSession != session)) {
      throw const LocalSessionChanged();
    }
    final id = newOperationId();
    final support = await _applicationSupportDirectory();
    await FeedbackPreparationFiles.rejectSource(file, support: support);
    final directory = Directory('${support.path}/feedback_uploads');
    await directory.create(recursive: true);
    final extension = file.path.split('.').last.toLowerCase();
    final stableFile = await file.copy('${directory.path}/$id.$extension');
    if (_storage.sessionStamp != session) {
      throw StateError('Session changed during preparation');
    }
    await _queueMutex.protect(() async {
      if (_storage.sessionStamp != session) throw StateError('Session changed');
      final queue = _storage.getFeedbackUploadQueue();
      queue.add({
        'id': id,
        ..._storage.queueIdentity,
        'file_path': stableFile.path,
        'content_type': contentType,
        'media_type': mediaType,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (exerciseId != null && exerciseId.isNotEmpty)
          'exercise_id': exerciseId,
        'feedback_kind': ?feedbackKind,
        'training_id': ?trainingId,
        'training_exercise_id': ?trainingExerciseId,
        'assignment_date': ?assignmentDate,
        'training_session_id': ?sessionId,
        'status': 'queued',
        'attempts': 0,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _storage.saveFeedbackUploadQueue(queue);
    });
    _report(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.queued));
    unawaited(processQueue());
    return id;
  }

  static bool canRetry(Map<String, dynamic> item) =>
      (item['status'] == 'failed' || item['status'] == 'queued') &&
      item['discard_requested'] != true;

  /// Local code once automatic operation-conflict renewals are exhausted.
  static const operationConflictExhausted = managedUploadConflictExhausted;

  Future<void> retry(String id) => _storage.withSession(() async {
    var changed = false;
    await _mutateById(id, (item) {
      if (!canRetry(item)) return item;
      changed = true;
      final verifiedUploadId = item['verified_upload_id'] as String?;
      // The conflicting `<id>:<generation>` is permanent on the server, so an
      // explicit retry starts a new generation and a new renewal bound.
      final conflicted =
          item['status'] == 'failed' &&
          (verifiedUploadId == null || verifiedUploadId.isEmpty) &&
          (item['last_error'] == managedUploadOperationConflict ||
              item['last_error'] == operationConflictExhausted);
      Map<String, dynamic>? checkpoint;
      if (conflicted) {
        checkpoint = Map<String, dynamic>.from(
          item['upload_checkpoint'] as Map? ?? {},
        )..[managedUploadConflictRenewalsKey] = 0;
        renewManagedUploadAfterConflict(checkpoint);
      }
      return {
        ...item,
        'status': 'queued',
        'attempts': 0,
        'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null,
        'upload_checkpoint': ?checkpoint,
      };
    });
    if (!changed) return;
    _report(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.queued));
    await processQueue();
  });

  List<Map<String, dynamic>> get pendingItems => _storage
      .getFeedbackUploadQueue()
      .where((item) => item['dismissed'] != true)
      .toList();

  Future<void> discard(String id) => _storage.withSession(() => _discard(id));

  Future<void> _discard(String id) async {
    final item = await _queueMutex.protect(() async {
      final queue = _storage.getFeedbackUploadQueue();
      final index = queue.indexWhere((entry) => entry['id'] == id);
      if (index < 0) return null;
      if (queue[index]['discard_cleanup_complete'] == true) return null;
      if (queue[index]['status'] == 'completed') {
        return {...queue[index], 'already_confirmed': true};
      }
      if (queue[index]['status'] == 'uploading' ||
          queue[index]['status'] == 'processing') {
        throw StateError(
          'Espera a que termine la operación en curso antes de descartar',
        );
      }
      final claimed = {
        ...queue[index],
        'status': 'discarding',
        'discard_requested': true,
      };
      queue[index] = claimed;
      await _storage.saveFeedbackUploadQueue(queue);
      return claimed;
    });
    if (item == null || item['discard_cleanup_complete'] == true) return;
    if (item['already_confirmed'] == true) {
      await _mutateById(id, (current) => {...current, 'dismissed': true});
      return;
    }
    if (item.containsKey(feedbackPreparationAttempts)) {
      final token = await _maintenanceToken();
      if (token == null) return;
      try {
        await _sweepWithLease(token);
        final matches = _storage
            .getFeedbackUploadQueue()
            .where((row) => row['id'] == id)
            .toList();
        if (matches.length != 1) return;
        final current = matches.single;
        final journal = current[feedbackPreparationAttempts];
        if (_storage.rawFeedbackOperationCount(id) != 1) return;
        if (journal != null ||
            current.containsKey(feedbackPreparationAttempts)) {
          final attempts = _readJournal(current);
          if (attempts == null ||
              attempts.any(
                (attempt) =>
                    attempt.compressed == 'unadopted' ||
                    attempt.prepared == 'unadopted',
              )) {
            return;
          }
        }
        await _finishDiscard(id, current, token: token);
      } finally {
        await FeedbackPreparationFiles.release(token);
      }
      return;
    }
    await _finishDiscard(id, item);
  }

  Future<void> _finishDiscard(
    String id,
    Map<String, dynamic> item, {
    String? token,
  }) async {
    if (item['discard_cleanup_complete'] == true) return;
    await _offlineSync.removeActionsDependingOnFeedback(id);
    _storage.guardSession();
    final filePath = item['file_path'] as String?;
    final prepared =
        (item['upload_checkpoint'] as Map?)?['prepared_path'] as String?;
    FeedbackPreparationAttempt? deletedAttempt;
    try {
      if (filePath != null) {
        await _deleteSource(filePath);
      }
      if (prepared != null && prepared != filePath) {
        deletedAttempt = await _deletePrepared(item, prepared, token: token);
      }
    } on FileSystemException catch (error) {
      await _mutateById(
        id,
        (current) => {
          ...current,
          'status': 'failed',
          'last_error': 'cleanup_failed: $error',
        },
      );
      rethrow;
    }
    await _queueMutex.protect(() async {
      final queue = _storage.getFeedbackUploadQueue();
      final index = queue.indexWhere((entry) => entry['id'] == id);
      if (index < 0) return;
      final journal = queue[index][feedbackPreparationAttempts];
      // A checkpoint save may have thrown after adoption. Keep other adopted
      // leaves and their provenance, even if this discard settled its source.
      final adopted = journal is List
          ? journal.where((raw) {
              final attempt = _readAttempt(raw, queue[index]);
              return attempt?.prepared == 'adopted' &&
                  attempt?.attempt != deletedAttempt?.attempt;
            }).toList()
          : const [];
      if (adopted.isEmpty) {
        queue.removeAt(index);
      } else {
        queue[index] =
            {
                ...queue[index],
                feedbackPreparationAttempts: adopted,
                'dismissed': true,
                'discard_cleanup_complete': true,
              }
              ..remove('training_session_id')
              ..remove('assignment_date');
      }
      await _storage.saveFeedbackUploadQueue(queue);
    });
    _notices.add(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.discarded));
  }

  Future<void> processQueue() =>
      _storage.withSession(() => _runnerMutex.protect(_processQueueLocked));

  // Match the existing durable error codes, including queues from older builds.
  // Connectivity is not permission to bypass a server's 429/5xx backoff.
  static final _networkFailure = RegExp(
    r'^network_(connectionError|connectionTimeout|receiveTimeout|sendTimeout|unknown)_0$',
  );

  Future<void> _processAfterReconnect() => _storage.withSession(
    () => _runnerMutex.protect(() async {
      // Wait for any in-flight attempt before removing its newly saved delay.
      await _queueMutex.protect(() async {
        final queue = _storage.getFeedbackUploadQueue();
        var changed = false;
        for (var i = 0; i < queue.length; i++) {
          final item = queue[i];
          final error = item['last_error'];
          if (item['status'] != 'queued' ||
              item['discard_requested'] == true ||
              !item.containsKey('next_attempt_at') ||
              error is! String ||
              !_networkFailure.hasMatch(error)) {
            continue;
          }
          queue[i] = Map<String, dynamic>.from(item)..remove('next_attempt_at');
          changed = true;
        }
        if (changed) await _storage.saveFeedbackUploadQueue(queue);
      });
      await _processQueueLocked();
    }),
  );

  Future<void> _processQueueLocked() async {
    if (_processing) return;
    _processing = true;
    final session = _storage.sessionStamp;
    final owner = _storage.ownerId;
    bool current() =>
        session != null &&
        _storage.sessionStamp == session &&
        _isAuthenticated();
    try {
      await _queueMutex.protect(() async {
        final original = _storage.getFeedbackUploadQueue();
        final recovered = original.map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return item['status'] == 'uploading' || item['status'] == 'processing'
              ? {...item, 'status': 'queued'}
              : item;
        }).toList();
        await _storage.saveFeedbackUploadQueue(recovered);
      });
      await _sweepPreparation();
      for (final item in _storage.getFeedbackUploadQueue().where(
        (item) =>
            item['discard_requested'] == true &&
            item['discard_cleanup_complete'] != true,
      )) {
        try {
          await discard(item['id'] as String);
        } on FileSystemException {
          /* durable retry next wake */
        }
      }
      await _retryCompletedCleanup();
      await _cleanupLegacyCompleted();
      if (!current()) return;
      while (true) {
        if (!current()) break;
        final item = await _claimNext();
        if (!current()) break;
        if (item == null) break;
        final id = item['id'] as String;
        final file = File(item['file_path'] as String);
        final exists = await file.exists();
        if (!current()) break;
        final savedUploadId = item['verified_upload_id'] as String?;
        final savedUrl = item['verified_file_url'] as String?;
        final hasVerifiedUpload =
            savedUploadId != null &&
            savedUploadId.isNotEmpty &&
            savedUrl != null &&
            savedUrl.isNotEmpty;
        final checkpoint = item['upload_checkpoint'] as Map?;
        final knownUploadId = checkpoint?['upload_id'] as String?;
        final preparedPath = checkpoint?['prepared_path'] as String?;
        final preparedExists =
            preparedPath != null && await File(preparedPath).exists();
        if (!current()) break;
        if (!exists &&
            !preparedExists &&
            !hasVerifiedUpload &&
            (knownUploadId == null || knownUploadId.isEmpty)) {
          await _mutateById(
            id,
            (current) => {
              ...current,
              'status': 'failed',
              'last_error': 'file_missing',
            },
          );
          _notices.add(
            FeedbackUploadNotice(id, FeedbackUploadNoticeKind.failed),
          );
          continue;
        }

        final attempts = item['attempts'] as int? ?? 1;
        // Upload-session errors are told apart from `/feedback` domain errors.
        var uploadStage = !hasVerifiedUpload;

        try {
          final upload = hasVerifiedUpload
              ? ManagedFeedbackUpload(
                  uploadId: savedUploadId,
                  fileUrl: savedUrl,
                )
              : await _repository.uploadMedia(
                  file,
                  item['content_type'] as String,
                  context: FeedbackUploadContext(
                    operationId: id,
                    checkpoint: Map<String, dynamic>.from(
                      item['upload_checkpoint'] as Map? ?? {},
                    ),
                    saveCheckpoint: (checkpoint) => _mutateById(
                      id,
                      (current) => {
                        ...current,
                        'upload_checkpoint': checkpoint,
                      },
                    ),
                    isCurrent: current,
                    preparationIdentity: owner == null
                        ? null
                        : (owner: owner, environment: _storage.environment),
                    recordPreparation: (attempt) =>
                        _writePreparationAttempt(id, attempt, adopt: false),
                    adoptPreparation: (attempt) =>
                        _writePreparationAttempt(id, attempt, adopt: true),
                    verifyPreparedReference: (path) =>
                        _verifyPreparedReference(id, path),
                    onProgress: (sent, total) => _report(
                      FeedbackUploadNotice(
                        id,
                        FeedbackUploadNoticeKind.uploading,
                        sentBytes: sent,
                        totalBytes: total,
                      ),
                    ),
                    onPreparing: () => _report(
                      FeedbackUploadNotice(
                        id,
                        FeedbackUploadNoticeKind.preparing,
                      ),
                    ),
                    onProcessing: () => _report(
                      FeedbackUploadNotice(
                        id,
                        FeedbackUploadNoticeKind.processing,
                      ),
                    ),
                  ),
                );
          uploadStage = false;
          if (_storage.sessionStamp != session) break;
          if (!current()) {
            await _mutateById(
              id,
              (current) => {...current, 'status': 'queued'},
            );
            break;
          }
          await _mutateById(
            id,
            (current) => {
              ...current,
              'status': 'processing',
              'verified_upload_id': upload.uploadId,
              'verified_file_url': upload.fileUrl,
            },
          );
          if (!current()) break;
          _report(
            FeedbackUploadNotice(id, FeedbackUploadNoticeKind.processing),
          );
          await _repository.createFeedback(
            mediaType: item['media_type'] as String,
            mediaUrl: upload.fileUrl,
            uploadId: upload.uploadId,
            notes: item['notes'] as String?,
            exerciseId: item['exercise_id'] as String?,
            clientUploadId: id,
            feedbackKind: item['feedback_kind'] as String?,
            trainingId: item['training_id'] as String?,
            trainingExerciseId: item['training_exercise_id'] as String?,
            assignmentDate: item['assignment_date'] as String?,
            sessionId: item['training_session_id'] as String?,
          );
          if (_storage.sessionStamp != session) break;
          if (!_isAuthenticated()) {
            await _mutateById(
              id,
              (current) => {...current, 'status': 'queued'},
            );
            break;
          }
          // Commit confirmation before touching the file. A crash from here on
          // retries only cleanup, never transfer or feedback creation.
          await _mutateById(
            id,
            (current) => {
              ...current,
              'status': 'completed',
              'cleanup_pending': true,
              'last_error': null,
            },
          );
          String? cleanupError;
          try {
            await _deleteSource(file.path);
            final persisted = _storage.getFeedbackUploadQueue().firstWhere(
              (entry) => entry['id'] == id,
            );
            final checkpoint = persisted['upload_checkpoint'] as Map?;
            final prepared = checkpoint?['prepared_path'];
            if (prepared is String && prepared != file.path) {
              await _deletePrepared(persisted, prepared);
            }
          } on FileSystemException catch (error) {
            cleanupError = 'cleanup_failed: $error';
          }
          await _mutateById(
            id,
            (current) => {
              ...current,
              'status': 'completed',
              'cleanup_pending': cleanupError != null,
              'last_error': cleanupError,
            },
          );
          _report(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.completed));
          await _offlineSync.syncPendingActions();
        } catch (error) {
          // Confirmation is terminal. Cleanup or a progress wakeup can fail
          // after it; neither may turn a confirmed receipt back into upload work.
          _storage.guardSession();
          final persisted = _storage.getFeedbackUploadQueue().where(
            (row) => row['id'] == id,
          );
          if (persisted.isNotEmpty &&
              persisted.first['status'] == 'completed') {
            _report(
              FeedbackUploadNotice(id, FeedbackUploadNoticeKind.completed),
            );
            continue;
          }
          if (!_isAuthenticated()) {
            await _mutateById(
              id,
              (current) => {...current, 'status': 'queued'},
            );
            break;
          }
          final errorData = error is DioException ? error.response?.data : null;
          final expired =
              errorData is Map && errorData['code'] == 'UPLOAD_EXPIRED';
          if (expired) {
            await _mutateById(id, (current) {
              final checkpoint = Map<String, dynamic>.from(
                current['upload_checkpoint'] as Map? ?? {},
              );
              checkpoint['generation'] =
                  (checkpoint['generation'] as int? ?? 0) + 1;
              checkpoint.remove('upload_id');
              checkpoint.remove('file_url');
              checkpoint.remove('session_attempted');
              checkpoint.remove('prepared_content_type');
              checkpoint.remove('prepared_bytes');
              return {...current, 'upload_checkpoint': checkpoint}
                ..remove('verified_upload_id')
                ..remove('verified_file_url');
            });
          }
          // A conflict that survived the transport's in-run renewal (e.g. an
          // older build also created `<id>:<generation + 1>`) moves to a new
          // generation durably and backs off, up to the persisted bound.
          final operationConflict =
              uploadStage && isManagedUploadOperationConflict(error);
          var conflictRenewed = false;
          if (operationConflict) {
            await _mutateById(id, (current) {
              final checkpoint = Map<String, dynamic>.from(
                current['upload_checkpoint'] as Map? ?? {},
              );
              conflictRenewed = renewManagedUploadAfterConflict(checkpoint);
              return conflictRenewed
                  ? {...current, 'upload_checkpoint': checkpoint}
                  : current;
            });
          }
          // Native cancellation is an interruption; explicit discard is separate.
          final compressionRetryable =
              error is PlatformException &&
              const [
                'compression_timeout',
                'compression_busy',
                'compression_cancelled',
              ].contains(error.code);
          final retryable =
              expired ||
              conflictRenewed ||
              compressionRetryable ||
              error is DioException &&
                  (isOfflineError(error) ||
                      error.response?.statusCode == 429 ||
                      (error.response?.statusCode ?? 0) >= 500);
          // Definitive validation/auth/resource errors require intervention.
          // Recoverable failures back off indefinitely without deleting media.
          if (!retryable) {
            await _mutateById(
              id,
              (current) => {
                ...current,
                'status': 'failed',
                'attempts': attempts,
                'last_failure_phase': _progress[id]?.kind.name ?? 'preparing',
                'last_http_status': error is DioException
                    ? error.response?.statusCode
                    : null,
                'last_error': operationConflict
                    ? operationConflictExhausted
                    : errorData is Map && errorData['code'] is String
                    ? errorData['code']
                    : error is DioException
                    ? 'upload_request_failed'
                    : error.toString(),
              },
            );
            _report(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.failed));
          } else {
            const delays = [30, 120, 600, 3600];
            await _mutateById(
              id,
              (current) => {
                ...current,
                'status': 'queued',
                'attempts': attempts,
                'last_failure_phase': _progress[id]?.kind.name ?? 'preparing',
                'last_http_status': error is DioException
                    ? error.response?.statusCode
                    : null,
                'next_attempt_at': DateTime.now()
                    .toUtc()
                    .add(
                      Duration(
                        seconds:
                            delays[(attempts - 1).clamp(0, delays.length - 1)],
                      ),
                    )
                    .toIso8601String(),
                'last_error': error is PlatformException
                    ? error.code
                    : conflictRenewed
                    ? managedUploadOperationConflict
                    : error is DioException
                    ? 'network_${error.type.name}_${error.response?.statusCode ?? 0}'
                    : 'upload_local_failure',
              },
            );

            _report(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.queued));
          }
        }
      }
    } finally {
      try {
        if (current()) await _sweepPreparation();
      } finally {
        _processing = false;
      }
    }
  }

  Future<Map<String, dynamic>?> _claimNext() {
    return _queueMutex.protect(() async {
      final queue = _storage.getFeedbackUploadQueue();
      final index = queue.indexWhere((item) {
        if (!_storage.ownsEntry(item) || item['discard_requested'] == true) {
          return false;
        }
        if (item['status'] != 'queued') return false;
        final next = DateTime.tryParse(
          item['next_attempt_at'] as String? ?? '',
        );
        return next == null || !next.isAfter(DateTime.now());
      });
      if (index < 0) return null;
      final claimed = {
        ...queue[index],
        'claimed_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'uploading',
        'attempts': (queue[index]['attempts'] as int? ?? 0) + 1,
      };
      queue[index] = claimed;
      await _storage.saveFeedbackUploadQueue(queue);
      _report(
        FeedbackUploadNotice(
          claimed['id'] as String,
          FeedbackUploadNoticeKind.uploading,
        ),
      );
      return Map<String, dynamic>.from(claimed);
    });
  }

  Future<void> _mutateById(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) mutate,
  ) {
    return _queueMutex.protect(() async {
      final queue = _storage.getFeedbackUploadQueue();
      final index = queue.indexWhere((item) => item['id'] == id);
      if (index < 0) return;
      queue[index] = mutate(Map<String, dynamic>.from(queue[index]));
      await _storage.saveFeedbackUploadQueue(queue);
    });
  }

  FeedbackPreparationAttempt? _readAttempt(
    Object? raw,
    Map<String, dynamic> row,
  ) {
    final owner = _storage.ownerId;
    if (owner == null) return null;
    return FeedbackPreparationAttempt.read(
      raw,
      row,
      owner: owner,
      environment: _storage.environment,
    );
  }

  List<FeedbackPreparationAttempt>? _readJournal(Map<String, dynamic> row) {
    final raw = row[feedbackPreparationAttempts];
    if (raw is! List) return null;
    final entries = <FeedbackPreparationAttempt>[];
    final ids = <String>{};
    for (final record in raw) {
      final attempt = _readAttempt(record, row);
      if (attempt == null || !ids.add(attempt.attempt)) return null;
      entries.add(attempt);
    }
    return entries;
  }

  Map<String, dynamic>? _currentPreparationRow(String id) {
    if (_storage.rawFeedbackOperationCount(id) != 1) return null;
    return _storage
        .getFeedbackUploadQueue()
        .where((row) => row['id'] == id)
        .firstOrNull;
  }

  Future<Directory> _preparationSupport() async => Directory(
    await (await _applicationSupportDirectory()).resolveSymbolicLinks(),
  );

  FeedbackPreparationAttempt? _adoptedPreparation(
    Map<String, dynamic> row,
    String path,
    Directory support,
  ) {
    final checkpoint = row['upload_checkpoint'];
    final journal = _readJournal(row);
    if (checkpoint is! Map ||
        checkpoint['prepared_path'] != path ||
        journal == null) {
      return null;
    }
    return journal
        .where(
          (attempt) =>
              attempt.prepared == 'adopted' &&
              path ==
                  '${attempt.directory(support).path}/${attempt.preparedLeaf}',
        )
        .singleOrNull;
  }

  Future<void> _verifyPreparedReference(String id, String path) =>
      _queueMutex.protect(() async {
        _storage.guardSession();
        final support = await _preparationSupport();
        _storage.guardSession();
        final row = _currentPreparationRow(id);
        if (!_isAuthenticated() ||
            row == null ||
            row['status'] != 'uploading' ||
            _adoptedPreparation(row, path, support) == null ||
            await FileSystemEntity.type(path, followLinks: false) !=
                FileSystemEntityType.file ||
            FeedbackPreparationFiles.pathKey(
                  await File(path).resolveSymbolicLinks(),
                ) !=
                FeedbackPreparationFiles.pathKey(path)) {
          throw StateError('Private feedback preparation is not adopted');
        }
      });

  Future<void> _writePreparationAttempt(
    String id,
    FeedbackPreparationAttempt attempt, {
    required bool adopt,
  }) => _queueMutex.protect(() async {
    _storage.guardSession();
    final queue = _storage.getFeedbackUploadQueue();
    final index = queue.indexWhere((row) => row['id'] == id);
    if (!_isAuthenticated() ||
        index < 0 ||
        _storage.rawFeedbackOperationCount(id) != 1 ||
        queue[index]['status'] != 'uploading' ||
        queue[index]['discard_requested'] == true ||
        _readAttempt(attempt.record, queue[index]) == null) {
      throw const LocalSessionChanged();
    }
    final raw = queue[index][feedbackPreparationAttempts];
    if (queue[index].containsKey(feedbackPreparationAttempts) &&
        _readJournal(queue[index]) == null) {
      throw StateError('Unsupported feedback preparation journal');
    }
    final journal = <Object?>[...?raw as List?];
    final matches = journal.indexed
        .where(
          (entry) =>
              entry.$2 is Map &&
              (entry.$2 as Map)['attempt_id'] == attempt.attempt,
        )
        .toList();
    if (adopt) {
      if (matches.length != 1) {
        throw StateError('Feedback preparation intent missing or ambiguous');
      }
      final match = matches.single;
      final original = _readAttempt(match.$2, queue[index]);
      if (original?.prepared != 'unadopted' || original?.kind != attempt.kind) {
        throw StateError('Feedback preparation intent changed');
      }
      journal[match.$1] = {...original!.record, 'prepared': 'adopted'};
    } else {
      if (matches.isNotEmpty) {
        throw StateError('Feedback preparation ID reused');
      }
      journal.add(attempt.record);
    }
    queue[index] = {...queue[index], feedbackPreparationAttempts: journal};
    await _storage.saveFeedbackUploadQueue(queue);
    _storage.guardSession();
  });

  Future<String?> _maintenanceToken() async {
    if (!FeedbackPreparationFiles.supported ||
        _storage.ownerId == null ||
        !_isAuthenticated()) {
      return null;
    }
    try {
      return await FeedbackPreparationFiles.acquireMaintenance();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _sweepPreparation() async {
    final token = await _maintenanceToken();
    if (token == null) return;
    try {
      await _sweepWithLease(token);
    } on FileSystemException {
      // Leave the durable journal for the next idle pass.
    } finally {
      await FeedbackPreparationFiles.release(token);
    }
  }

  Future<Set<String>?> _preparationReferences({
    ({String id, String path})? retiringPrepared,
  }) async {
    final references = <String>{};
    // Snapshot raw references before resolving aliases across awaits.
    final raw = _storage
        .mediaQueueReferenceValues(retiringPrepared: retiringPrepared)
        .toList();
    for (final value in raw) {
      try {
        final uri = Uri.tryParse(value);
        final drivePath =
            Platform.isWindows && value.length > 2 && value[1] == ':';
        if (!drivePath &&
            uri != null &&
            uri.hasAuthority &&
            uri.scheme.isNotEmpty &&
            uri.scheme != 'file') {
          continue;
        }
        final file = uri?.scheme == 'file' ? File.fromUri(uri!) : File(value);
        references.add(FeedbackPreparationFiles.pathKey(file.path));
        references.add(
          FeedbackPreparationFiles.pathKey(await file.resolveSymbolicLinks()),
        );
      } on FileSystemException {
        // A missing path can still veto by its exact, normalized name.
      } on ArgumentError {
        // Remote URLs and invalid local names do not identify an artifact.
      } on UnsupportedError {
        // Malformed local URIs may name a leaf. Retain, without stalling upload.
        return null;
      }
    }
    return references;
  }

  Future<void> _sweepWithLease(String token) => _queueMutex.protect(() async {
    // The lease precedes the snapshot. A publisher cannot adopt a selected
    // leaf between this read and native deletion, including across engines.
    _storage.guardSession();
    if (!_isAuthenticated()) return;
    final queue = _storage.getFeedbackUploadQueue();
    if (!queue.any((row) => row.containsKey(feedbackPreparationAttempts))) {
      return;
    }
    final support = await _preparationSupport();
    final references = await _preparationReferences();
    if (references == null) return;
    var changed = false;
    for (var i = 0; i < queue.length; i++) {
      final row = queue[i];
      final attempts = _readJournal(row);
      final id = row['id'];
      if (attempts == null ||
          id is! String ||
          _storage.rawFeedbackOperationCount(id) != 1) {
        continue;
      }
      final journal = <Object?>[];
      var rowChanged = false;
      for (final attempt in attempts) {
        Future<bool> remove(String leaf) async {
          _storage.guardSession();
          if (!_isAuthenticated() ||
              references.contains(
                FeedbackPreparationFiles.pathKey(
                  '${attempt.directory(support).path}/$leaf',
                ),
              )) {
            return false;
          }
          try {
            return await FeedbackPreparationFiles.remove(token, attempt, leaf);
          } on MissingPluginException {
            return false;
          } on PlatformException {
            return false;
          }
        }

        final compressedRemoved =
            attempt.compressed == 'unadopted' &&
            await remove(FeedbackPreparationAttempt.compressedLeaf);
        final preparedRemoved =
            attempt.prepared == 'unadopted' &&
            await remove(attempt.preparedLeaf);
        if (!compressedRemoved && !preparedRemoved) {
          journal.add(attempt.record);
          continue;
        }
        rowChanged = true;
        final record = {
          ...attempt.record,
          if (compressedRemoved) 'compressed': 'removed',
          if (preparedRemoved) 'prepared': 'removed',
        };
        if (record['compressed'] == 'unadopted' ||
            record['prepared'] != 'removed') {
          journal.add(record);
        }
      }
      if (rowChanged) {
        changed = true;
        queue[i] = {...row};
        if (journal.isEmpty) {
          queue[i].remove(feedbackPreparationAttempts);
        } else {
          queue[i][feedbackPreparationAttempts] = journal;
        }
      }
    }
    _storage.guardSession();
    if (changed) await _storage.saveFeedbackUploadQueue(queue);
  });

  Future<FeedbackPreparationAttempt?> _deletePrepared(
    Map<String, dynamic> row,
    String path, {
    String? token,
  }) async {
    if (!FeedbackPreparationFiles.supported) {
      await _deleteFile(path);
      return null;
    }
    final support = await _preparationSupport();
    if (!await FeedbackPreparationFiles.isPrivateFile(path, support)) {
      _storage.guardSession();
      await _deleteFile(path);
      return null;
    }
    final lease = token ?? await _maintenanceToken();
    const deferred = FileSystemException(
      'Feedback preparation cleanup deferred',
    );
    try {
      final id = row['id'];
      if (lease == null || id is! String) throw deferred;
      return await _queueMutex.protect(() async {
        _storage.guardSession();
        final current = _currentPreparationRow(id);
        if (current == null ||
            (current['status'] != 'completed' &&
                (current['status'] != 'discarding' ||
                    current['discard_requested'] != true))) {
          throw deferred;
        }
        final attempt = _adoptedPreparation(current, path, support);
        if (attempt == null) throw deferred;
        final references = await _preparationReferences(
          retiringPrepared: (id: id, path: path),
        );
        _storage.guardSession();
        if (!_isAuthenticated() ||
            references == null ||
            references.contains(FeedbackPreparationFiles.pathKey(path)) ||
            !await FeedbackPreparationFiles.remove(
              lease,
              attempt,
              attempt.preparedLeaf,
            )) {
          throw deferred;
        }
        return attempt;
      });
    } on MissingPluginException {
      throw deferred;
    } on PlatformException {
      throw deferred;
    } finally {
      if (token == null && lease != null) {
        await FeedbackPreparationFiles.release(lease);
      }
    }
  }

  Future<void> _deleteSource(String path) async {
    if (FeedbackPreparationFiles.supported) {
      final support = await _preparationSupport();
      if (await FeedbackPreparationFiles.isPrivateFile(path, support)) {
        throw const FileSystemException(
          'Private feedback path is not a source',
        );
      }
      _storage.guardSession();
    }
    await _deleteFile(path);
  }

  String? statusOf(String id) {
    final item = _storage.getFeedbackUploadQueue().where(
      (entry) => entry['id'] == id,
    );
    return item.isEmpty ? null : item.first['status'] as String?;
  }

  Future<void> _retryCompletedCleanup() async {
    final pendingCleanup = await _queueMutex.protect(() async {
      return _storage
          .getFeedbackUploadQueue()
          .where(
            (item) =>
                item['status'] == 'completed' &&
                (item['cleanup_pending'] == true ||
                    (item['last_error'] as String? ?? '').startsWith(
                      'cleanup_failed:',
                    )),
          )
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
    });
    for (final item in pendingCleanup) {
      final id = item['id'] as String?;
      final path = item['file_path'] as String?;
      if (id == null || path == null) continue;
      try {
        await _deleteSource(path);
        final prepared = (item['upload_checkpoint'] as Map?)?['prepared_path'];
        if (prepared is String && prepared != path) {
          await _deletePrepared(item, prepared);
        }
        await _mutateById(
          id,
          (current) => {
            ...current,
            'last_error': null,
            'cleanup_pending': false,
          },
        );
      } on FileSystemException catch (error) {
        await _mutateById(
          id,
          (current) => {...current, 'last_error': 'cleanup_failed: $error'},
        );
      }
    }
  }

  Future<void> _cleanupLegacyCompleted() async {
    final expired = await _queueMutex.protect(() async {
      final now = DateTime.now().toUtc();
      return _storage
          .getFeedbackUploadQueue()
          .where((item) {
            if (item['status'] != 'completed' ||
                item.containsKey(feedbackPreparationAttempts) ||
                item['cleanup_pending'] != null ||
                (item['last_error'] as String? ?? '').startsWith(
                  'cleanup_failed:',
                )) {
              return false;
            }
            final queuedAt = DateTime.tryParse(
              item['queued_at'] as String? ?? '',
            );
            return queuedAt != null &&
                now.difference(queuedAt.toUtc()) >= const Duration(hours: 24);
          })
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
    });
    for (final item in expired) {
      if (!_isAuthenticated() && item['status'] != 'completed') continue;
      final id = item['id'] as String?;
      final path = item['file_path'] as String?;
      if (id == null) continue;
      try {
        if (path != null) await _deleteSource(path);
        await _mutateById(
          id,
          (current) => {
            ...current,
            'cleanup_pending': false,
            'last_error': null,
          },
        );
      } on FileSystemException catch (error) {
        await _mutateById(
          id,
          (current) => {
            ...current,
            'status': item['status'] == 'completed' ? 'completed' : 'failed',
            'last_error': 'cleanup_failed: $error',
          },
        );
      }
    }
  }

  static Future<void> _deleteExistingFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
