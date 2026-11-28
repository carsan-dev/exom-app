// Drafts written by earlier versions may hold a set with only RIR (no reps,
// seconds or weight). Owner decision (P3, «reparar al leer, sin migración»):
// that set is not registered. On restore it does not count as done, it becomes
// the pending set again and its RIR is kept, while the Hive draft is not
// rewritten until the user saves that set. A completion identity that already
// exists is frozen: such a draft completes as it is and the replay leaves the
// set out of the request.
import 'package:dio/dio.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/services/offline_sync_service_test.dart'
    show FakeSyncStorage, respondingClient;

const _date = '2026-11-18';
const _key = 'ex-1:$_date';

class _Store implements ActiveWorkoutLocalStore {
  final Map<String, ActiveWorkoutHiveModel> data = {};
  final writes = <ActiveWorkoutHiveModel>[];

  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) =>
      data[exerciseId];

  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout) async {
    data[workout.exerciseId] = workout;
    writes.add(workout);
  }

  @override
  Future<void> removeActiveWorkout(String exerciseId) async {
    data.remove(exerciseId);
  }
}

class _Native implements RestTimerCoordinator {
  @override
  RestTimerSession? activeSession;

  @override
  Future<void> start(RestTimerSession session) async => activeSession = session;

  @override
  Future<void> finish() async => activeSession = null;

  @override
  Future<void> cancel() async => activeSession = null;
}

TrainingExerciseEntity _exercise({int sets = 4, int restSeconds = 90}) =>
    TrainingExerciseEntity(
      id: 'te-1',
      order: 1,
      sets: sets,
      repsOrDuration: '8',
      measureType: ExerciseMeasureType.reps,
      targetValue: 8,
      targetRir: 2,
      restSeconds: restSeconds,
      exercise: const ExerciseEntity(id: 'ex-1', name: 'Remo', muscleGroups: []),
    );

ActiveWorkoutHiveModel _draft({
  required int completedSets,
  required int currentSet,
  required List<Map<String, dynamic>> sets,
  String? completionOperationId,
}) => ActiveWorkoutHiveModel(
  trainingId: 't-1',
  exerciseId: _key,
  currentSet: currentSet,
  completedSets: completedSets,
  lastWeightKg: 60.0,
  completedSetData: sets,
  completionOperationId: completionOperationId,
);

Future<ActiveExerciseBloc> _restore(
  _Store store,
  ActiveWorkoutHiveModel draft, {
  TrainingExerciseEntity? exercise,
}) async {
  store.data[draft.exerciseId] = draft;
  final bloc = ActiveExerciseBloc(
    localStorage: store,
    trainingExercise: exercise ?? _exercise(),
    restTimerCoordinator: _Native(),
  );
  bloc.add(const StartExercise(
    trainingId: 't-1',
    exerciseId: 'ex-1',
    assignmentDate: _date,
  ));
  await pumpEventQueue();
  return bloc;
}

void _expectSameDraft(ActiveWorkoutHiveModel actual, ActiveWorkoutHiveModel expected) {
  expect(actual.trainingId, expected.trainingId);
  expect(actual.sessionId, expected.sessionId);
  expect(actual.currentSet, expected.currentSet);
  expect(actual.completedSets, expected.completedSets);
  expect(actual.restEndsAt, expected.restEndsAt);
  expect(actual.lastWeightKg, expected.lastWeightKg);
  expect(actual.completedSetData, expected.completedSetData);
  expect(actual.lastSetFeedbackClientUploadId,
      expected.lastSetFeedbackClientUploadId);
  expect(actual.completionOperationId, expected.completionOperationId);
}

const _rirOnly = {'set_number': 1, 'rir': 4};
const _valid2 = {'set_number': 2, 'reps': 8, 'weight_kg': 60.0, 'rir': 8};

