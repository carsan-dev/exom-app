// FB1: a failed mandatory last-set video can be replaced by a new one. The
// replacement is committed in one write of the feedback queue; every queued
// reference to the old upload (exercise completion, training completion,
// draft, circuit snapshot) then resolves to the new one, also after a crash
// between the steps, without a second feedback or a second progress write.
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'offline_sync_service_test.dart' show respondingClient;

const _date = '2026-10-01';
const _training = 'fixture-training';
const _trainingExercise = 'fixture-te';
const _exercise = 'fixture-e';

class _Repository extends Fake implements FeedbackRepository {
  final created = <String?>[];
  int uploads = 0;

  @override
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String contentType, {
    FeedbackUploadContext? context,
  }) async {
    uploads++;
    return ManagedFeedbackUpload(
      uploadId: 'upload-$uploads',
      fileUrl: 'https://fixture.invalid/$uploads',
    );
  }

  @override
  Future<FeedbackEntity> createFeedback({
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
    created.add(clientUploadId);
    return FeedbackEntity(
      id: 'feedback-${created.length}',
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      status: 'PENDING',
      createdAt: DateTime.utc(2026, 10, 1),
    );
  }
}

/// Stops the replacement right after its commit, as a process death would:
/// the step after the commit never ends and nothing after it runs.
class _CrashingSync extends OfflineSyncService {
  _CrashingSync(super.client, super.storage, {super.isAuthenticated,
    super.authenticationChanges, super.connectivityChanges});

  @override
  Future<void> redirectFeedbackDependency(String from, String to) =>
      Completer<void>().future;
}

/// The first redirect after the commit fails (a storage error, not a file
/// error); later ones (the queue sweep) work.
class _FailingOnceSync extends OfflineSyncService {
  _FailingOnceSync(super.client, super.storage, {super.isAuthenticated,
    super.authenticationChanges, super.connectivityChanges});

  var failed = false;

  @override
  Future<void> redirectFeedbackDependency(String from, String to) {
    if (!failed) {
      failed = true;
      return Future.error(StateError('simulated failure after the commit'));
    }
    return super.redirectFeedbackDependency(from, to);
  }
}

enum _SyncKind { normal, crashing, failingOnce }

class _World {
  _World(this.directory);

  final Directory directory;
  var session = const LocalAuthSession(uid: 'owner-a', generation: 1);
  var authenticated = false;
  final repository = _Repository();
  final requests = <({String path, String? id, Map<String, dynamic> data})>[];
  var _revision = 0;
  late LocalStorage store;
  late OfflineSyncService sync;
  late FeedbackUploadQueueService queue;
  late ApiClient client;

  /// File deletion of the queue service; null keeps the real one.
  Future<void> Function(String)? deleteFile;

