import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/data/models/training_model.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';

const config = TimedPrescription(
  unit: TimeDisplayUnit.minutes,
  segments: [
    TimedSegment(action: 'Corre', seconds: 120, unit: TimeDisplayUnit.minutes),
    TimedSegment(action: 'Camina', seconds: 60, unit: TimeDisplayUnit.minutes),
  ],
);
const exercise = TrainingExerciseEntity(
  id: 'occurrence',
  order: 0,
  sets: 2,
  repsOrDuration: '1440s',
  measureType: ExerciseMeasureType.seconds,
  targetValue: 1440,
  timedPrescription: config,
  restSeconds: 15,
  exercise: ExerciseEntity(id: 'exercise', name: 'Carrera', muscleGroups: []),
);

class _Store implements ActiveWorkoutLocalStore {
  final Box<ActiveWorkoutHiveModel> box;
  Future<void> saving = Future.value();
  _Store(this.box);
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String id) => box.get(id);
  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel value) =>
      saving = box.put(value.exerciseId, value);
  @override
  Future<void> removeActiveWorkout(String id) => box.delete(id);
}

Future<void> _dispatch(
  ActiveExerciseBloc bloc,
  _Store store,
  ActiveExerciseEvent event,
) async {
  final emitted = bloc.stream.first;
  bloc.add(event);
  await emitted;
  await store.saving;
}

// Exact persisted fields of the base adapter (7a0534c), before FEAT-007.
class _LegacyAdapter extends ActiveWorkoutHiveModelAdapter {
  @override
  void write(BinaryWriter writer, ActiveWorkoutHiveModel obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.lastSetFeedbackClientUploadId);
  }
}

