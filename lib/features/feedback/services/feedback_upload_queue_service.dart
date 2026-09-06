import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/utils/async_mutex.dart';

enum FeedbackUploadNoticeKind {
  queued,
  uploading,
  completed,
  failed,
  discarded,
}

class FeedbackUploadNotice {
  final String id;
  final FeedbackUploadNoticeKind kind;

  const FeedbackUploadNotice(this.id, this.kind);
}

class FeedbackUploadQueueService {
  final FeedbackRepository _repository;
  final LocalStorage _storage;
  final OfflineSyncService _offlineSync;
  final bool Function() _isAuthenticated;
  final Future<Directory> Function() _applicationSupportDirectory;
  final Future<void> Function(String) _deleteFile;
  final StreamController<FeedbackUploadNotice> _notices =
      StreamController<FeedbackUploadNotice>.broadcast();
  final AsyncMutex _queueMutex = AsyncMutex();

  bool _processing = false;
  bool _initialized = false;

  FeedbackUploadQueueService(
    this._repository,
    this._storage,
    this._offlineSync, {
    bool Function()? isAuthenticated,
    Future<Directory> Function()? applicationSupportDirectory,
    Future<void> Function(String)? deleteFile,
  }) : _isAuthenticated =
           isAuthenticated ?? (() => FirebaseAuth.instance.currentUser != null),
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory,
       _deleteFile = deleteFile ?? _deleteExistingFile;

