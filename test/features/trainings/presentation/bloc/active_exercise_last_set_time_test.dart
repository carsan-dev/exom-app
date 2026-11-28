import 'dart:io';

import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

// C-O1: the completion time of an exercise is the time of its last logged
// set. It is captured when the set is logged, survives the final rest and a
// restart through the draft, and is what the completion carries.

class _Store implements ActiveWorkoutLocalStore {
  final Map<String, ActiveWorkoutHiveModel> data = {};

  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) =>
      data[exerciseId];

  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout) async {
    data[workout.exerciseId] = workout;
  }

  @override
  Future<void> removeActiveWorkout(String exerciseId) async {
    data.remove(exerciseId);
  }
}

class _Rest implements RestTimerCoordinator {
  @override
  RestTimerSession? activeSession;

  @override
  Future<void> start(RestTimerSession session) async => activeSession = session;

  @override
  Future<void> finish() async => activeSession = null;

  @override
  Future<void> cancel() async => activeSession = null;
}

// Adapter as it was before field 14 (c56bb8e): 14 fields, indexes 0-13.
class _PreLastSetLoggedAtAdapter extends TypeAdapter<ActiveWorkoutHiveModel> {
  @override
  final int typeId = ActiveWorkoutHiveModel.typeId;

  @override
  ActiveWorkoutHiveModel read(BinaryReader reader) =>
      throw UnimplementedError('write-only');

  @override
  void write(BinaryWriter writer, ActiveWorkoutHiveModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.trainingId)
      ..writeByte(1)
      ..write(obj.exerciseId)
      ..writeByte(2)
      ..write(obj.currentSet)
      ..writeByte(3)
      ..write(obj.completedSets)
      ..writeByte(4)
      ..write(obj.restEndsAt)
      ..writeByte(5)
      ..write(obj.lastWeightKg)
      ..writeByte(6)
      ..write(obj.completedSetData)
      ..writeByte(7)
      ..write(obj.lastSetFeedbackClientUploadId)
      ..writeByte(8)
      ..write(obj.timedElapsedMs)
      ..writeByte(9)
      ..write(obj.timedStartedAt)
      ..writeByte(10)
      ..write(obj.timedTotalSeconds)
      ..writeByte(11)
      ..write(obj.timedPrescription?.toJson())
      ..writeByte(12)
      ..write(obj.sessionId)
      ..writeByte(13)
      ..write(obj.completionOperationId);
  }
}

TrainingExerciseEntity _exercise({int sets = 2, int restSeconds = 90}) =>
    TrainingExerciseEntity(
      id: 'te-1',
      order: 1,
      sets: sets,
      repsOrDuration: '10 reps',
      restSeconds: restSeconds,
      exercise: const ExerciseEntity(
        id: 'ex-1',
        name: 'Press banca',
        muscleGroups: ['pecho'],
      ),
    );