  Future<void> open({_SyncKind kind = _SyncKind.normal}) async {
    if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
      Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
    }
    await Hive.openBox('cache_box');
    await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
    store = LocalStorage(currentSession: () => session);
    client = respondingClient((options, handler) {
      requests.add((
        path: options.path,
        id: options.headers['x-exom-operation-id'] as String?,
        data: Map<String, dynamic>.from(options.data as Map),
      ));
      _revision++;
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'date': _date,
          'sync_revision': _revision,
          'operation_revision': _revision,
          'exercises_completed': <Map<String, dynamic>>[],
          'meals_completed': <String>[],
        },
      ));
    });
    sync = switch (kind) {
      _SyncKind.crashing => _CrashingSync(client, store,
          isAuthenticated: () => authenticated,
          authenticationChanges: const Stream<bool>.empty(),
          connectivityChanges: const Stream<bool>.empty()),
      _SyncKind.failingOnce => _FailingOnceSync(client, store,
          isAuthenticated: () => authenticated,
          authenticationChanges: const Stream<bool>.empty(),
          connectivityChanges: const Stream<bool>.empty()),
      _SyncKind.normal => OfflineSyncService(client, store,
          isAuthenticated: () => authenticated,
          authenticationChanges: const Stream<bool>.empty(),
          connectivityChanges: const Stream<bool>.empty()),
    };
    queue = FeedbackUploadQueueService(repository, store, sync,
      isAuthenticated: () => authenticated,
      applicationSupportDirectory: () async => directory,
      deleteFile: deleteFile,
      connectivityChanges: const Stream<bool>.empty());
  }

  /// Waits for the queue pass a replacement or enqueue started on its own.
  /// A crashed process runs nothing more.
  Future<void> settle() async {
    if (sync is _CrashingSync) return;
    await queue.processQueue();
  }

  Future<void> restart({_SyncKind kind = _SyncKind.normal}) async {
    await settle();
    await queue.dispose();
    await sync.dispose();
    await Hive.close();
    await open(kind: kind);
  }

  /// Starts a replacement of [id] in a process that dies right after its
  /// commit ([_CrashingSync]) and returns the id it committed.
  Future<String> crashAfterCommit(String id, String name) async {
    expect(sync, isA<_CrashingSync>());
    unawaited(queue.replaceFailed(id, file: video(name),
      contentType: 'video/mp4', expectedSession: store.sessionStamp));
    for (var turn = 0; turn < 500; turn++) {
      final link = store.getFeedbackUploadQueue()
          .where((item) => item['id'] == id)
          .firstOrNull?['replaced_by'];
      if (link is String) return link;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the replacement was never committed');
  }

  Future<void> close() async {
    try {
      await settle();
      await queue.dispose();
      await sync.dispose();
    } finally {
      await Hive.close();
    }
  }

  Map<String, dynamic> row(String id) =>
      store.getFeedbackUploadQueue().singleWhere((item) => item['id'] == id);

  /// Names of the files kept next to the queue.
  List<String> uploadFiles() {
    final folder = Directory('${directory.path}/feedback_uploads');
    if (!folder.existsSync()) return const [];
    return folder.listSync().map((entry) => _name(entry.path)).toList();
  }

  File video(String name) =>
      File('${directory.path}/$name.mp4')..writeAsBytesSync([1, 2, 3]);

  /// A finished exercise whose mandatory video failed for good (the stable
  /// copy is gone), with its completion and the training completion queued.
  Future<({String execution, String failed})> failedMandatoryVideo({
    bool withName = true,
    bool queueTrainingCompletion = true,
  }) async {
    final execution = await store.createTrainingExecution(_training, _date);
    final failed = await queue.enqueue(
      file: video('first'),
      contentType: 'video/mp4',
      mediaType: 'VIDEO',
      exerciseId: _exercise,
      feedbackKind: 'LAST_SET',
      trainingId: _training,
      trainingExerciseId: _trainingExercise,
      assignmentDate: _date,
      sessionId: execution,
      exerciseName: withName ? 'Sentadilla búlgara' : null,
    );
    await queue.processQueue();
    File(row(failed)['file_path'] as String).deleteSync();
    authenticated = true;
    await queue.processQueue();
    expect(row(failed)['status'], 'failed');
    expect(row(failed)['last_error'], 'file_missing');
    await sync.queueExerciseCompletion(_trainingExercise, _date,
      completed: true, exerciseId: _exercise, trainingId: _training,
      sessionId: execution, lastSetFeedbackClientUploadId: failed,
      operationId: 'exercise-op');
    if (queueTrainingCompletion) {
      await sync.queueTrainingCompletion(_date, trainingId: _training,
        sessionId: execution, rpe: 8);
    }
    await sync.syncPendingActions();
    expect(requests, isEmpty, reason: 'nothing is sent before the video');
    if (queueTrainingCompletion) {
      expect(sync.completionBlocker(_training, _date, execution)?.kind,
        CompletionSyncBlockerKind.feedbackFailed);
    }
    authenticated = false;
    return (execution: execution, failed: failed);
  }

  Map<String, dynamic> exerciseAction() => store.getPendingSyncActions()
      .singleWhere((action) => action['id'] == 'exercise-op');

  Map<String, dynamic> completionAction() => store.getPendingSyncActions()
      .singleWhere((action) => action['type'] == 'complete_training');
}

