import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late LocalAuthSession? current;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-completion-draft-');
    Hive.init(directory.path);
    await Hive.openBox('cache_box');
    if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
      Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
    }
    await Hive.openBox<ActiveWorkoutHiveModel>('active_workout_box');
    current = const LocalAuthSession(uid: 'A', generation: 1);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('global pending executions keep distinct identities across days and owners', () async {
    final storage = LocalStorage(currentSession: () => current, environment: 'test-A');
    final first = await storage.createTrainingExecution('same', '2026-09-05');
    final second = await storage.createTrainingExecution('same', '2026-09-05');
    final older = await storage.createTrainingExecution('other', '2026-08-12');
    await storage.setTrainingExecutionStatus(second, 'pending-sync');
    expect(storage.getPendingTrainingExecutions().map((entry) => entry['id']).toSet(),
        {first, second, older});
    expect(storage.getPendingTrainingExecutions().singleWhere(
        (entry) => entry['id'] == second)['status'], 'pending-sync');
    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(storage.getPendingTrainingExecutions(), isEmpty);
    current = const LocalAuthSession(uid: 'A', generation: 3);
    expect(LocalStorage(currentSession: () => current, environment: 'test-B')
        .getPendingTrainingExecutions(), isEmpty);
    expect(storage.getPendingTrainingExecutions().length, 3);
    await storage.saveActiveWorkout(ActiveWorkoutHiveModel(
        trainingId: 'same', sessionId: first,
        exerciseId: 'exercise:2026-09-05:$first',
        currentSet: 1, completedSets: 1));
    await storage.completeTrainingExecution(first);
    expect(storage.getPendingTrainingExecutions().map((entry) => entry['id']),
        isNot(contains(first)));
  });

  test('confirmed display candidates remain scoped and do not re-enter pending writes', () async {
    final storage = LocalStorage(currentSession: () => current, environment: 'test-A');
    final confirmed = await storage.createTrainingExecution('training', '2026-09-05');
    final pending = await storage.createTrainingExecution('training', '2026-09-05');
    final otherDate = await storage.createTrainingExecution('training', '2026-09-06');
    final otherTraining = await storage.createTrainingExecution('other', '2026-09-05');
    await storage.completeTrainingExecution(confirmed);
    await storage.completeTrainingExecution(otherDate);
    await storage.completeTrainingExecution(otherTraining);
    expect(storage.getConfirmedTrainingExecutions('training', '2026-09-05')
        .map((entry) => entry['id']), [confirmed]);
    expect(storage.getPendingTrainingExecutions().map((entry) => entry['id']), [pending]);
    await storage.cacheData('training_executions', [
      ...storage.getCachedList('training_executions')!,
      {'id': '', 'training_id': 'training', 'assignment_date': '2026-09-05', 'status': 'confirmed'},
      {'id': 'unbound', 'status': 'confirmed'},
    ]);
    expect(storage.getConfirmedTrainingExecutions('training', '2026-09-05')
        .map((entry) => entry['id']), [confirmed]);
    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(storage.getConfirmedTrainingExecutions('training', '2026-09-05'), isEmpty);
    current = null;
    expect(storage.getConfirmedTrainingExecutions('training', '2026-09-05'), isEmpty);
    current = const LocalAuthSession(uid: 'A', generation: 3);
    expect(LocalStorage(currentSession: () => current, environment: 'test-B')
        .getConfirmedTrainingExecutions('training', '2026-09-05'), isEmpty);
    expect(storage.getConfirmedTrainingExecutions('training', '2026-09-05').single['id'], confirmed);
  });

  test('restart after durable enqueue but before execution status write derives pending sync from the exact action', () async {
    LocalStorage storage = LocalStorage(currentSession: () => current, environment: 'test-A');
    final id = await storage.createTrainingExecution('training', '2026-09-05');
    await storage.saveTrainingCompletionDraft('training', '2026-09-05', id,
        rpe: 8, notes: 'Original');
    final action = <String, dynamic>{
      ...storage.queueIdentity,
      'id': 'operation-123', 'type': 'complete_training',
      'training_id': 'training', 'date': '2026-09-05',
      'training_session_id': id, 'rpe': 8, 'notes': 'Original',
      'status': 'queued', 'attempts': 0,
    };
    await storage.savePendingSyncActions([action]); // crash: no status write
    storage = LocalStorage(currentSession: () => current, environment: 'test-A');
    expect(storage.getPendingSyncActions().single, containsPair('id', 'operation-123'));
    expect(storage.getPendingSyncActions().single, containsPair('notes', 'Original'));
    expect(storage.getPendingTrainingExecutions().single['status'], 'pending-sync');
    expect(storage.getTrainingExecutions('training', '2026-09-05'), isEmpty);
    await storage.savePendingSyncActions([{...action, 'status': 'uploading'}]);
    expect(storage.getPendingTrainingExecutions().single['status'], 'pending-sync');
    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(storage.getPendingTrainingExecutions(), isEmpty);
    current = const LocalAuthSession(uid: 'A', generation: 3);
    expect(LocalStorage(currentSession: () => current, environment: 'test-B')
        .getPendingSyncActions(), isEmpty);

    await storage.savePendingSyncActions([{...action, 'status': 'failed'}]);
    expect(storage.getTrainingExecutions('training', '2026-09-05').single['status'], 'failed');
    await storage.savePendingSyncActions([{
      ...action, 'status': 'failed',
      'last_error': 'progress_conflict_review_required',
    }]);
    expect(storage.getTrainingExecutions('training', '2026-09-05').single['status'], 'conflict');
    await storage.savePendingSyncActions([{...action, 'training_session_id': null}]);
    expect(storage.getTrainingExecutions('training', '2026-09-05').single['status'], 'pending-finalize');
    await storage.savePendingSyncActions([{...action, 'training_id': 'other'}]);
    expect(storage.getTrainingExecutions('training', '2026-09-05').single['status'], 'pending-finalize');
    await storage.savePendingSyncActions([{...action, 'type': 'mark_exercise_completed'}]);
    expect(storage.getTrainingExecutions('training', '2026-09-05').single['status'], 'pending-finalize');
    await storage.savePendingSyncActions([action]);
    await storage.completeTrainingExecution(id);
    expect(storage.getPendingTrainingExecutions(), isEmpty);
    expect(storage.getTrainingExecutions('training', '2026-09-05'), isEmpty);
  });

  test('failed and discarded completion remains recoverable without new RPE', () async {
    final storage = LocalStorage(currentSession: () => current, environment: 'test-A');
    final id = await storage.createTrainingExecution('training', '2026-09-05');
    await storage.saveTrainingCompletionDraft('training', '2026-09-05', id,
        rpe: 8, notes: 'Original');
    await storage.setTrainingExecutionStatus(id, 'pending-sync');
    expect(storage.getTrainingExecutions('training', '2026-09-05'), isEmpty);
    await storage.setTrainingExecutionStatus(id, 'failed');
    expect(storage.getTrainingExecutions('training', '2026-09-05').single['id'], id);
    expect(storage.getTrainingCompletionDraft('training', '2026-09-05', id),
        containsPair('rpe', 8));
    await storage.setTrainingExecutionStatus(id, 'pending-sync');
    await storage.setTrainingExecutionStatus(id, 'failed'); // action discarded
    expect(storage.getTrainingExecutions('training', '2026-09-05').single['status'], 'failed');
    expect(storage.getTrainingCompletionDraft('training', '2026-09-05', id),
        containsPair('notes', 'Original'));
    expect(storage.hasCompletedTrainingExecution('training', '2026-09-05'), isFalse);
  });

  test('completion draft survives storage restart but never crosses owner, environment or execution', () async {
    LocalStorage storage = LocalStorage(currentSession: () => current, environment: 'test-A');
    final execution = await storage.createTrainingExecution('training', '2026-09-05');
    await storage.saveTrainingCompletionDraft('training', '2026-09-05', execution,
        rpe: 8, notes: ' Hard session ');
    await storage.clearCache();
    storage = LocalStorage(currentSession: () => current, environment: 'test-A');
    expect(storage.getTrainingCompletionDraft('training', '2026-09-05', execution),
        containsPair('notes', 'Hard session'));
    expect(storage.getTrainingCompletionDraft('training', '2026-09-05', execution),
        containsPair('rpe', 8));
    expect(storage.getTrainingCompletionDraft('training', '2026-09-06', execution), isNull);
    expect(storage.getTrainingCompletionDraft('training', '2026-09-05', 'other'), isNull);
    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(storage.getTrainingCompletionDraft('training', '2026-09-05', execution), isNull);
    current = const LocalAuthSession(uid: 'A', generation: 3);
    expect(LocalStorage(currentSession: () => current, environment: 'test-B')
        .getTrainingCompletionDraft('training', '2026-09-05', execution), isNull);
    await storage.completeTrainingExecution(execution);
    expect(storage.getTrainingCompletionDraft('training', '2026-09-05', execution), isNull);
  });
}