const _start = StartExercise(
  trainingId: 't-1',
  exerciseId: 'ex-1',
  assignmentDate: '2026-11-27',
  sessionId: 'execution-1',
);
const _key = 'ex-1:2026-11-27:execution-1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the last logged set dates the completion, not the end of the final '
      'rest', () async {
    var now = DateTime.utc(2026, 11, 27, 13, 50);
    final store = _Store();
    final bloc = ActiveExerciseBloc(
      localStorage: store,
      trainingExercise: _exercise(),
      restTimerCoordinator: _Rest(),
      now: () => now,
    );
    bloc.add(_start);
    await pumpEventQueue();
    expect(bloc.state.lastSetLoggedAt, isNull);

    bloc.add(const CompleteSet(reps: 10, weightKg: 60));
    await pumpEventQueue();
    expect(bloc.state.lastSetLoggedAt, DateTime.utc(2026, 11, 27, 13, 50));

    now = DateTime.utc(2026, 11, 27, 13, 52);
    bloc.add(const SkipRest());
    await pumpEventQueue();
    now = DateTime.utc(2026, 11, 27, 13, 56, 51, 120);
    bloc.add(const CompleteSet(reps: 8, weightKg: 60));
    await pumpEventQueue();
    expect(bloc.state.isFinalResting, isTrue);
    expect(store.data[_key]!.lastSetLoggedAt!.toUtc(),
        DateTime.utc(2026, 11, 27, 13, 56, 51, 120));

    now = DateTime.utc(2026, 11, 27, 13, 58, 21);
    bloc.add(const SkipRest());
    await pumpEventQueue();
    expect(bloc.state.isDone, isTrue);
    expect(bloc.state.completionOperationId, isNotNull);
    expect(bloc.state.lastSetLoggedAt!.toUtc(),
        DateTime.utc(2026, 11, 27, 13, 56, 51, 120));
    await bloc.close();

    final restarted = ActiveExerciseBloc(
      localStorage: store,
      trainingExercise: _exercise(),
      restTimerCoordinator: _Rest(),
      now: () => now,
    );
    restarted.add(_start);
    await pumpEventQueue();
    expect(restarted.state.isDone, isTrue);
    expect(restarted.state.lastSetLoggedAt!.toUtc(),
        DateTime.utc(2026, 11, 27, 13, 56, 51, 120));
    await restarted.close();
  });

  test('a captured time is kept to the millisecond the draft stores',
      () async {
    final store = _Store();
    final bloc = ActiveExerciseBloc(
      localStorage: store,
      trainingExercise: _exercise(sets: 1, restSeconds: 0),
      restTimerCoordinator: _Rest(),
      now: () => DateTime.utc(2026, 11, 27, 13, 56, 51, 120, 987),
    );
    bloc.add(_start);
    await pumpEventQueue();
    bloc.add(const CompleteSet(reps: 10));
    await pumpEventQueue();
    expect(bloc.state.isDone, isTrue);
    expect(bloc.state.lastSetLoggedAt,
        DateTime.utc(2026, 11, 27, 13, 56, 51, 120));
    await bloc.close();
  });

  test('a draft written before the field restores without a time', () async {
    final store = _Store();
    store.data[_key] = const ActiveWorkoutHiveModel(
      trainingId: 't-1',
      sessionId: 'execution-1',
      exerciseId: _key,
      currentSet: 2,
      completedSets: 2,
      completedSetData: [
        {'set_number': 1, 'reps': 10},
        {'set_number': 2, 'reps': 8},
      ],
      completionOperationId: 'frozen-op',
    );
    final bloc = ActiveExerciseBloc(
      localStorage: store,
      trainingExercise: _exercise(),
      restTimerCoordinator: _Rest(),
    );
    bloc.add(_start);
    await pumpEventQueue();
    expect(bloc.state.isDone, isTrue);
    expect(bloc.state.completionOperationId, 'frozen-op');
    expect(bloc.state.lastSetLoggedAt, isNull);
    await bloc.close();
  });

  group('Hive draft adapter', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('exom-co1-draft-');
      Hive.init(directory.path);
      if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
        Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
      }
    });
    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('round-trips the last set time', () async {
      var box = await Hive.openBox<ActiveWorkoutHiveModel>('drafts');
      await box.put(
        _key,
        ActiveWorkoutHiveModel(
          trainingId: 't-1',
          exerciseId: _key,
          currentSet: 2,
          completedSets: 2,
          completionOperationId: 'op-1',
          lastSetLoggedAt: DateTime.utc(2026, 11, 27, 13, 56, 51, 120),
        ),
      );
      await Hive.close();
      box = await Hive.openBox<ActiveWorkoutHiveModel>('drafts');
      final read = box.get(_key)!;
      expect(read.lastSetLoggedAt!.toUtc(),
          DateTime.utc(2026, 11, 27, 13, 56, 51, 120));
      expect(read.completionOperationId, 'op-1');
      expect(read.copyWith(currentSet: 1).lastSetLoggedAt!.toUtc(),
          DateTime.utc(2026, 11, 27, 13, 56, 51, 120));
    });

    test('reads bytes written by the adapter without field 14', () async {
      Hive.registerAdapter(_PreLastSetLoggedAtAdapter(), override: true);
      var box = await Hive.openBox<ActiveWorkoutHiveModel>('legacy_drafts');
      await box.put(
        _key,
        ActiveWorkoutHiveModel(
          trainingId: 't-1',
          sessionId: 'execution-1',
          exerciseId: _key,
          currentSet: 3,
          completedSets: 2,
          lastWeightKg: 42.5,
          completedSetData: const [
            {'set_number': 1, 'reps': 10},
            {'set_number': 2, 'reps': 8},
          ],
          completionOperationId: 'frozen-op',
          timedElapsedMs: 1500,
          lastSetLoggedAt: DateTime.utc(2026, 11, 27), // not written
        ),
      );
      await Hive.close();
      Hive.registerAdapter(ActiveWorkoutHiveModelAdapter(), override: true);
      box = await Hive.openBox<ActiveWorkoutHiveModel>('legacy_drafts');
      final read = box.get(_key)!;
      expect(read.lastSetLoggedAt, isNull);
      expect(read.trainingId, 't-1');
      expect(read.sessionId, 'execution-1');
      expect(read.currentSet, 3);
      expect(read.completedSets, 2);
      expect(read.lastWeightKg, 42.5);
      expect(read.completedSetData.map((s) => s['reps']), [10, 8]);
      expect(read.completionOperationId, 'frozen-op');
      expect(read.timedElapsedMs, 1500);
    });
  });
}
