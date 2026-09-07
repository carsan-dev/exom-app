import 'package:exom_app/core/utils/operation_id.dart';
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/utils/async_mutex.dart';

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
    _progress[notice.id] = notice;
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
  }) async {
    final session = _storage.sessionStamp;
    if (session == null ||
        (expectedSession != null && expectedSession != session)) {
      throw const LocalSessionChanged();
    }
    final id = newOperationId();
    final directory = Directory(
      '${(await _applicationSupportDirectory()).path}/feedback_uploads',
    );
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

  Future<void> retry(String id) => _storage.withSession(() async {
    var changed = false;
    await _mutateById(id, (item) {
      if (!canRetry(item)) return item;
      changed = true;
      return {
        ...item,
        'status': 'queued',
        'attempts': 0,
        'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null,
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

  Future<void> discard(String id) async {
    final item = await _queueMutex.protect(() async {
      final queue = _storage.getFeedbackUploadQueue();
      final index = queue.indexWhere((entry) => entry['id'] == id);
      if (index < 0) return null;
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
    if (item == null) return;
    if (item['already_confirmed'] == true) {
      await _mutateById(id, (current) => {...current, 'dismissed': true});
      return;
    }
    await _offlineSync.removeActionsDependingOnFeedback(id);
    try {
      final filePath = item['file_path'] as String?;
      if (filePath != null) {
        await _deleteFile(filePath);
      }
      final prepared =
          (item['upload_checkpoint'] as Map?)?['prepared_path'] as String?;
      if (prepared != null && prepared != filePath) await _deleteFile(prepared);
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
      final queue = _storage.getFeedbackUploadQueue()
        ..removeWhere((entry) => entry['id'] == id);
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
      for (final item in _storage.getFeedbackUploadQueue().where(
        (item) => item['discard_requested'] == true,
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
        if (item == null) break;
        final id = item['id'] as String;
        final file = File(item['file_path'] as String);
        final exists = await file.exists();
        if (!current()) break;
        if (!exists) {
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

        try {
          final savedUploadId = item['verified_upload_id'] as String?;
          final savedUrl = item['verified_file_url'] as String?;
          final upload = savedUploadId != null && savedUrl != null
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
          );
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
            await _deleteFile(file.path);
            final checkpoint =
                _storage.getFeedbackUploadQueue().firstWhere(
                      (entry) => entry['id'] == id,
                    )['upload_checkpoint']
                    as Map?;
            final prepared = checkpoint?['prepared_path'];
            if (prepared is String && prepared != file.path) {
              await _deleteFile(prepared);
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
              return {...current, 'upload_checkpoint': checkpoint}
                ..remove('verified_upload_id')
                ..remove('verified_file_url');
            });
          }
          final retryable =
              expired ||
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
                'last_error': errorData is Map && errorData['code'] is String
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
                'last_error': error is DioException
                    ? 'network_${error.type.name}_${error.response?.statusCode ?? 0}'
                    : 'upload_local_failure',
              },
            );

            _report(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.queued));
          }
        }
      }
    } finally {
      _processing = false;
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
        await _deleteFile(path);
        final prepared = (item['upload_checkpoint'] as Map?)?['prepared_path'];
        if (prepared is String && prepared != path) await _deleteFile(prepared);
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
                item['cleanup_pending'] == false) {
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
        if (path != null) await _deleteFile(path);
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