void main() {
  test('a restored RIR-only set is pending again and the draft is not '
      'rewritten', () async {
    final store = _Store();
    final draft = _draft(
      completedSets: 2, currentSet: 3, sets: const [_rirOnly, _valid2]);
    final bloc = await _restore(store, draft);

    expect(bloc.state.status, ActiveExerciseStatus.executing);
    expect(bloc.state.currentSet, 1);
    expect(bloc.state.unregisteredSets, {1});
    expect(bloc.state.registeredSets, 1);
    expect(bloc.state.currentUnregisteredRir, 4);
    _expectSameDraft(store.data[_key]!, draft);
    await bloc.close();
  });

  test('saving the pending set replaces it in place and moves on to the next '
      'set', () async {
    final store = _Store();
    final bloc = await _restore(store, _draft(
      completedSets: 2, currentSet: 3, sets: const [_rirOnly, _valid2]));

    bloc.add(const CompleteSet(reps: 7, weightKg: 62.5, rir: 4));
    await pumpEventQueue();

    expect(bloc.state.completedSets, 2);
    expect(bloc.state.unregisteredSets, isEmpty);
    expect(bloc.state.status, ActiveExerciseStatus.resting);
    expect(bloc.state.currentSet, 3);
    final saved = store.data[_key]!;
    expect(saved.completedSets, 2);
    expect(saved.currentSet, 3);
    expect(saved.completedSetData, [
      {'set_number': 1, 'reps': 7, 'weight_kg': 62.5, 'rir': 4},
      _valid2,
    ]);
    await bloc.close();
  });

  test('with two pending sets the next one follows after saving the first',
      () async {
    final store = _Store();
    final bloc = await _restore(store, _draft(
      completedSets: 3,
      currentSet: 4,
      sets: const [_rirOnly, _valid2, {'set_number': 3, 'rir': 1}],
    ), exercise: _exercise(restSeconds: 0));
    expect(bloc.state.currentSet, 1);

    bloc.add(const CompleteSet(reps: 8, weightKg: 60.0, rir: 4));
    await pumpEventQueue();
    expect(bloc.state.status, ActiveExerciseStatus.executing);
    expect(bloc.state.currentSet, 3);
    expect(store.data[_key]!.currentSet, 4,
        reason: 'the persisted cursor keeps its meaning for older versions');

    bloc.add(const CompleteSet(reps: 8, weightKg: 60.0, rir: 1));
    await pumpEventQueue();
    expect(bloc.state.currentSet, 4);
    expect(bloc.state.registeredSets, 3);

    bloc.add(const CompleteSet(reps: 5, weightKg: 70.0, rir: 2));
    await pumpEventQueue();
    final persisted = store.data[_key]!.completedSetData;
    expect(persisted.map((s) => s['set_number']), [1, 2, 3, 4],
        reason: 'ordered by set_number, no duplicates, no gaps');
    expect(persisted[0],
        {'set_number': 1, 'reps': 8, 'weight_kg': 60.0, 'rir': 4});
    expect(persisted[1], _valid2, reason: 'valid set stays intact');
    expect(persisted[2],
        {'set_number': 3, 'reps': 8, 'weight_kg': 60.0, 'rir': 1});
    expect(persisted[3],
        {'set_number': 4, 'reps': 5, 'weight_kg': 70.0, 'rir': 2},
        reason: 'the new set is appended last with its values');
    await bloc.close();
  });

  test('a full draft whose last set is RIR-only is not done until that set is '
      'saved', () async {
    final store = _Store();
    final draft = _draft(completedSets: 4, currentSet: 4, sets: const [
      {'set_number': 1, 'reps': 8},
      {'set_number': 2, 'reps': 8},
      {'set_number': 3, 'reps': 8},
      {'set_number': 4, 'rir': 0},
    ]);
    final bloc = await _restore(store, draft,
        exercise: _exercise(restSeconds: 0));

    expect(bloc.state.status, ActiveExerciseStatus.executing);
    expect(bloc.state.currentSet, 4);
    expect(bloc.state.completionOperationId, isNull);
    _expectSameDraft(store.data[_key]!, draft);

    bloc.add(const CompleteSet(reps: 6, rir: 0));
    await pumpEventQueue();
    expect(bloc.state.status, ActiveExerciseStatus.done);
    expect(bloc.state.completionOperationId, isNotNull);
    expect(store.data[_key]!.completedSetData.last,
        {'set_number': 4, 'reps': 6, 'rir': 0});
    await bloc.close();
  });

  test('completing a pending optional set without values leaves no RIR-only '
      'entry behind', () async {
    final store = _Store();
    final bloc = await _restore(store, _draft(
      completedSets: 2, currentSet: 3, sets: const [_rirOnly, _valid2]));

    bloc.add(const CompleteSet());
    await pumpEventQueue();

    expect(bloc.state.unregisteredSets, isEmpty);
    expect(bloc.state.completedSets, 2);
    expect(store.data[_key]!.completedSetData, [_valid2]);
    await bloc.close();
  });

  test('a draft with a completion identity keeps it frozen and completes as it '
      'is', () async {
    final store = _Store();
    final draft = _draft(completedSets: 4, currentSet: 4,
        completionOperationId: 'op-frozen', sets: const [
          {'set_number': 1, 'reps': 8},
          {'set_number': 2, 'reps': 8},
          {'set_number': 3, 'reps': 8},
          {'set_number': 4, 'rir': 0},
        ]);
    final bloc = await _restore(store, draft,
        exercise: _exercise(restSeconds: 0));

    expect(bloc.state.status, ActiveExerciseStatus.done);
    expect(bloc.state.completionOperationId, 'op-frozen');
    // Still not registered (not counted as done), but not reopened.
    expect(bloc.state.unregisteredSets, {4});
    expect(bloc.state.registeredSets, 3);
    _expectSameDraft(store.data[_key]!, draft);
    await bloc.close();
  });

  group('end to end: Hive draft -> restore -> complete -> request', () {
    Future<Map<String, dynamic>> complete(ActiveExerciseState state) async {
      final requests = <Map<String, dynamic>>[];
      final storage = FakeSyncStorage();
      final sync = OfflineSyncService(
        respondingClient((options, handler) {
          requests.add(Map<String, dynamic>.from(options.data as Map));
          handler.resolve(Response(requestOptions: options, statusCode: 200,
            data: {'operation_revision': 1, 'sync_revision': 1,
              'exercises_completed': <Map<String, dynamic>>[],
              'meals_completed': <String>[]}));
        }),
        storage,
        isAuthenticated: () => true,
        authenticationChanges: const Stream<bool>.empty(),
        connectivityChanges: const Stream<bool>.empty(),
      );
      // Same arguments the active exercise page sends on completion.
      await sync.queueExerciseCompletion('te-1', _date,
          completed: true,
          exerciseId: 'ex-1',
          weightUsed: state.weightKg,
          sets: state.setPerformances,
          operationId: state.completionOperationId);
      await sync.syncPendingActions();
      await sync.dispose();
      expect(storage.actions, isEmpty);
      return requests.single;
    }

    test('a frozen finished draft is sent without its RIR-only set', () async {
      final store = _Store();
      final bloc = await _restore(store, _draft(
        completedSets: 2, currentSet: 2, completionOperationId: 'op-1',
        sets: const [_rirOnly, _valid2]), exercise: _exercise(sets: 2));
      expect(bloc.state.isDone, isTrue);

      final request = await complete(bloc.state);
      expect(request['sets'], [_valid2]);
      await bloc.close();
    });

    test('a pending set saved by the user is sent with its new values',
        () async {
      final store = _Store();
      final bloc = await _restore(store, _draft(
        completedSets: 2, currentSet: 2, sets: const [_rirOnly, _valid2]),
        exercise: _exercise(sets: 2, restSeconds: 0));
      expect(bloc.state.isDone, isFalse);

      bloc.add(const CompleteSet(reps: 8, weightKg: 60.0, rir: 4));
      await pumpEventQueue();
      expect(bloc.state.isDone, isTrue);

      final request = await complete(bloc.state);
      expect(request['sets'], [
        {'set_number': 1, 'reps': 8, 'weight_kg': 60.0, 'rir': 4},
        _valid2,
      ]);
      await bloc.close();
    });
  });
}
