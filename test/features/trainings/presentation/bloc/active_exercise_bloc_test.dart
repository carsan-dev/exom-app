import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';

class _FakeStore implements ActiveWorkoutLocalStore {
  final Map<String, ActiveWorkoutHiveModel> _data = {};

  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) =>
      _data[exerciseId];

  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout) async {
    _data[workout.exerciseId] = workout;
  }

  @override
  Future<void> removeActiveWorkout(String exerciseId) async {
    _data.remove(exerciseId);
  }
}

TrainingExerciseEntity _trainingExercise({
  String id = 'te-1',
  int sets = 3,
  int restSeconds = 60,
}) {
  return TrainingExerciseEntity(
    id: id,
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
}

void main() {
  group('ActiveExerciseBloc', () {
    test('initial state derives from training exercise prescription', () {
      final bloc = ActiveExerciseBloc(
        localStorage: _FakeStore(),
        trainingExercise: _trainingExercise(),
      );

      expect(bloc.state.currentSet, 1);
      expect(bloc.state.totalSets, 3);
      expect(bloc.state.completedSets, 0);
      expect(bloc.state.status, ActiveExerciseStatus.executing);
      expect(bloc.state.restEndsAt, isNull);
    });

    test('StartExercise without saved data persists initial state', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.currentSet, 1);
      expect(store.getActiveWorkout('ex-1'), isNotNull);
      expect(store.getActiveWorkout('ex-1')!.completedSets, 0);
    });

    test(
      'StartExercise restores executing state when saved rest expired',
      () async {
        final store = _FakeStore();
        await store.saveActiveWorkout(
          ActiveWorkoutHiveModel(
            trainingId: 't-1',
            exerciseId: 'ex-1',
            currentSet: 2,
            completedSets: 1,
            restEndsAt: DateTime.now().subtract(const Duration(seconds: 5)),
            lastWeightKg: 50,
          ),
        );

        final bloc = ActiveExerciseBloc(
          localStorage: store,
          trainingExercise: _trainingExercise(),
        );

        bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.completedSets, 1);
        expect(bloc.state.currentSet, 2);
        expect(bloc.state.status, ActiveExerciseStatus.executing);
        expect(bloc.state.weightKg, 50);
        expect(bloc.state.restEndsAt, isNull);
      },
    );

    test(
      'StartExercise restores resting state when saved rest still pending',
      () async {
        final store = _FakeStore();
        final pendingRestEnd = DateTime.now().add(const Duration(seconds: 30));
        await store.saveActiveWorkout(
          ActiveWorkoutHiveModel(
            trainingId: 't-1',
            exerciseId: 'ex-1',
            currentSet: 2,
            completedSets: 1,
            restEndsAt: pendingRestEnd,
            lastWeightKg: 60,
          ),
        );

        final bloc = ActiveExerciseBloc(
          localStorage: store,
          trainingExercise: _trainingExercise(),
        );

        bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, ActiveExerciseStatus.resting);
        expect(bloc.state.completedSets, 1);
        expect(bloc.state.currentSet, 2);
        expect(bloc.state.restEndsAt, pendingRestEnd);
      },
    );

    test('CompleteSet on intermediate set transitions to resting', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const CompleteSet(weightKg: 70));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, ActiveExerciseStatus.resting);
      expect(bloc.state.completedSets, 1);
      expect(bloc.state.currentSet, 2);
      expect(bloc.state.weightKg, 70);
      expect(bloc.state.restEndsAt, isNotNull);
      expect(store.getActiveWorkout('ex-1')!.completedSets, 1);
    });

    test('CompleteSet persists reps and weight for each tracked set', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CompleteSet(reps: 12, weightKg: 72.5));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.setPerformances, hasLength(1));
      expect(bloc.state.setPerformances.single.setNumber, 1);
      expect(bloc.state.setPerformances.single.reps, 12);
      expect(bloc.state.setPerformances.single.weightKg, 72.5);
      expect(store.getActiveWorkout('ex-1')!.completedSetData.single, {
        'set_number': 1,
        'reps': 12,
        'weight_kg': 72.5,
      });
    });

    test('CompleteSet persists weight without reps', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CompleteSet(weightKg: 42.5));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.setPerformances.single.reps, isNull);
      expect(store.getActiveWorkout('ex-1')!.completedSetData.single, {
        'set_number': 1,
        'weight_kg': 42.5,
      });
    });

    test('CompleteSet persists reps without weight', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CompleteSet(reps: 9));
      await Future<void>.delayed(Duration.zero);

      expect(store.getActiveWorkout('ex-1')!.completedSetData.single, {
        'set_number': 1,
        'reps': 9,
      });
    });

    test('CompleteSet without data completes without performance', () async {
      final bloc = ActiveExerciseBloc(
        localStorage: _FakeStore(),
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CompleteSet());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.completedSets, 1);
      expect(bloc.state.setPerformances, isEmpty);
    });

    test('CompleteSet skips rest when restSeconds == 0', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(restSeconds: 0),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const CompleteSet(weightKg: 70));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, ActiveExerciseStatus.executing);
      expect(bloc.state.completedSets, 1);
      expect(bloc.state.currentSet, 2);
      expect(bloc.state.restEndsAt, isNull);
    });

    test('CompleteSet on last set marks done and clears persistence', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(sets: 2),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CompleteSet(weightKg: 65));
      await Future<void>.delayed(Duration.zero);
      // Skip the rest to be ready to complete the final set.
      bloc.add(const SkipRest());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CompleteSet(weightKg: 65));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, ActiveExerciseStatus.done);
      expect(bloc.state.completedSets, 2);
      expect(bloc.state.currentSet, 2);
      expect(store.getActiveWorkout('ex-1'), isNull);
    });

    test('SkipRest transitions back to executing', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CompleteSet());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const SkipRest());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, ActiveExerciseStatus.executing);
      expect(bloc.state.restEndsAt, isNull);
      expect(store.getActiveWorkout('ex-1')!.restEndsAt, isNull);
    });

    test('AbandonExercise keeps saved progress for later resume', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CompleteSet(weightKg: 80));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SkipRest());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const AbandonExercise());
      await Future<void>.delayed(Duration.zero);

      final saved = store.getActiveWorkout('ex-1');
      expect(saved, isNotNull);
      expect(saved!.completedSets, 1);
      expect(saved.lastWeightKg, 80);
    });
  });
}