class _DelayedStore implements ActiveWorkoutLocalStore {
  final values = <String, ActiveWorkoutHiveModel>{};
  Completer<void>? barrier;
  int concurrent = 0;
  int maximumConcurrent = 0;
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String id) => values[id];
  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel value) async {
    concurrent++;
    if (concurrent > maximumConcurrent) maximumConcurrent = concurrent;
    await barrier?.future;
    values[value.exerciseId] = value;
    concurrent--;
  }

  @override
  Future<void> removeActiveWorkout(String id) async {
    values.remove(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'F007 upgrades an eight-field Hive record without losing performance or evidence identity',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exom-f007-legacy-',
      );
      Hive.init(directory.path);
      Hive.registerAdapter(_LegacyAdapter(), override: true);
      var box = await Hive.openBox<ActiveWorkoutHiveModel>('legacy');
      try {
        await box.put(
          'occurrence',
          const ActiveWorkoutHiveModel(
            trainingId: 'training',
            exerciseId: 'occurrence',
            currentSet: 2,
            completedSets: 1,
            lastWeightKg: 5,
            completedSetData: [
              {'set_number': 1, 'seconds': 90, 'rir': 0},
            ],
            lastSetFeedbackClientUploadId: 'owned-upload',
          ),
        );
        await box.close();
        Hive.registerAdapter(ActiveWorkoutHiveModelAdapter(), override: true);
        box = await Hive.openBox<ActiveWorkoutHiveModel>('legacy');
        final saved = box.get('occurrence')!;
        expect(saved.completedSetData.single, {
          'set_number': 1,
          'seconds': 90,
          'rir': 0,
        });
        expect(saved.lastSetFeedbackClientUploadId, 'owned-upload');
        expect(saved.lastWeightKg, 5);
        expect(saved.timedElapsedMs, 0);
        expect(saved.timedTotalSeconds, isNull);
        expect(saved.timedPrescription, isNull);
      } finally {
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'F007 restored continuous duration keeps canonical seconds and prescribed RIR',
    () {
      const current = TrainingExerciseEntity(
        id: 'occurrence',
        order: 0,
        sets: 1,
        repsOrDuration: '1440s',
        measureType: ExerciseMeasureType.seconds,
        targetValue: 1440,
        targetRir: 0,
        timedPrescription: config,
        restSeconds: 30,
        exercise: ExerciseEntity(
          id: 'exercise',
          name: 'Carrera',
          muscleGroups: [],
        ),
      );
      expect(
        formatExercisePrescription(current, savedTotalSeconds: 90),
        '90 s en total. · RIR 0',
      );
      expect(
        formatExercisePrescription(
          current,
          savedTotalSeconds: 120,
          savedTimedPrescription: const TimedPrescription(
            unit: TimeDisplayUnit.minutes,
          ),
        ),
        '2 min en total. · RIR 0',
      );
    },
  );
  test(
    'F007 legacy owner-bound workout keeps its slot and sets without inventing a date',
    () async {
      final store = _DelayedStore();
      store.values['occurrence'] = const ActiveWorkoutHiveModel(
        trainingId: 'training',
        exerciseId: 'occurrence',
        currentSet: 2,
        completedSets: 1,
        completedSetData: [
          {'set_number': 1, 'seconds': 90, 'rir': 2},
        ],
      );
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: exercise,
      );
      bloc.add(
        const StartExercise(
          trainingId: 'training',
          exerciseId: 'occurrence',
          assignmentDate: '2026-09-13',
        ),
      );
      await pumpEventQueue();
      expect(bloc.state.completedSets, 1);
      expect(bloc.state.setPerformances.single.seconds, 90);
      expect(store.values['occurrence']!.completedSetData.single['rir'], 2);
      expect(store.values['occurrence:2026-09-13'], isNull);
      await bloc.close();
    },
  );
  test(
    'F007 delayed start write cannot overwrite a later reset or run writes in parallel',
    () async {
      final store = _DelayedStore()..barrier = Completer<void>();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: exercise,
      );
      bloc.add(
        const StartExercise(
          trainingId: 'training',
          exerciseId: 'occurrence',
          assignmentDate: '2026-09-13',
        ),
      );
      await pumpEventQueue();
      bloc.add(const ToggleExecutionTimer());
      bloc.add(const ResetExecutionTimer());
      await pumpEventQueue();
      expect(store.concurrent, 1);
      store.barrier!.complete();
      await pumpEventQueue();
      expect(store.maximumConcurrent, 1);
      expect(store.values['occurrence:2026-09-13']!.timedStartedAt, isNull);
      expect(bloc.state.timedElapsedMs, 0);
      await bloc.close();
    },
  );
  test(
    'F007 total is 24 minutes: 16 running and 8 walking; boundaries and partial final segment',
    () {
      final byAction = <String, int>{};
      for (var second = 0; second < 1440; second++) {
        final phase = config.phase(1440, second * 1000);
        byAction.update(phase.action, (n) => n + 1, ifAbsent: () => 1);
      }
      expect(byAction, {'Corre': 960, 'Camina': 480});
      expect(config.phase(1440, 119999).action, 'Corre');
      expect(config.phase(1440, 120000).action, 'Camina');
      expect(config.phase(1440, 180000).action, 'Corre');
      expect(config.phase(1440, 1440000).totalRemainingMilliseconds, 0);
      expect(config.phase(1500, 1440000).remainingMilliseconds, 60000);
      expect(config.phase(1500, 1440000).nextAction, isNull);
      expect(
        config.instructions(1500),
        contains('Último tramo recortado: Corre, 1 min'),
      );
      final reversed = TimedPrescription(
        unit: config.unit,
        segments: config.segments.reversed.toList(),
      );
      expect(reversed.phase(1440, 0).action, 'Camina');
      expect(
        reversed.instructions(1440),
        contains('Camina: 1 min; Corre: 2 min'),
      );
    },
  );
  test(
    'F007 reads canonical seconds and presentation from cached JSON; legacy stays readable',
    () {
      final parsed = TrainingExerciseModel.fromJson({
        'id': 'occurrence',
        'measure_type': 'SECONDS',
        'target_value': 1440,
        'timed_config': config.toJson(),
      });
      expect(parsed.targetValue, 1440);
      expect(
        parsed.timedPrescription!.instructions(1440),
        config.instructions(1440),
      );
      expect(
        TrainingExerciseModel.fromJson({'target_value': 90}).timedPrescription,
        isNull,
      );
      expect(formatDurationValue(120, TimeDisplayUnit.minutes), '2 min');
      expect(formatDurationValue(90, TimeDisplayUnit.minutes), '1,5 min');
      expect(formatDurationValue(7, TimeDisplayUnit.minutes), '0 min 7 s');
      expect(TimedPrescription.tryParse({'version': 2}), isNull);
    },
  );
  test(
    'F007 pause/resume and Hive reopen retain exact elapsed time and date; timer never completes progress',
    () async {
      final directory = await Directory.systemTemp.createTemp('exom-f007-');
      Hive.init(directory.path);
      if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
        Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
      }
      var box = await Hive.openBox<ActiveWorkoutHiveModel>('timed');
      var store = _Store(box);
      var now = DateTime.utc(2026, 9, 13, 12);
      var bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: exercise,
        now: () => now,
      );
      try {
        await _dispatch(
          bloc,
          store,
          const StartExercise(
            trainingId: 'training',
            exerciseId: 'occurrence',
            assignmentDate: '2026-09-13',
          ),
        );
        await _dispatch(bloc, store, const ToggleExecutionTimer());
        now = now.add(const Duration(milliseconds: 1234));
        await _dispatch(bloc, store, const ToggleExecutionTimer());
        expect(bloc.state.timedElapsedMs, 1234);
        now = now.add(const Duration(minutes: 5));
        expect(bloc.state.elapsedAt(now), 1234);
        await _dispatch(bloc, store, const ToggleExecutionTimer());
        now = now.add(const Duration(milliseconds: 766));
        expect(bloc.state.elapsedAt(now), 2000);
        await bloc.close();
        await box.close();
        box = await Hive.openBox<ActiveWorkoutHiveModel>('timed');
        store = _Store(box);
        now = now.add(const Duration(seconds: 118));
        bloc = ActiveExerciseBloc(
          localStorage: store,
          trainingExercise: exercise,
          now: () => now,
        );
        await _dispatch(
          bloc,
          store,
          const StartExercise(
            trainingId: 'training',
            exerciseId: 'occurrence',
            assignmentDate: '2026-09-13',
          ),
        );
        expect(bloc.state.elapsedAt(now), 120000);
        expect(
          bloc.state.timedPrescription!
              .phase(1440, bloc.state.elapsedAt(now))
              .action,
          'Camina',
        );
        now = now.add(const Duration(hours: 2));
        expect(bloc.state.elapsedAt(now), 1440000);
        expect(bloc.state.completedSets, 0);
        expect(bloc.state.setPerformances, isEmpty);
        expect(bloc.state.isDone, isFalse);
        expect(box.get('occurrence:2026-09-13'), isNotNull);
        expect(box.get('occurrence:2026-09-14'), isNull);
        await _dispatch(bloc, store, const ResetExecutionTimer());
        expect(bloc.state.elapsedAt(now), 0);
        expect(box.get('occurrence:2026-09-13')!.timedElapsedMs, 0);
      } finally {
        await bloc.close();
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