  Stream<FeedbackUploadNotice> get notices => _notices.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final original = _storage.getFeedbackUploadQueue();
    final recovered = <Map<String, dynamic>>[];
    for (final raw in original) {
      var item = Map<String, dynamic>.from(raw);
      final queuedAt = DateTime.tryParse(item['queued_at'] as String? ?? '');
      final expired =
          queuedAt != null &&
          DateTime.now().toUtc().difference(queuedAt.toUtc()) >=
              const Duration(hours: 24);
      if (expired) {
        try {
          final path = item['file_path'] as String?;
          if (path != null) {
            await _deleteFile(path);
          }
          final id = item['id'] as String?;
          if (id != null && item['status'] != 'completed') {
            await _offlineSync.removeActionsDependingOnFeedback(id);
          }
          continue;
        } on FileSystemException catch (error) {
          item = {
            ...item,
            'status': item['status'] == 'completed' ? 'completed' : 'failed',
            'last_error': 'cleanup_failed: $error',
          };
        }
      } else if (item['status'] == 'uploading') {
        item = {...item, 'status': 'queued'};
      }
      recovered.add(item);
    }
    await _queueMutex.protect(
      () => _storage.saveFeedbackUploadQueue(recovered),
    );
    Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(processQueue()),
    );
    await processQueue();
  }

  Future<String> enqueue({
    required File file,
    required String contentType,
    required String mediaType,
    String? notes,
    String? exerciseId,
    String? feedbackKind,
    String? trainingId,
    String? trainingExerciseId,
    String? assignmentDate,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final directory = Directory(
      '${(await _applicationSupportDirectory()).path}/feedback_uploads',
    );
    await directory.create(recursive: true);
    final extension = file.path.split('.').last.toLowerCase();
    final stableFile = await file.copy('${directory.path}/$id.$extension');
    await _queueMutex.protect(() async {
      final queue = _storage.getFeedbackUploadQueue();
      queue.add({
        'id': id,
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
    _notices.add(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.queued));
    unawaited(processQueue());
    return id;
  }

  Future<void> retry(String id) async {
    await _mutateById(id, (item) {
      if (item['status'] != 'failed') return item;
      return {
        ...item,
        'status': 'queued',
        'attempts': 0,
        'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null,
      };
    });
    await processQueue();
  }

  List<Map<String, dynamic>> get pendingItems =>
      _storage.getFeedbackUploadQueue();

  Future<void> discard(String id) async {
    final item = await _queueMutex.protect(() async {
      final queue = _storage.getFeedbackUploadQueue();
      final index = queue.indexWhere((entry) => entry['id'] == id);
      if (index < 0) return null;
      final claimed = {...queue[index], 'status': 'discarding'};
      queue[index] = claimed;
      await _storage.saveFeedbackUploadQueue(queue);
      return claimed;
    });
    if (item == null) return;
    try {
      final filePath = item['file_path'] as String?;
      if (filePath != null) {
        await _deleteFile(filePath);
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
      final queue = _storage.getFeedbackUploadQueue()
        ..removeWhere((entry) => entry['id'] == id);
      await _storage.saveFeedbackUploadQueue(queue);
    });
    await _offlineSync.removeActionsDependingOnFeedback(id);
    _notices.add(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.discarded));
  }

  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      await _retryCompletedCleanup();
      await _purgeExpiredItems();
      if (!_isAuthenticated()) return;
      while (true) {
        if (!_isAuthenticated()) break;
        final item = await _claimNext();
        if (item == null) break;
        final id = item['id'] as String;
        final file = File(item['file_path'] as String);
        if (!await file.exists()) {
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
          final upload = await _repository.uploadMedia(
            file,
            item['content_type'] as String,
          );
          if (!_isAuthenticated()) {
            await _mutateById(
              id,
              (current) => {...current, 'status': 'queued'},
            );
            break;
          }
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
          String? cleanupError;
          try {
            await _deleteFile(file.path);
          } on FileSystemException catch (error) {
            cleanupError = 'cleanup_failed: $error';
          }
          await _mutateById(
            id,
            (current) => {
              ...current,
              'status': 'completed',
              'last_error': cleanupError,
            },
          );
          _notices.add(
            FeedbackUploadNotice(id, FeedbackUploadNoticeKind.completed),
          );
          await _offlineSync.syncPendingActions();
        } catch (error) {
          if (!_isAuthenticated()) {
            await _mutateById(
              id,
              (current) => {...current, 'status': 'queued'},
            );
            break;
          }
          if (attempts >= 5) {
            await _mutateById(
              id,
              (current) => {
                ...current,
                'status': 'failed',
                'attempts': attempts,
                'last_error': error.toString(),
              },
            );
            _notices.add(
              FeedbackUploadNotice(id, FeedbackUploadNoticeKind.failed),
            );
          } else {
            const delays = [30, 120, 600, 3600];
            await _mutateById(
              id,
              (current) => {
                ...current,
                'status': 'queued',
                'attempts': attempts,
                'next_attempt_at': DateTime.now()
                    .toUtc()
                    .add(Duration(seconds: delays[attempts - 1]))
                    .toIso8601String(),
                'last_error': error.toString(),
              },
            );
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
        if (item['status'] != 'queued') return false;
        final next = DateTime.tryParse(
          item['next_attempt_at'] as String? ?? '',
        );
        return next == null || !next.isAfter(DateTime.now());
      });
      if (index < 0) return null;
      final claimed = {
        ...queue[index],
        'status': 'uploading',
        'attempts': (queue[index]['attempts'] as int? ?? 0) + 1,
      };
      queue[index] = claimed;
      await _storage.saveFeedbackUploadQueue(queue);
      _notices.add(
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
                (item['last_error'] as String? ?? '').startsWith(
                  'cleanup_failed:',
                ),
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
        final queuedAt = DateTime.tryParse(item['queued_at'] as String? ?? '');
        if (queuedAt != null &&
            DateTime.now().toUtc().difference(queuedAt.toUtc()) >=
                const Duration(hours: 24)) {
          await _removeById(id);
        } else {
          await _mutateById(id, (current) => {...current, 'last_error': null});
        }
      } on FileSystemException catch (error) {
        await _mutateById(
          id,
          (current) => {...current, 'last_error': 'cleanup_failed: $error'},
        );
      }
    }
  }

  Future<void> _purgeExpiredItems() async {
    final expired = await _queueMutex.protect(() async {
      final now = DateTime.now().toUtc();
      return _storage
          .getFeedbackUploadQueue()
          .where((item) {
            if (!_isAuthenticated() && item['status'] != 'completed') {
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
        await _removeById(id);
        if (item['status'] != 'completed') {
          await _offlineSync.removeActionsDependingOnFeedback(id);
        }
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

  Future<void> _removeById(String id) {
    return _queueMutex.protect(() async {
      final queue = _storage.getFeedbackUploadQueue()
        ..removeWhere((item) => item['id'] == id);
      await _storage.saveFeedbackUploadQueue(queue);
    });
  }

  static Future<void> _deleteExistingFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
