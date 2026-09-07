import 'dart:async';
import 'dart:io';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'feedback_upload_queue_service_test.dart';

void main() {
  late Directory dir;
  late LocalAuthSession? current;
  late LocalStorage storage;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('exom-owner-test-');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
      Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
    }
    await Hive.openBox('auth_box');
    await Hive.openBox('cache_box');
    await Hive.openBox('settings_box');
    await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
    current = const LocalAuthSession(uid: 'A', generation: 1);
    storage = LocalStorage(
      currentSession: () => current,
      environment: 'https://test.exom.invalid',
    );
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'logout/cache clearing preserve owned evidence and quarantine legacy data',
    () async {
      final file = await File('${dir.path}/pending.mp4').writeAsBytes([1]);
      await Hive.box('cache_box').put('feedback_upload_queue', [
        {'id': 'legacy', 'file_path': file.path, 'status': 'queued'},
      ]);
      await storage.saveFeedbackUploadQueue([
        {
          'id': 'A-video',
          'file_path': file.path,
          'status': 'queued',
          ...storage.queueIdentity,
        },
      ]);
      await storage.savePendingSyncActions([
        {'id': 'A-action', 'status': 'queued', ...storage.queueIdentity},
      ]);
      await storage.cacheData('profile', {'name': 'A'});
      await storage.clearCache();
      await storage.clearSessionData();
      expect(await file.exists(), true);
      expect(storage.getFeedbackUploadQueue().single['id'], 'A-video');
      expect(storage.getPendingSyncActions().single['id'], 'A-action');
      expect(storage.hasUnattributedData, true);
      current = const LocalAuthSession(uid: 'B', generation: 2);
      expect(storage.getFeedbackUploadQueue(), isEmpty);
      expect(storage.getPendingSyncActions(), isEmpty);
      expect(storage.getCachedMap('profile'), isNull);
      current = const LocalAuthSession(uid: 'A', generation: 3);
      expect(storage.getFeedbackUploadQueue().single['id'], 'A-video');
      expect(Hive.box('cache_box').get('feedback_upload_queue'), hasLength(1));
    },
  );

  test(
    'A in-flight upload cannot create feedback or apply its result to B',
    () async {
      final file = await File('${dir.path}/pending.mp4').writeAsBytes([1]);
      await storage.saveFeedbackUploadQueue([
        {
          'id': 'A-video',
          'file_path': file.path,
          'status': 'queued',
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          ...storage.queueIdentity,
        },
      ]);
      final repository = BlockingFeedbackRepository();
      final service = FeedbackUploadQueueService(
        repository,
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => current != null,
      );
      final task = service.processQueue();
      await repository.firstUploadStarted.future;
      current =
          null; // expiration/logout pauses A; a B login is not disposal consent.
      current = const LocalAuthSession(uid: 'B', generation: 2);
      repository.releaseFirstUpload.complete();
      await task;
      expect(repository.createCalls, 0);
      expect(storage.getFeedbackUploadQueue(), isEmpty);
      expect(await file.exists(), true);
      current = const LocalAuthSession(uid: 'A', generation: 3);
      expect(storage.getFeedbackUploadQueue().single['status'], 'uploading');
      await service.processQueue();
      expect(storage.getFeedbackUploadQueue().single['status'], 'completed');
      expect(repository.createCalls, 1);
    },
  );

  test(
    'session zones reject a cache writer resumed after switching accounts',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final task = storage.sessionTask(() async {
        entered.complete();
        await release.future;
        await storage.cacheData('profile', {'name': 'A'});
      });
      await entered.future;
      current = const LocalAuthSession(uid: 'B', generation: 2);
      final rejected = expectLater(task, throwsA(isA<LocalSessionChanged>()));
      release.complete();
      await rejected;
      expect(storage.getCachedMap('profile'), isNull);
    },
  );

  test(
    'two service instances cannot consume the same claimed evidence',
    () async {
      final file = await File('${dir.path}/pending.mp4').writeAsBytes([1]);
      await storage.saveFeedbackUploadQueue([
        {
          'id': 'A-video',
          'file_path': file.path,
          'status': 'queued',
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          ...storage.queueIdentity,
        },
      ]);
      final repository = BlockingFeedbackRepository();
      final one = FeedbackUploadQueueService(
        repository,
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => true,
      );
      final two = FeedbackUploadQueueService(
        repository,
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => true,
      );
      final taskOne = one.processQueue();
      await repository.firstUploadStarted.future;
      final taskTwo = two.processQueue();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repository.uploadCalls, 1);
      repository.releaseFirstUpload.complete();
      await Future.wait([taskOne, taskTwo]);
      expect(repository.uploadCalls, 1);
      expect(repository.createCalls, 1);
    },
  );
  test(
    'reconnect queued by A cannot wake B after account replacement',
    () async {
      final connectivity = StreamController<bool>();
      final file = await File(
        '${dir.path}/pending-reconnect.mp4',
      ).writeAsBytes([1]);
      await storage.saveFeedbackUploadQueue([
        {
          'id': 'A-pending',
          'file_path': file.path,
          'status': 'queued',
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          ...storage.queueIdentity,
        },
      ]);
      final repository = BlockingFeedbackRepository();
      final service = FeedbackUploadQueueService(
        repository,
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => current != null,
        connectivityChanges: connectivity.stream,
      );
      addTearDown(() async {
        await service.dispose();
        await connectivity.close();
      });
      final initialization = service.init();
      await repository.firstUploadStarted.future;
      connectivity.add(true);
      await Future<void>.delayed(Duration.zero);
      current = const LocalAuthSession(uid: 'B', generation: 2);
      final nextAttempt = DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String();
      await storage.saveFeedbackUploadQueue([
        {
          'id': 'B-pending',
          'file_path': file.path,
          'status': 'queued',
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          ...storage.queueIdentity,
          'last_error': 'network_connectionError_0',
          'next_attempt_at': nextAttempt,
        },
      ]);
      repository.releaseFirstUpload.complete();
      await initialization;
      await service.processQueue();
      expect(repository.uploadCalls, 1);
      expect(repository.createCalls, 0);
      expect(storage.getFeedbackUploadQueue().single['id'], 'B-pending');
      expect(
        storage.getFeedbackUploadQueue().single['next_attempt_at'],
        nextAttempt,
      );
      current = const LocalAuthSession(uid: 'A', generation: 3);
      expect(storage.getFeedbackUploadQueue().single['status'], 'uploading');
      expect(await file.exists(), isTrue);
    },
  );
  test(
    'active workouts are isolated by owner/environment and stale writers are rejected',
    () async {
      final bound = storage.bindActiveWorkoutStore();
      const workout = ActiveWorkoutHiveModel(
        trainingId: 't',
        exerciseId: 'e',
        currentSet: 2,
        completedSets: 1,
      );
      await bound.saveActiveWorkout(workout);
      final otherEnvironment = LocalStorage(
        currentSession: () => current,
        environment: 'https://other.invalid',
      );
      expect(otherEnvironment.getActiveWorkout('e'), isNull);
      current = const LocalAuthSession(uid: 'B', generation: 2);
      expect(storage.getActiveWorkouts(), isEmpty);
      await expectLater(
        bound.saveActiveWorkout(workout),
        throwsA(isA<LocalSessionChanged>()),
      );
      await expectLater(
        bound.removeActiveWorkout('e'),
        throwsA(isA<LocalSessionChanged>()),
      );
      current = const LocalAuthSession(uid: 'A', generation: 3);
      expect(storage.getActiveWorkout('e')?.completedSets, 1);
    },
  );
  test(
    'unknown queue formats are quarantined and survive supported-queue writes',
    () async {
      await storage.saveFeedbackUploadQueue([
        {'id': 'future', ...storage.queueIdentity, 'format_version': 99},
      ]);
      expect(storage.getFeedbackUploadQueue(), isEmpty);
      await storage.saveFeedbackUploadQueue([
        {'id': 'known', ...storage.queueIdentity, 'status': 'queued'},
      ]);
      expect(storage.getFeedbackUploadQueue().single['id'], 'known');
      final raw = Hive.box(
        'cache_box',
      ).values.whereType<List>().expand((items) => items).whereType<Map>();
      expect(raw.any((row) => row['id'] == 'future'), true);
    },
  );
  test(
    'an old feedback form cannot enqueue A media after login as B',
    () async {
      final file = await File('${dir.path}/form.mp4').writeAsBytes([1]);
      final expected = storage.sessionStamp;
      final service = FeedbackUploadQueueService(
        BlockingFeedbackRepository(),
        storage,
        FakeOfflineSyncService(storage),
        isAuthenticated: () => true,
      );
      current = const LocalAuthSession(uid: 'B', generation: 2);
      await expectLater(
        service.enqueue(
          file: file,
          contentType: 'video/mp4',
          mediaType: 'VIDEO',
          expectedSession: expected,
        ),
        throwsA(isA<LocalSessionChanged>()),
      );
      expect(storage.getFeedbackUploadQueue(), isEmpty);
      expect(await file.exists(), true);
    },
  );
  test(
    'review: unsupported opaque queue entries survive writes without adoption',
    () async {
      await storage.cacheData('feedback_upload_queue', [
        'opaque-future-format',
        ['future', 99],
        {'id': 'future', ...storage.queueIdentity, 'format_version': 99},
      ]);
      expect(storage.getFeedbackUploadQueue(), isEmpty);
      await storage.saveFeedbackUploadQueue([
        {'id': 'supported', ...storage.queueIdentity, 'status': 'queued'},
      ]);
      expect(storage.getFeedbackUploadQueue().single['id'], 'supported');
      expect(
        storage.getCachedList('feedback_upload_queue'),
        contains('opaque-future-format'),
      );
      expect(
        storage.getCachedList('feedback_upload_queue'),
        contains(equals(['future', 99])),
      );
    },
  );
}
