import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late LocalAuthSession? current;
  late LocalStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-legacy-workout-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
      Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
    }
    await Hive.openBox('cache_box');
    await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
    current = const LocalAuthSession(uid: 'A', generation: 1);
    storage = LocalStorage(currentSession: () => current, environment: 'test-A');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('explicit recovery binds scoped date draft to an execution without losing sets', () async {
    const key = 'exercise:2026-09-24';
    await storage.saveActiveWorkout(const ActiveWorkoutHiveModel(
      trainingId: 'training', exerciseId: key, currentSet: 2,
      completedSets: 1, completedSetData: [{'set_number': 1, 'reps': 8}],
    ));
    expect(storage.recoverableLegacyWorkout('training', 'exercise', '2026-09-24'), isNotNull);
    final id = await storage.recoverLegacyWorkout('training', 'exercise', '2026-09-24');
    expect(storage.getActiveWorkout('exercise:2026-09-24:$id')?.completedSetData,
        [{'set_number': 1, 'reps': 8}]);
    expect(storage.getActiveWorkout('exercise:2026-09-24:$id')?.sessionId, id);
    expect(storage.getActiveWorkout(key), isNull);
    expect(storage.getTrainingExecutions('training', '2026-09-24').single['id'], id);
  });

  test('concurrent recovery of one draft persists only one execution and copy', () async {
    const key = 'exercise:2026-09-24';
    await storage.saveActiveWorkout(const ActiveWorkoutHiveModel(
      trainingId: 'training', exerciseId: key, currentSet: 2,
      completedSets: 1, completedSetData: [{'set_number': 1, 'reps': 8}],
    ));
    final gate = _PausedRegistryStore(() => current);
    final first = gate.recoverLegacyWorkout('training', 'exercise', '2026-09-24');
    await gate.registryWriteStarted.future;
    final second = storage.recoverLegacyWorkout('training', 'exercise', '2026-09-24');
    // Both calls are live while the first registry write is still suspended.
    gate.resumeRegistryWrite.complete();
    final ids = await Future.wait([first, second]);
    expect(ids[0], ids[1]);
    expect(storage.getCachedList('training_executions'), hasLength(1));
    expect(storage.getActiveWorkouts().where((draft) => draft.sessionId != null),
        hasLength(1));
    expect(storage.getActiveWorkout('exercise:2026-09-24:${ids[0]}')?.completedSetData,
        [{'set_number': 1, 'reps': 8}]);
  });

  test('queued recovery fails closed when the auth generation changes', () async {
    const key = 'exercise:2026-09-24';
    await storage.saveActiveWorkout(const ActiveWorkoutHiveModel(
      trainingId: 'training', exerciseId: key, currentSet: 2,
      completedSets: 0,
    ));
    final gate = _PausedRegistryStore(() => current);
    final first = gate.recoverLegacyWorkout('training', 'exercise', '2026-09-24');
    await gate.registryWriteStarted.future;
    final second = storage.recoverLegacyWorkout('training', 'exercise', '2026-09-24');
    current = const LocalAuthSession(uid: 'A', generation: 2);
    gate.resumeRegistryWrite.complete();
    await expectLater(first, throwsA(isA<LocalSessionChanged>()));
    await expectLater(second, throwsA(isA<LocalSessionChanged>()));
    current = const LocalAuthSession(uid: 'A', generation: 1);
    expect(storage.getActiveWorkout(key), isNotNull);
    expect(storage.getCachedList('training_executions'), isNull);
  });

  test('a different draft is not held by a paused recovery', () async {
    for (final exercise in ['first', 'second']) {
      await storage.saveActiveWorkout(ActiveWorkoutHiveModel(
        trainingId: 'training', exerciseId: '$exercise:2026-09-24',
        currentSet: 2, completedSets: 0,
      ));
    }
    final gate = _PausedRegistryStore(() => current);
    final first = gate.recoverLegacyWorkout('training', 'first', '2026-09-24');
    await gate.registryWriteStarted.future;
    try {
      final other = await storage.recoverLegacyWorkout(
        'training', 'second', '2026-09-24',
      ).timeout(const Duration(seconds: 2));
      expect(storage.getActiveWorkout('second:2026-09-24:$other'), isNotNull);
    } finally {
      gate.resumeRegistryWrite.complete();
    }
    await first;
  });

  test('interrupted recovery reuses pending identity without overwriting newer sets', () async {
    const key = 'exercise:2026-09-24';
    await storage.saveActiveWorkout(const ActiveWorkoutHiveModel(
      trainingId: 'training', exerciseId: key, currentSet: 2, completedSets: 1,
    ));
    await storage.cacheData('training_executions', [{
      'id': 'original', 'training_id': 'training',
      'assignment_date': '2026-09-24', 'status': 'pending',
      'legacy_draft_key': key,
    }]);
    await storage.saveActiveWorkout(const ActiveWorkoutHiveModel(
      trainingId: 'training', sessionId: 'original',
      exerciseId: 'exercise:2026-09-24:original',
      currentSet: 3, completedSets: 2,
    ));
    final id = await storage.recoverLegacyWorkout('training', 'exercise', '2026-09-24');
    expect(id, 'original');
    expect(storage.getActiveWorkout('exercise:2026-09-24:original')?.completedSets, 2);
    expect(storage.getActiveWorkout(key)?.completedSets, 1);
    expect(storage.getTrainingExecutions('training', '2026-09-24'), hasLength(1));
  });

  for (final status in ['pending-sync', 'failed']) {
    test('interrupted copy reuses its execution after status changes to $status', () async {
      const key = 'exercise:2026-09-24';
      await storage.saveActiveWorkout(const ActiveWorkoutHiveModel(
        trainingId: 'training', exerciseId: key, currentSet: 2,
        completedSets: 1, completedSetData: [{'set_number': 1, 'reps': 8}],
      ));
      // The registry and copy were persisted, but deleting the source failed.
      await storage.cacheData('training_executions', [
        {
          'id': 'original', 'training_id': 'training',
          'assignment_date': '2026-09-24', 'status': status,
          'legacy_draft_key': key,
        },
        {
          'id': 'other', 'training_id': 'training',
          'assignment_date': '2026-09-24', 'status': 'pending',
          'legacy_draft_key': 'different-exercise:2026-09-24',
        },
      ]);
      await storage.saveActiveWorkout(const ActiveWorkoutHiveModel(
        trainingId: 'training', sessionId: 'original',
        exerciseId: 'exercise:2026-09-24:original', currentSet: 3,
        completedSets: 2, completedSetData: [
          {'set_number': 1, 'reps': 8}, {'set_number': 2, 'reps': 10},
        ],
      ));

      expect(await storage.recoverLegacyWorkout('training', 'exercise', '2026-09-24'),
          'original');
      expect(storage.getCachedList('training_executions'), hasLength(2));
      expect(storage.getActiveWorkout('exercise:2026-09-24:original')?.completedSetData,
          [{'set_number': 1, 'reps': 8}, {'set_number': 2, 'reps': 10}]);
      expect(storage.getActiveWorkout(key)?.completedSetData,
          [{'set_number': 1, 'reps': 8}]);
    });
  }

  test('unscoped and foreign drafts stay quarantined across account and environment', () async {
    await Hive.box<ActiveWorkoutHiveModel>('active_workout_box').put(
      'exercise:2026-09-24', const ActiveWorkoutHiveModel(
        trainingId: 'training', exerciseId: 'exercise:2026-09-24',
        currentSet: 2, completedSets: 1,
      ));
    expect(storage.hasQuarantinedWorkoutDrafts, isTrue);
    expect(storage.recoverableLegacyWorkout('training', 'exercise', '2026-09-24'), isNull);
    expect(() => storage.recoverLegacyWorkout('training', 'exercise', '2026-09-24'),
        throwsA(isA<StateError>()));
    await storage.saveActiveWorkout(const ActiveWorkoutHiveModel(
      trainingId: 'training', exerciseId: 'exercise:2026-09-25',
      currentSet: 2, completedSets: 1,
    ));
    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(storage.recoverableLegacyWorkout('training', 'exercise', '2026-09-25'), isNull);
    final otherEnvironment = LocalStorage(
      currentSession: () => current, environment: 'test-B');
    expect(otherEnvironment.recoverableLegacyWorkout('training', 'exercise', '2026-09-25'), isNull);
    expect(Hive.box<ActiveWorkoutHiveModel>('active_workout_box').containsKey('exercise:2026-09-24'), isTrue);
  });
}

class _PausedRegistryStore extends LocalStorage {
  _PausedRegistryStore(LocalAuthSession? Function() currentSession)
      : super(currentSession: currentSession, environment: 'test-A');

  final registryWriteStarted = Completer<void>();
  final resumeRegistryWrite = Completer<void>();

  @override
  Future<void> cacheData(String key, dynamic value) async {
    if (key == 'training_executions' && !registryWriteStarted.isCompleted) {
      registryWriteStarted.complete();
      await resumeRegistryWrite.future;
    }
    await super.cacheData(key, value);
  }
}