String _name(String path) => path.split(RegExp(r'[\\/]')).last;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _World world;
  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('exom-fb1-');
    Hive.init(directory.path);
    world = _World(directory);
    await world.open();
  });
  tearDown(() async {
    await world.close();
    if (await world.directory.exists()) {
      await world.directory.delete(recursive: true);
    }
  });

  test('stores the exercise name and still reads rows saved without it',
      () async {
    final old = await world.failedMandatoryVideo();
    expect(world.row(old.failed)['exercise_name'], 'Sentadilla búlgara');
    // An entry persisted by an earlier build has no exercise_name at all.
    final legacy = Map<String, dynamic>.from(world.row(old.failed))
      ..remove('exercise_name');
    await world.store.saveFeedbackUploadQueue([legacy]);
    expect(world.queue.pendingItems.single.containsKey('exercise_name'), false);
    final fresh = await world.queue.replaceFailed(old.failed,
      file: world.video('legacy-again'), contentType: 'video/mp4',
      expectedSession: world.store.sessionStamp);
    expect(world.row(fresh).containsKey('exercise_name'), false);
    expect(world.exerciseAction()['last_set_feedback_client_upload_id'], fresh);
  });

  test('replacing a failed video redirects every queued reference and sends '
      'one feedback and one write per action', () async {
    final old = await world.failedMandatoryVideo();
    final draft = ActiveWorkoutHiveModel(trainingId: _training,
      sessionId: old.execution, exerciseId: 'other-te:$_date:${old.execution}',
      currentSet: 3, completedSets: 3, lastSetFeedbackClientUploadId: old.failed);
    await world.store.saveActiveWorkout(draft);

    final fresh = await world.queue.replaceFailed(old.failed,
      file: world.video('again'), contentType: 'video/mp4', notes: ' otra ',
      expectedSession: world.store.sessionStamp);

    expect(fresh, isNot(old.failed));
    final replaced = world.store.getFeedbackUploadQueue()
        .singleWhere((item) => item['id'] == old.failed);
    expect(replaced['replaced_by'], fresh);
    expect(replaced['status'], 'superseded');
    expect(replaced['dismissed'], true);
    final added = world.row(fresh);
    expect(added['status'], 'queued');
    expect(added['replaces_feedback_id'], old.failed);
    expect(added['training_session_id'], old.execution);
    expect(added['training_exercise_id'], _trainingExercise);
    expect(added['training_id'], _training);
    expect(added['assignment_date'], _date);
    expect(added['feedback_kind'], 'LAST_SET');
    expect(added['media_type'], 'VIDEO');
    expect(added['exercise_id'], _exercise);
    expect(added['exercise_name'], 'Sentadilla búlgara');
    expect(added['notes'], 'otra');
    expect(world.queue.pendingItems.map((item) => item['id']), [fresh]);

    expect(world.exerciseAction()['last_set_feedback_client_upload_id'], fresh);
    expect(world.exerciseAction()['status'], 'queued');
    expect(world.completionAction()['depends_on_feedback_ids'], [fresh]);
    expect(world.completionAction()['status'], 'queued');
    expect(world.store.getPendingSyncActions()
        .where((action) => action['last_error'] == 'feedback_discarded'), isEmpty);
    expect(world.store.getActiveWorkout(draft.exerciseId)
        ?.lastSetFeedbackClientUploadId, fresh);
    expect(world.sync.completionBlocker(_training, _date, old.execution)?.kind,
      CompletionSyncBlockerKind.feedbackWaiting);

    world.authenticated = true;
    await world.queue.processQueue();
    expect(world.repository.created, [fresh]);
    expect(world.requests.map((request) => request.path), [
      '/progress/exercises/complete',
      '/progress/trainings/complete',
    ]);
    expect(world.requests.first.id, 'exercise-op');
    expect(world.requests.first.data['last_set_feedback_client_upload_id'],
      fresh);
    expect(world.store.getPendingSyncActions(), isEmpty);

    // Replay and wake-ups after the fact change nothing.
    await world.queue.processQueue();
    await world.sync.syncPendingActions();
    await world.queue.replaceFailed(old.failed, file: world.video('late'),
      contentType: 'video/mp4', expectedSession: world.store.sessionStamp);
    await world.queue.processQueue();
    expect(world.repository.created, [fresh]);
    expect(world.requests, hasLength(2));
  });

  test('a crash after the commit leaves a state that resolves to the new '
      'video and finishes on the next wake', () async {
    final old = await world.failedMandatoryVideo();
    await world.restart(kind: _SyncKind.crashing);

    final fresh = await world.crashAfterCommit(old.failed, 'again');
    // The queued actions still name the old upload: nothing was redirected.
    expect(world.exerciseAction()['last_set_feedback_client_upload_id'],
      old.failed);

    await world.restart();
    // Before any repair the old reference already resolves to the new video.
    expect(world.sync.completionBlocker(_training, _date, old.execution)?.kind,
      CompletionSyncBlockerKind.feedbackWaiting);
    // A second tap after the restart reuses the committed replacement.
    final again = await world.queue.replaceFailed(old.failed,
      file: world.video('again-2'), contentType: 'video/mp4',
      expectedSession: world.store.sessionStamp);
    expect(again, fresh);
    expect(world.store.getFeedbackUploadQueue(), hasLength(2));

    world.authenticated = true;
    await world.queue.processQueue();
    expect(world.repository.created, [fresh]);
    expect(world.requests, hasLength(2));
    expect(world.requests.first.data['last_set_feedback_client_upload_id'],
      fresh);
    expect(world.store.getPendingSyncActions(), isEmpty);
    expect(world.store.getFeedbackUploadQueue()
        .singleWhere((item) => item['id'] == old.failed)['status'], 'superseded');
  });

  test('a crash before the redirect is repaired by the queue sweep alone',
      () async {
    final old = await world.failedMandatoryVideo();
    await world.restart(kind: _SyncKind.crashing);
    final fresh = await world.crashAfterCommit(old.failed, 'again');
    await world.restart();
    await world.queue.processQueue(); // signed out: only local repair
    expect(world.exerciseAction()['last_set_feedback_client_upload_id'], fresh);
    expect(world.completionAction()['depends_on_feedback_ids'], [fresh]);
    expect(world.store.getPendingSyncActions()
        .where((action) => action['status'] == 'failed'), isEmpty);
  });

  test('a double tap replaces once and keeps no stray copy', () async {
    final old = await world.failedMandatoryVideo();
    final results = await Future.wait([
      world.queue.replaceFailed(old.failed, file: world.video('tap-1'),
        contentType: 'video/mp4', expectedSession: world.store.sessionStamp),
      world.queue.replaceFailed(old.failed, file: world.video('tap-2'),
        contentType: 'video/mp4', expectedSession: world.store.sessionStamp),
    ]);
    expect(results[0], results[1]);
    expect(world.store.getFeedbackUploadQueue(), hasLength(2));
    expect(world.uploadFiles(),
      [_name(world.row(results[0])['file_path'] as String)]);
  });

  test('a late reference to the old video (circuit snapshot) sends the new one',
      () async {
    final old = await world.failedMandatoryVideo();
    final fresh = await world.queue.replaceFailed(old.failed,
      file: world.video('again'), contentType: 'video/mp4',
      expectedSession: world.store.sessionStamp);
    // A circuit restored after the replacement still holds the old id in
    // its frozen completion snapshot.
    await world.sync.queueExerciseCompletion('circuit-te', _date,
      completed: true, exerciseId: 'circuit-e', trainingId: _training,
      sessionId: old.execution, lastSetFeedbackClientUploadId: old.failed,
      operationId: 'circuit-op');
    world.authenticated = true;
    await world.queue.processQueue();
    final circuit = world.requests.singleWhere((request) =>
        request.id == 'circuit-op');
    expect(circuit.data['last_set_feedback_client_upload_id'], fresh);
    expect(world.repository.created, [fresh]);
  });

  test('another session or account cannot replace or redirect the video',
      () async {
    final old = await world.failedMandatoryVideo();
    final before = world.store.getFeedbackUploadQueue();
    await expectLater(
      world.queue.replaceFailed(old.failed, file: world.video('stale'),
        contentType: 'video/mp4', expectedSession: 'owner-a:0:test'),
      throwsA(isA<LocalSessionChanged>()),
    );
    expect(world.store.getFeedbackUploadQueue(), before);

    world.session = const LocalAuthSession(uid: 'owner-b', generation: 2);
    await world.sync.queueExerciseCompletion('b-te', _date, completed: true,
      exerciseId: 'b-e', trainingId: _training,
      lastSetFeedbackClientUploadId: old.failed, operationId: 'b-op');
    await expectLater(
      world.queue.replaceFailed(old.failed, file: world.video('foreign'),
        contentType: 'video/mp4', expectedSession: world.store.sessionStamp),
      throwsStateError,
    );

    world.session = const LocalAuthSession(uid: 'owner-a', generation: 1);
    expect(world.store.getFeedbackUploadQueue(), before);
    final fresh = await world.queue.replaceFailed(old.failed,
      file: world.video('mine'), contentType: 'video/mp4',
      expectedSession: world.store.sessionStamp);
    expect(world.exerciseAction()['last_set_feedback_client_upload_id'], fresh);
    world.session = const LocalAuthSession(uid: 'owner-b', generation: 2);
    expect(world.store.getPendingSyncActions().single
        ['last_set_feedback_client_upload_id'], old.failed,
      reason: 'the other account keeps its own record untouched');
  });

  test('only a failed last-set video can be replaced', () async {
    final execution =
        await world.store.createTrainingExecution(_training, _date);
    final queued = await world.queue.enqueue(file: world.video('queued'),
      contentType: 'video/mp4', mediaType: 'VIDEO', feedbackKind: 'LAST_SET',
      trainingId: _training, trainingExerciseId: _trainingExercise,
      assignmentDate: _date, sessionId: execution);
    await expectLater(
      world.queue.replaceFailed(queued, file: world.video('again'),
        contentType: 'video/mp4', expectedSession: world.store.sessionStamp),
      throwsStateError,
    );
    expect(world.store.getFeedbackUploadQueue(), hasLength(1));
    expect(world.uploadFiles(), hasLength(1));
  });

  test('a training completion queued after the commit depends on the '
      'replacement, not the old video', () async {
    final old = await world.failedMandatoryVideo(
      queueTrainingCompletion: false);
    await world.restart(kind: _SyncKind.crashing);
    final fresh = await world.crashAfterCommit(old.failed, 'again');
    expect(world.sync.hasPendingFeedbackForTraining(_training, _date), true);
    await world.sync.queueTrainingCompletion(_date, trainingId: _training,
      sessionId: old.execution, rpe: 8);
    expect(world.completionAction()['depends_on_feedback_ids'], [fresh]);
  });

  // FB1 r2 (review F3): once the replacement is committed it is not reported
  // as failed because a later step threw; the queue sweep finishes it.
  test('a failure after the commit does not fail the replacement: the sweep '
      'finishes it', () async {
    final old = await world.failedMandatoryVideo();
    await world.restart(kind: _SyncKind.failingOnce);
    final fresh = await world.queue.replaceFailed(old.failed,
      file: world.video('again'), contentType: 'video/mp4',
      expectedSession: world.store.sessionStamp);
    expect(world.row(old.failed)['replaced_by'], fresh);
    expect(world.row(fresh)['status'], 'queued');
    await world.settle();
    expect(world.exerciseAction()['last_set_feedback_client_upload_id'], fresh);
    expect(world.completionAction()['depends_on_feedback_ids'], [fresh]);
    expect(world.row(old.failed)['status'], 'superseded');
    expect(world.store.getPendingSyncActions()
        .where((action) => action['status'] == 'failed'), isEmpty);
  });

  // FB1 r2 (review F2): a late reference (a circuit snapshot restored after
  // the replacement) still names the old id. Deleting the replacement must
  // release that action like any other dependant, never leave it queued
  // for an upload that no longer exists.
  test('deleting the replacement fails a late reference to the old video '
      'instead of leaving it queued forever', () async {
    final old = await world.failedMandatoryVideo(
      queueTrainingCompletion: false);
    final fresh = await world.queue.replaceFailed(old.failed,
      file: world.video('again'), contentType: 'video/mp4',
      expectedSession: world.store.sessionStamp);
    await world.settle();
    await world.sync.queueExerciseCompletion('circuit-te', _date,
      completed: true, exerciseId: 'circuit-e', trainingId: _training,
      sessionId: old.execution, lastSetFeedbackClientUploadId: old.failed,
      operationId: 'circuit-op');

    await world.queue.discard(fresh);

    final circuit = world.store.getPendingSyncActions()
        .singleWhere((action) => action['id'] == 'circuit-op');
    expect(circuit['status'], 'failed');
    expect(circuit['last_error'], 'feedback_discarded');
    expect(circuit.containsKey('last_set_feedback_client_upload_id'), false);
    expect(world.exerciseAction()['status'], 'failed');
    expect(world.exerciseAction()['last_error'], 'feedback_discarded');
  });

  // FB1 r2 (review F4): the replacement and the queue sweep can clean the
  // same replaced row at once; the one that finds the file already gone
  // must not turn the finished tombstone into a failed row.
  test('two cleanups of the same replaced video leave one superseded '
      'tombstone', () async {
    final old = await world.failedMandatoryVideo();
    Completer<void>? gate;
    var gated = false;
    world.deleteFile = (path) async {
      if (gate != null && !gated) {
        gated = true;
        await gate.future;
        // It saw the file before the other cleanup deleted it.
        throw PathNotFoundException(
          path, const OSError('No such file or directory', 2));
      }
      final file = File(path);
      if (await file.exists()) await file.delete();
    };
    await world.restart();
    gate = Completer<void>();
    final replacing = world.queue.replaceFailed(old.failed,
      file: world.video('again'), contentType: 'video/mp4',
      expectedSession: world.store.sessionStamp);
    for (var turn = 0; !gated && turn < 500; turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(gated, true, reason: 'the replacement reached its cleanup');
    await world.queue.processQueue(); // the sweep cleans the same row
    expect(world.row(old.failed)['status'], 'superseded');
    gate.complete();
    final fresh = await replacing;

    final tombstone = world.row(old.failed);
    expect(tombstone['status'], 'superseded');
    expect(tombstone['replaced_by'], fresh);
    expect(tombstone['discard_cleanup_complete'], true);
    expect('${tombstone['last_error']}', isNot(startsWith('cleanup_failed')));
    expect(world.queue.statusOf(old.failed), 'queued');
  });

  // FB1 r2 (review F6): a replacement can fail too and be replaced again.
  test('a chain of replacements (A→B→C) resolves to the last one in status, '
      'diagnosis and replay', () async {
    final a = await world.failedMandatoryVideo(queueTrainingCompletion: false);
    final b = await world.queue.replaceFailed(a.failed,
      file: world.video('b'), contentType: 'video/mp4',
      expectedSession: world.store.sessionStamp);
    await world.settle();
    // B is lost as well.
    File(world.row(b)['file_path'] as String).deleteSync();
    world.authenticated = true;
    await world.queue.processQueue();
    expect(world.row(b)['status'], 'failed');
    world.authenticated = false;
    expect(world.queue.statusOf(a.failed), 'failed');
    // A circuit restored now still names A (frozen snapshot).
    await world.sync.queueExerciseCompletion('circuit-te', _date,
      completed: true, exerciseId: 'circuit-e', trainingId: _training,
      sessionId: a.execution, lastSetFeedbackClientUploadId: a.failed,
      operationId: 'circuit-op');

    final c = await world.queue.replaceFailed(b,
      file: world.video('c'), contentType: 'video/mp4',
      expectedSession: world.store.sessionStamp);
    await world.settle();
    final queue = world.store.getFeedbackUploadQueue();
    expect(resolveFeedbackReplacement(queue, a.failed), c);
    expect(resolveFeedbackReplacement(queue, b), c);
    expect(world.queue.statusOf(a.failed), 'queued');
    expect(world.row(b)['status'], 'superseded');
    expect(world.exerciseAction()['last_set_feedback_client_upload_id'], c);
    // Replacing B only rewrites references to B: the snapshot keeps A.
    expect(world.store.getPendingSyncActions().singleWhere(
        (action) => action['id'] == 'circuit-op')
        ['last_set_feedback_client_upload_id'], a.failed);
    await world.sync.queueTrainingCompletion(_date, trainingId: _training,
      sessionId: a.execution, rpe: 8);
    expect(world.completionAction()['depends_on_feedback_ids'], [c]);
    expect(world.sync.completionBlocker(_training, _date, a.execution)?.kind,
      CompletionSyncBlockerKind.feedbackWaiting);

    world.authenticated = true;
    await world.queue.processQueue();
    expect(world.repository.created, [c]);
    final circuit = world.requests.singleWhere(
        (request) => request.id == 'circuit-op');
    expect(circuit.data['last_set_feedback_client_upload_id'], c);
    expect(world.requests.singleWhere((request) => request.id == 'exercise-op')
        .data['last_set_feedback_client_upload_id'], c);
    expect(world.store.getPendingSyncActions(), isEmpty);
  });

  test('a replacement cycle in a damaged queue ends instead of looping', () {
    final cycle = [
      {'id': 'a', 'replaced_by': 'b'},
      {'id': 'b', 'replaced_by': 'a'},
    ];
    expect(resolveFeedbackReplacement(cycle, 'a'), 'b');
    expect(resolveFeedbackReplacement(cycle, 'b'), 'a');
    expect(resolveFeedbackReplacement([
      {'id': 'self', 'replaced_by': 'self'},
    ], 'self'), 'self');
    expect(resolveFeedbackReplacement(cycle, 'unknown'), 'unknown');
  });
}
