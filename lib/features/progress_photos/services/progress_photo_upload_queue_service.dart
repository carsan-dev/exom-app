import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/utils/async_mutex.dart';
import 'package:exom_app/core/utils/operation_id.dart';
import 'package:exom_app/features/progress_photos/domain/repositories/progress_photo_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

enum ProgressPhotoEnqueueStage { beforeCopy, afterRename }

typedef ProgressPhotoStagingCopy =
    Future<File> Function(File source, File staging);

/// Owner-scoped durable progress-photo queue. It deliberately has no UI
/// dependency: P2-T5 can observe this service without changing its protocol.
class ProgressPhotoUploadQueueService {
  ProgressPhotoUploadQueueService(
    this._repository,
    this._storage, {
    bool Function()? isAuthenticated,
    Future<Directory> Function()? applicationSupportDirectory,
    Future<void> Function(String)? deleteFile,
    ProgressPhotoStagingCopy? copyToStaging,
    Future<void> Function(ProgressPhotoEnqueueStage stage)? enqueueStage,
    Stream<bool>? connectivityChanges,
  }) : _isAuthenticated =
           isAuthenticated ?? (() => FirebaseAuth.instance.currentUser != null),
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory,
       _deleteFile = deleteFile ?? _deleteExistingFile,
       _copyToStaging = copyToStaging ?? _copyFileToStaging,
       _enqueueStage = enqueueStage,
       _connectivityChanges =
           connectivityChanges ??
           Connectivity().onConnectivityChanged.map(
             (results) => results.any((result) => result != ConnectivityResult.none),
           );

  final ProgressPhotoRepository _repository;
  final LocalStorage _storage;
  final bool Function() _isAuthenticated;
  final Future<Directory> Function() _applicationSupportDirectory;
  final Future<void> Function(String) _deleteFile;
  final ProgressPhotoStagingCopy _copyToStaging;
  final Future<void> Function(ProgressPhotoEnqueueStage stage)? _enqueueStage;
  final Stream<bool> _connectivityChanges;
  static final AsyncMutex _queueMutex = AsyncMutex();
  static final AsyncMutex _runnerMutex = AsyncMutex();

  bool _initialized = false;
  bool _processing = false;
  Timer? _timer;
  StreamSubscription<bool>? _connectivitySubscription;

  List<Map<String, dynamic>> get pendingItems =>
      _storage.getProgressPhotoUploadQueue();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _connectivitySubscription = _connectivityChanges.distinct().listen((connected) {
      if (connected) unawaited(_resumeAfterReconnect());
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(processQueue()));
    await processQueue();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _connectivitySubscription?.cancel();
  }

  /// Persists owner-scoped journal intent before copying media. The final file
  /// is atomically renamed from the indexed staging path before queue promotion.
  Future<String> enqueue({
    required File file,
    required String civilSessionDate,
    required String canonicalView,
    required String contentType,
    String? resolvedSessionId,
    String? replacesPhotoId,
    String? expectedSession,
  }) => _storage.sessionTask(
    () => _enqueue(
      file: file,
      civilSessionDate: civilSessionDate,
      canonicalView: canonicalView,
      contentType: contentType,
      resolvedSessionId: resolvedSessionId,
      replacesPhotoId: replacesPhotoId,
      expectedSession: expectedSession,
    ),
  );

