import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';

class _Store implements ActiveWorkoutLocalStore {
  final data = <String, ActiveWorkoutHiveModel>{};

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

/// Records, in order, what the native rest timer (which owns the «Descanso
/// terminado» notification) is asked to do.
class _RecordingRestTimer implements RestTimerCoordinator {
  final calls = <String>[];
  final sessions = <RestTimerSession>[];

  @override
  RestTimerSession? activeSession;

  @override
  Future<void> start(RestTimerSession session) async {
    activeSession = session;
    sessions.add(session);
    calls.add('start');
  }

  @override
  Future<void> finish() async {
    activeSession = null;
    calls.add('finish');
  }

  @override
  Future<void> cancel() async {
    activeSession = null;
    calls.add('cancel');
  }
}

TrainingExerciseEntity _exercise({int sets = 2, int restSeconds = 20}) =>
    TrainingExerciseEntity(
      id: 'te-3',
      order: 3,
      sets: sets,
      repsOrDuration: '10 reps',
      restSeconds: restSeconds,
      exercise: const ExerciseEntity(
        id: 'ex-3',
        name: 'HOJA Press',
        muscleGroups: [],
      ),
    );

/// DESCANSO-AVISO (OBS-11): every way out of a rest and what it asks of the
/// native notification.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime clock;
  late _Store store;
  late _RecordingRestTimer native;

  ActiveExerciseBloc newBloc({int sets = 2}) => ActiveExerciseBloc(
    localStorage: store,
    trainingExercise: _exercise(sets: sets),
    restTimerCoordinator: native,
    now: () => clock,
  );

  Future<ActiveExerciseBloc> resting({int sets = 2}) async {
    final bloc = newBloc(sets: sets);
    bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-3'));
    await pumpEventQueue();
    bloc.add(const CompleteSet(reps: 10, weightKg: 40, rir: 2));
    await pumpEventQueue();
    return bloc;
  }

  setUp(() {
    clock = DateTime.utc(2026, 11, 27, 10);
    store = _Store();
    native = _RecordingRestTimer();
  });

  test('«Saltar descanso» between sets cancels that rest, once', () async {
    final bloc = await resting();
    addTearDown(bloc.close);
    final end = bloc.state.restEndsAt!;
    clock = clock.add(const Duration(seconds: 13)); // 0:07 left

    bloc.add(const SkipRest());
    await pumpEventQueue();
    expect(bloc.state.status, ActiveExerciseStatus.executing);
    expect(native.calls, ['start', 'cancel']);

    // The footer of the skipped rest may still tick when it reaches zero.
    clock = end.add(const Duration(seconds: 1));
    bloc.add(FinishRest(restEndsAt: end));
    await pumpEventQueue();
    expect(native.calls, ['start', 'cancel']);
  });

  test('«Saltar descanso» in the final rest (OBS-11 flow) cancels it and '
      'nothing re-arms it', () async {
    final bloc = await resting(sets: 1);
    addTearDown(bloc.close);
    expect(bloc.state.status, ActiveExerciseStatus.finalResting);
    final end = bloc.state.restEndsAt!;
    clock = clock.add(const Duration(seconds: 13));

    bloc.add(const SkipRest());
    await pumpEventQueue();
    expect(bloc.state.status, ActiveExerciseStatus.done);
    expect(native.calls, ['start', 'cancel']);
    expect(store.data['ex-3']!.restEndsAt, isNull);

    clock = end.add(const Duration(seconds: 1));
    bloc
      ..add(FinishRest(restEndsAt: end))
      ..add(const ExtendRest())
      ..add(const SkipRest());
    await pumpEventQueue();
    expect(native.calls, ['start', 'cancel']);
  });

  test('«+30 s» re-arms the same rest at the new end, then «Saltar» '
      'cancels it', () async {
    final bloc = await resting(sets: 1);
    addTearDown(bloc.close);
    final first = native.sessions.single;
    clock = clock.add(const Duration(seconds: 5));

    bloc.add(const ExtendRest());
    await pumpEventQueue();
    expect(native.calls, ['start', 'start']);
    expect(native.sessions.last.id, first.id);
    expect(
      native.sessions.last.endsAt,
      first.endsAt.add(const Duration(seconds: 30)),
    );

    clock = clock.add(const Duration(seconds: 30));
    bloc.add(const SkipRest());
    await pumpEventQueue();
    expect(native.calls, ['start', 'start', 'cancel']);
  });

  test('a rest that ends on its own finishes the native timer once', () async {
    final bloc = await resting();
    addTearDown(bloc.close);
    final end = bloc.state.restEndsAt!;
    // Back in the foreground after the end: the footer reports it.
    clock = end.add(const Duration(minutes: 2));
    bloc
      ..add(FinishRest(restEndsAt: end))
      ..add(FinishRest(restEndsAt: end));
    await pumpEventQueue();
    expect(bloc.state.status, ActiveExerciseStatus.executing);
    expect(native.calls, ['start', 'finish']);
  });

  test('leaving the exercise during a rest cancels it', () async {
    final bloc = await resting();
    addTearDown(bloc.close);
    bloc.add(const AbandonExercise());
    await pumpEventQueue();
    expect(native.calls, ['start', 'cancel']);
  });

  test('reopening after the rest ended does not re-arm it', () async {
    final bloc = await resting();
    final end = bloc.state.restEndsAt!;
    await bloc.close();

    clock = end.add(const Duration(seconds: 30));
    final reopened = newBloc();
    addTearDown(reopened.close);
    reopened.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-3'));
    await pumpEventQueue();
    expect(reopened.state.status, ActiveExerciseStatus.executing);
    expect(native.calls, ['start']);
  });
}