  Future<String> _enqueue({
    required File file,
    required String civilSessionDate,
    required String canonicalView,
    required String contentType,
    String? resolvedSessionId,
    String? replacesPhotoId,
    String? expectedSession,
  }) async {
    final session = _storage.sessionStamp;
    if (session == null || (expectedSession != null && expectedSession != session)) {
      throw const LocalSessionChanged();
    }
    final identity = Map<String, Object?>.from(_storage.progressPhotoQueueIdentity);
    final queueId = newOperationId();
    final root = await _applicationSupportDirectory();
    _requireSession(session);
    final directory = Directory(
      '${root.path}/progress_photo_uploads/v1/${_ownerScope(identity)}',
    );
    // This may create metadata only; no media bytes are written before the
    // following queue record is durable.
    await directory.create(recursive: true);
    _requireSession(session);
    final extension = _safeExtension(file.path);
    final finalFile = File('${directory.path}/$queueId.$extension');
    final stagingFile = File('${directory.path}/$queueId.$extension.part');
    await _queueMutex.protect(() async {
      _requireSession(session);
      final queue = _storage.getProgressPhotoUploadQueue();
      queue.add({
        'id': queueId,
        ...identity,
        'journal_version': 1,
        'file_path': finalFile.path,
        'staging_file_path': stagingFile.path,
        'source_file_path': file.path,
        'content_type': contentType,
        'civil_session_date': civilSessionDate,
        'session_id': ?resolvedSessionId,
        'view': canonicalView,
        'session_operation_id': newOperationId(),
        'upload_operation_id': newOperationId(),
        'association_operation_id': newOperationId(),
        'replaces_photo_id': ?replacesPhotoId,
        'session_checkpoint': {
          'state': resolvedSessionId == null ? 'pending' : 'confirmed',
          'session_id': ?resolvedSessionId,
        },
        'upload_checkpoint': <String, dynamic>{'phase': 'pending'},
        'association_checkpoint': <String, dynamic>{'state': 'pending'},
        'cleanup_checkpoint': <String, dynamic>{'state': 'pending'},
        'staging_checkpoint': <String, dynamic>{'state': 'intent'},
        'status': 'staging',
        'attempts': 0,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _storage.saveProgressPhotoUploadQueue(queue);
      _requireSession(session);
    });
    // A current-owner filtered lookup must never turn a journal handoff into
    // an acknowledgement after another account/session takes ownership.
    _requireSession(session);
    await _stageAndPromote(queueId, session);
    _requireSession(session);
    unawaited(processQueue());
    return queueId;
  }

  Future<void> retry(String id) => _storage.withSession(() async {
    final item = _find(id);
    final session = _storage.sessionStamp;
    if (item?['status'] == 'staging' ||
        (item?['status'] == 'failed' && item?['staging_checkpoint'] is Map)) {
      if (session == null) throw const LocalSessionChanged();
      await _stageAndPromote(id, session);
    } else {
      await _mutate(id, (item) => {
        ...item,
        'status': 'queued',
        'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null,
      });
    }
    await processQueue();
  });

  Future<void> processQueue() =>
      _storage.withSession(() => _runnerMutex.protect(_processLocked));

  Future<void> _resumeAfterReconnect() => _storage.withSession(
    () => _runnerMutex.protect(() async {
      await _queueMutex.protect(() async {
        final queue = _storage.getProgressPhotoUploadQueue();
        var changed = false;
        for (var index = 0; index < queue.length; index++) {
          final item = queue[index];
          if (item['status'] == 'queued' && _isNetworkBackoff(item['last_error'])) {
            queue[index] = Map<String, dynamic>.from(item)..remove('next_attempt_at');
            changed = true;
          }
        }
        if (changed) await _storage.saveProgressPhotoUploadQueue(queue);
      });
      await _processLocked();
    }),
  );

  Future<void> _processLocked() async {
    if (_processing) return;
    _processing = true;
    try {
      final session = _storage.sessionStamp;
      if (session == null) return;
      // Staging recovery is local and owner-scoped, so it must run even while
      // offline. Remote transfer remains gated by authentication below.
      await _recoverInterrupted(session);
      _requireSession(session);
      if (!_isAuthenticated()) return;
      bool current() =>
          _storage.sessionStamp == session && _isAuthenticated();
      await _retryCleanup(session);
      _requireSession(session);
      while (current()) {
        final item = await _claimNext();
        if (item == null) break;
        final id = item['id'] as String;
        final file = File(item['file_path'] as String);
        if (!await file.exists()) {
          await _fail(id, item, 'progress_photo_file_missing', retryable: false);
          continue;
        }
        try {
          final sessionId = await _resolveSession(item, current);
          if (!current()) break;
          final upload = await _repository.uploadPhoto(
            file,
            item['content_type'] as String,
            context: ManagedUploadContext(
              operationId: item['upload_operation_id'] as String,
              checkpoint: Map<String, dynamic>.from(item['upload_checkpoint'] as Map? ?? const {}),
              isCurrent: current,
              saveCheckpoint: (checkpoint) {
                if (!current()) throw const LocalSessionChanged();
                return _mutate(
                  id,
                  (saved) => {...saved, 'upload_checkpoint': checkpoint},
                );
              },
            ),
          );
          if (!current()) break;
          await _mutate(id, (saved) => {
            ...saved,
            'upload_checkpoint': {
              ...(saved['upload_checkpoint'] as Map? ?? const {}),
              'phase': 'completion_confirmed',
              'upload_id': upload.uploadId,
              'file_url': upload.fileUrl,
            },
          });
          await _associate(item, sessionId, upload.uploadId, current);
          if (!current()) break;
          // Confirmation is durable before cleanup. Cleanup is an independent,
          // retryable checkpoint and can never cause another association.
          await _mutate(id, (saved) => {
            ...saved,
            'status': 'completed',
            'cleanup_pending': true,
            'cleanup_checkpoint': {'state': 'pending'},
            'last_error': null,
          });
          await _cleanup(id, file.path, session);
        } catch (error) {
          if (!current()) break;
          final persisted = _find(id);
          if (persisted?['status'] == 'completed') continue;
          await _fail(id, persisted ?? item, error, retryable: _isRetryable(error));
        }
      }
    } finally {
      _processing = false;
    }
  }

  Future<String> _resolveSession(
    Map<String, dynamic> item,
    bool Function() current,
  ) async {
    final existing = item['session_id'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final id = item['id'] as String;
    await _mutate(id, (saved) => {
      ...saved,
      'session_checkpoint': {'state': 'creating'},
    });
    final created = await _repository.createSession(
      civilDate: item['civil_session_date'] as String,
      operationId: item['session_operation_id'] as String,
    );
    if (!current()) throw const LocalSessionChanged();
    await _mutate(id, (saved) => {
      ...saved,
      'session_id': created.id,
      'session_checkpoint': {'state': 'confirmed', 'session_id': created.id},
    });
    return created.id;
  }

  Future<void> _associate(
    Map<String, dynamic> original,
    String sessionId,
    String uploadId,
    bool Function() current,
  ) async {
    final id = original['id'] as String;
    final persisted = _find(id) ?? original;
    if ((persisted['association_checkpoint'] as Map?)?['state'] == 'confirmed') return;
    await _mutate(id, (saved) => {
      ...saved,
      'association_checkpoint': {'state': 'associating'},
    });
    final photo = await _repository.associatePhoto(
      sessionId: sessionId,
      uploadId: uploadId,
      view: original['view'] as String,
      operationId: original['association_operation_id'] as String,
      replacesPhotoId: original['replaces_photo_id'] as String?,
    );
    if (!current()) throw const LocalSessionChanged();
    await _mutate(id, (saved) => {
      ...saved,
      'association_checkpoint': {'state': 'confirmed', 'photo_id': photo.id},
    });
  }

  Future<void> _stageAndPromote(String id, String session) async {
    _requireSession(session);
    final item = _find(id);
    if (item == null) {
      throw StateError('Progress photo staging journal is missing');
    }
    final finalPath = item['file_path'] as String?;
    final stagingPath = item['staging_file_path'] as String?;
    final sourcePath = item['source_file_path'] as String?;
    if (finalPath == null || stagingPath == null || sourcePath == null) {
      await _markStagingFailure(id, 'progress_photo_journal_invalid', session);
      throw StateError('Progress photo staging journal is invalid');
    }
    final finalFile = File(finalPath);
    final stagingFile = File(stagingPath);
    if (await finalFile.exists()) {
      _requireSession(session);
      await _promoteStaged(id, finalFile, session);
      return;
    }
    _requireSession(session);
    await _mutate(
      id,
      (saved) => {
        ...saved,
        'status': 'staging',
        'staging_checkpoint': {'state': 'copying'},
        'last_error': null,
      },
      session: session,
    );
    await _enqueueStage?.call(ProgressPhotoEnqueueStage.beforeCopy);
    _requireSession(session);

    final source = File(sourcePath);
    if (!await source.exists()) {
      _requireSession(session);
      await _markStagingFailure(id, 'progress_photo_source_unavailable', session);
      throw StateError('Progress photo source is unavailable');
    }
    if (await stagingFile.exists()) {
      _requireSession(session);
      await stagingFile.delete();
      _requireSession(session);
    }
    await stagingFile.parent.create(recursive: true);
    _requireSession(session);
    await _copyToStaging(source, stagingFile);
    _requireSession(session);
    await stagingFile.rename(finalFile.path);
    await _enqueueStage?.call(ProgressPhotoEnqueueStage.afterRename);
    _requireSession(session);
    await _promoteStaged(id, finalFile, session);
  }

  Future<void> _promoteStaged(
    String id,
    File finalFile,
    String session,
  ) async {
    _requireSession(session);
    final bytes = await finalFile.length();
    _requireSession(session);
    await _mutate(
      id,
      (saved) => {
        ...saved,
        'bytes': bytes,
        'status': 'queued',
        'staging_checkpoint': {'state': 'queued'},
        'last_error': null,
      },
      session: session,
    );
    _requireSession(session);
  }

  Future<void> _markStagingFailure(
    String id,
    String error,
    String session,
  ) => _mutate(
    id,
    (saved) => {
      ...saved,
      'status': 'failed',
      'staging_checkpoint': {'state': 'source_unavailable'},
      'last_error': error,
    },
    session: session,
  );

  Future<void> _reconcileStaging(String session) async {
    final resumable = <String>[];
    await _queueMutex.protect(() async {
      _requireSession(session);
      final queue = _storage.getProgressPhotoUploadQueue();
      var changed = false;
      for (var index = 0; index < queue.length; index++) {
        _requireSession(session);
        final item = queue[index];
        if (item['status'] != 'staging') continue;
        final finalPath = item['file_path'] as String?;
        final stagingPath = item['staging_file_path'] as String?;
        final sourcePath = item['source_file_path'] as String?;
        if (finalPath == null || stagingPath == null || sourcePath == null) {
          queue[index] = {
            ...item,
            'status': 'failed',
            'staging_checkpoint': {'state': 'journal_invalid'},
            'last_error': 'progress_photo_journal_invalid',
          };
          changed = true;
          continue;
        }
        final finalFile = File(finalPath);
        if (await finalFile.exists()) {
          _requireSession(session);
          final bytes = await finalFile.length();
          _requireSession(session);
          queue[index] = {
            ...item,
            'bytes': bytes,
            'status': 'queued',
            'staging_checkpoint': {'state': 'queued'},
            'last_error': null,
          };
          changed = true;
          continue;
        }
        _requireSession(session);
        final stagingFile = File(stagingPath);
        if (await stagingFile.exists()) {
          _requireSession(session);
          await stagingFile.delete();
          _requireSession(session);
        }
        if (await File(sourcePath).exists()) {
          _requireSession(session);
          resumable.add(item['id'] as String);
        } else {
          _requireSession(session);
          queue[index] = {
            ...item,
            'status': 'failed',
            'staging_checkpoint': {'state': 'source_unavailable'},
            'last_error': 'progress_photo_source_unavailable',
          };
          changed = true;
        }
      }
      if (changed) {
        _requireSession(session);
        await _storage.saveProgressPhotoUploadQueue(queue);
        _requireSession(session);
      }
    });
    _requireSession(session);
    for (final id in resumable) {
      _requireSession(session);
      await _stageAndPromote(id, session);
      _requireSession(session);
    }
  }

  void _requireSession(String expected) {
    if (_storage.sessionStamp != expected) throw const LocalSessionChanged();
  }

  String _ownerScope(Map<String, Object?> identity) => base64Url.encode(
    utf8.encode(jsonEncode([
      identity['format_version'],
      identity['owner_id'],
      identity['environment'],
    ])),
  );

  String _safeExtension(String path) {
    final segment = path.split(Platform.pathSeparator).last;
    final dot = segment.lastIndexOf('.');
    final extension = dot < 0 ? '' : segment.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,10}$').hasMatch(extension) ? extension : 'bin';
  }

  static Future<File> _copyFileToStaging(File source, File staging) =>
      source.copy(staging.path);

  Future<void> _recoverInterrupted(String session) async {
    await _queueMutex.protect(() async {
      _requireSession(session);
      final queue = _storage.getProgressPhotoUploadQueue();
      var changed = false;
      for (var index = 0; index < queue.length; index++) {
        _requireSession(session);
        if (queue[index]['status'] == 'processing') {
          queue[index] = {...queue[index], 'status': 'queued'};
          changed = true;
        }
      }
      if (changed) {
        _requireSession(session);
        await _storage.saveProgressPhotoUploadQueue(queue);
        _requireSession(session);
      }
    });
    _requireSession(session);
    await _reconcileStaging(session);
  }

  Future<void> _retryCleanup(String session) async {
    _requireSession(session);
    for (final item in _storage.getProgressPhotoUploadQueue()) {
      _requireSession(session);
      if (item['status'] != 'completed' || item['cleanup_pending'] != true) continue;
      await _cleanup(item['id'] as String, item['file_path'] as String, session);
      _requireSession(session);
    }
  }

  Future<void> _cleanup(String id, String path, String session) async {
    try {
      await _mutate(
        id,
        (saved) => {
          ...saved,
          'cleanup_pending': true,
          'cleanup_checkpoint': {'state': 'deleting'},
        },
        session: session,
      );
      _requireSession(session);
      await _deleteFile(path);
      _requireSession(session);
      await _mutate(
        id,
        (saved) => {
          ...saved,
          'cleanup_pending': false,
          'cleanup_checkpoint': {'state': 'confirmed'},
          'last_error': null,
        },
        session: session,
      );
    } on FileSystemException catch (error) {
      _requireSession(session);
      await _mutate(
        id,
        (saved) => {
          ...saved,
          'cleanup_pending': true,
          'cleanup_checkpoint': {'state': 'failed'},
          'last_error': 'cleanup_failed: $error',
        },
        session: session,
      );
    }
  }

  Future<Map<String, dynamic>?> _claimNext() => _queueMutex.protect(() async {
    final queue = _storage.getProgressPhotoUploadQueue();
    final index = queue.indexWhere((item) {
      if (!_storage.ownsProgressPhotoQueueEntry(item) || item['status'] != 'queued') {
        return false;
      }
      final next = DateTime.tryParse(item['next_attempt_at'] as String? ?? '');
      return next == null || !next.isAfter(DateTime.now());
    });
    if (index < 0) return null;
    final claimed = {
      ...queue[index],
      'status': 'processing',
      'claimed_at': DateTime.now().toUtc().toIso8601String(),
      'attempts': (queue[index]['attempts'] as int? ?? 0) + 1,
    };
    queue[index] = claimed;
    await _storage.saveProgressPhotoUploadQueue(queue);
    return Map<String, dynamic>.from(claimed);
  });

  Map<String, dynamic>? _find(String id) {
    final matches = _storage.getProgressPhotoUploadQueue().where((item) => item['id'] == id);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _mutate(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) mutate, {
    String? session,
  }) => _queueMutex.protect(() async {
    if (session != null) _requireSession(session);
    final queue = _storage.getProgressPhotoUploadQueue();
    final index = queue.indexWhere((item) => item['id'] == id);
    if (index < 0) {
      if (session != null) {
        throw StateError('Progress photo journal is missing for its owner session');
      }
      return;
    }
    queue[index] = mutate(Map<String, dynamic>.from(queue[index]));
    if (session != null) _requireSession(session);
    await _storage.saveProgressPhotoUploadQueue(queue);
    if (session != null) _requireSession(session);
  });

  Future<void> _fail(
    String id,
    Map<String, dynamic> item,
    Object error, {
    required bool retryable,
  }) async {
    final attempts = item['attempts'] as int? ?? 1;
    final code = _errorCode(error);
    await _mutate(id, (saved) => {
      ...saved,
      'status': retryable ? 'queued' : 'failed',
      'last_error': code,
      if (retryable)
        'next_attempt_at': DateTime.now().toUtc().add(_backoff(attempts)).toIso8601String(),
    });
  }

  bool _isRetryable(Object error) {
    if (error is! DioException) return false;
    final status = error.response?.statusCode;
    // A stale replacement or authorization failure needs an explicit new
    // operation; automatic replay would be an unsafe overwrite attempt.
    if (status == 401 || status == 403 || status == 409 || status == 423) return false;
    return isOfflineError(error) || status == 429 || (status != null && status >= 500);
  }

  String _errorCode(Object error) {
    if (error is DioException) {
      if (isOfflineError(error)) {
        return 'progress_photo_network_${error.type.name}_0';
      }
      final data = error.response?.data;
      if (data is Map && data['code'] is String) return data['code'] as String;
      final status = error.response?.statusCode;
      return status == null
          ? 'progress_photo_transport_${error.type.name}'
          : 'progress_photo_http_$status';
    }
    return error is LocalSessionChanged ? 'session_changed' : error.toString();
  }

  // Keep reconnect behavior aligned with feedback's durable classification:
  // only an actual transport failure can discard its scheduled retry. Server
  // throttling and failures retain their backoff after connectivity changes.
  static final _networkFailure = RegExp(
    r'^progress_photo_(?:network|http)_(connectionError|connectionTimeout|receiveTimeout|sendTimeout|unknown)_0$',
  );

  bool _isNetworkBackoff(Object? error) =>
      error is String && _networkFailure.hasMatch(error);

  Duration _backoff(int attempts) {
    const seconds = [30, 120, 600, 3600];
    return Duration(seconds: seconds[(attempts - 1).clamp(0, seconds.length - 1)]);
  }

  static Future<void> _deleteExistingFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
