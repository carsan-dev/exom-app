import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
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

class _FakeRestTimerCoordinator implements RestTimerCoordinator {
  @override
  RestTimerSession? activeSession;
  final startedSessions = <RestTimerSession>[];
  int finishCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> start(RestTimerSession session) async {
    activeSession = session;
    startedSessions.add(session);
  }

  @override
  Future<void> finish() async {
    activeSession = null;
    finishCalls += 1;
  }

  @override
  Future<void> cancel() async {
    activeSession = null;
    cancelCalls += 1;
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
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test('execution identity survives draft persistence and restart', () async {
      final store = _FakeStore();
      final first = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );
      first.add(const StartExercise(
        trainingId: 't-1',
        exerciseId: 'ex-1',
        assignmentDate: '2026-09-24',
        sessionId: 'execution-one',
      ));
      await pumpEventQueue();
      expect(store.getActiveWorkout('ex-1:2026-09-24:execution-one')?.sessionId,
          'execution-one');
      await first.close();

      final restarted = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );
      restarted.add(const StartExercise(
        trainingId: 't-1',
        exerciseId: 'ex-1',
        assignmentDate: '2026-09-24',
        sessionId: 'execution-one',
      ));
      await pumpEventQueue();
      expect(restarted.state.sessionId, 'execution-one');
      await restarted.close();
    });

    test('a distinct execution never replaces an existing same-day draft', () async {
      final store = _FakeStore();
      await store.saveActiveWorkout(const ActiveWorkoutHiveModel(
        trainingId: 't-1',
        sessionId: 'first',
        exerciseId: 'ex-1:2026-09-24',
        currentSet: 2,
        completedSets: 1,
      ));
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );
      bloc.add(const StartExercise(
        trainingId: 't-1',
        exerciseId: 'ex-1',
        assignmentDate: '2026-09-24',
        sessionId: 'second',
      ));
      await pumpEventQueue();
      expect(store.getActiveWorkout('ex-1:2026-09-24')?.sessionId, 'first');
      expect(bloc.state.sessionId, 'second');
      expect(store.getActiveWorkout('ex-1:2026-09-24:second')?.sessionId, 'second');
      await bloc.close();
    });

    test('upgrades a same-execution date-keyed draft without losing sets', () async {
      final store = _FakeStore();
      await store.saveActiveWorkout(const ActiveWorkoutHiveModel(
        trainingId: 't-1', sessionId: 'execution-one',
        exerciseId: 'ex-1:2026-09-24', currentSet: 2, completedSets: 1,
      ));
      final bloc = ActiveExerciseBloc(
        localStorage: store, trainingExercise: _trainingExercise());
      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1',
          assignmentDate: '2026-09-24', sessionId: 'execution-one'));
      await pumpEventQueue();
      expect(bloc.state.completedSets, 1);
      expect(store.getActiveWorkout('ex-1:2026-09-24:execution-one')?.completedSets, 1);
      expect(store.getActiveWorkout('ex-1:2026-09-24'), isNull);
      await bloc.close();
    });

    test('two same-day executions keep independent resumable set drafts', () async {
      final store = _FakeStore();
      for (final id in ['execution-one', 'execution-two']) {
        final bloc = ActiveExerciseBloc(
          localStorage: store,
          trainingExercise: _trainingExercise(),
        );
        bloc.add(StartExercise(
          trainingId: 't-1', exerciseId: 'ex-1',
          assignmentDate: '2026-09-24', sessionId: id,
        ));
        await pumpEventQueue();
        bloc.add(const CompleteSet(reps: 10));
        await pumpEventQueue();
        await bloc.close();
      }
      expect(store.getActiveWorkout('ex-1:2026-09-24:execution-one')?.completedSets, 1);
      expect(store.getActiveWorkout('ex-1:2026-09-24:execution-two')?.completedSets, 1);
    });

    test('StartExercise without saved data persists initial state', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();

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
        await pumpEventQueue();

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
        await pumpEventQueue();

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
      await pumpEventQueue();

      bloc.add(const CompleteSet(weightKg: 70));
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.resting);
      expect(bloc.state.completedSets, 1);
      expect(bloc.state.currentSet, 2);
      expect(bloc.state.weightKg, 70);
      expect(bloc.state.restEndsAt, isNotNull);
      expect(store.getActiveWorkout('ex-1')!.completedSets, 1);
    });

    test(
      'AttachLastSetFeedback persists before final set completion',
      () async {
        final store = _FakeStore();
        final bloc = ActiveExerciseBloc(
          localStorage: store,
          trainingExercise: _trainingExercise(),
        );

        bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
        await pumpEventQueue();
        bloc.add(const AttachLastSetFeedback('feedback-1'));
        await pumpEventQueue();

        expect(bloc.state.lastSetFeedbackClientUploadId, 'feedback-1');
        expect(
          store.getActiveWorkout('ex-1')!.lastSetFeedbackClientUploadId,
          'feedback-1',
        );

        final restoredBloc = ActiveExerciseBloc(
          localStorage: store,
          trainingExercise: _trainingExercise(),
        );
        restoredBloc.add(
          const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'),
        );
        await pumpEventQueue();

        expect(restoredBloc.state.lastSetFeedbackClientUploadId, 'feedback-1');
        await bloc.close();
        await restoredBloc.close();
      },
    );

    test('CompleteSet persists reps and weight for each tracked set', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      bloc.add(const CompleteSet(reps: 12, weightKg: 72.5, rir: 2));
      await pumpEventQueue();

      expect(bloc.state.setPerformances, hasLength(1));
      expect(bloc.state.setPerformances.single.setNumber, 1);
      expect(bloc.state.setPerformances.single.reps, 12);
      expect(bloc.state.setPerformances.single.weightKg, 72.5);
      expect(bloc.state.setPerformances.single.rir, 2);
      expect(store.getActiveWorkout('ex-1')!.completedSetData.single, {
        'set_number': 1,
        'reps': 12,
        'weight_kg': 72.5,
        'rir': 2,
      });
    });

    test('CompleteSet persists weight without reps', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      bloc.add(const CompleteSet(weightKg: 42.5));
      await pumpEventQueue();

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
      await pumpEventQueue();
      bloc.add(const CompleteSet(reps: 9));
      await pumpEventQueue();

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
      await pumpEventQueue();
      bloc.add(const CompleteSet());
      await pumpEventQueue();

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
      await pumpEventQueue();

      bloc.add(const CompleteSet(weightKg: 70));
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.executing);
      expect(bloc.state.completedSets, 1);
      expect(bloc.state.currentSet, 2);
      expect(bloc.state.restEndsAt, isNull);
    });

    test('CompleteSet on last set retains finalResting draft until enqueue', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(sets: 2),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      bloc.add(const CompleteSet(weightKg: 65));
      await pumpEventQueue();
      // Skip the rest to be ready to complete the final set.
      bloc.add(const SkipRest());
      await pumpEventQueue();
      bloc.add(const CompleteSet(weightKg: 65));
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.finalResting);
      expect(bloc.state.completedSets, 2);
      expect(bloc.state.currentSet, 2);
      expect(store.getActiveWorkout('ex-1'), isNotNull);

      bloc.add(const SkipRest());
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.done);
      expect(store.getActiveWorkout('ex-1')?.completedSets, 2);
      expect(store.getActiveWorkout('ex-1')?.completionOperationId,
          bloc.state.completionOperationId);
    });

    test('failed enqueue leaves final sets recoverable on restart', () async {
      final store = _FakeStore();
      final first = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(sets: 1, restSeconds: 0),
      );
      first.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      first.add(const CompleteSet(reps: 12, weightKg: 70));
      await pumpEventQueue();
      expect(first.state.isDone, isTrue);
      // The page's enqueue fails before a durable queue write, then the app exits.
      await first.close();
      final restarted = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(sets: 1, restSeconds: 0),
      );
      restarted.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      expect(restarted.state.isDone, isTrue);
      expect(restarted.state.setPerformances.single.reps, 12);
      expect(store.getActiveWorkout('ex-1')?.completedSetData.single['reps'], 12);
      await restarted.close();
    });

    test('last set with zero rest completes immediately', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(sets: 1, restSeconds: 0),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      bloc.add(const CompleteSet());
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.done);
      expect(store.getActiveWorkout('ex-1')?.completionOperationId,
          bloc.state.completionOperationId);
    });

    test('restores pending final rest', () async {
      final store = _FakeStore();
      final end = DateTime.now().add(const Duration(minutes: 1));
      await store.saveActiveWorkout(
        ActiveWorkoutHiveModel(
          trainingId: 't-1',
          exerciseId: 'ex-1',
          currentSet: 1,
          completedSets: 1,
          restEndsAt: end,
        ),
      );
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(sets: 1),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.finalResting);
      expect(bloc.state.restEndsAt, end);
      expect(store.getActiveWorkout('ex-1'), isNotNull);
    });

    test('expired final rest restores done without deleting draft', () async {
      final store = _FakeStore();
      await store.saveActiveWorkout(
        ActiveWorkoutHiveModel(
          trainingId: 't-1',
          exerciseId: 'ex-1',
          currentSet: 1,
          completedSets: 1,
          restEndsAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(sets: 1),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.done);
      expect(store.getActiveWorkout('ex-1')?.completionOperationId,
          bloc.state.completionOperationId);
    });

    test('SkipRest transitions back to executing', () async {
      final store = _FakeStore();
      final restTimerCoordinator = _FakeRestTimerCoordinator();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
        restTimerCoordinator: restTimerCoordinator,
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      bloc.add(const CompleteSet());
      await pumpEventQueue();

      bloc.add(const SkipRest());
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.executing);
      expect(bloc.state.restEndsAt, isNull);
      expect(store.getActiveWorkout('ex-1')!.restEndsAt, isNull);
      expect(restTimerCoordinator.cancelCalls, 1);
      expect(restTimerCoordinator.finishCalls, 0);
    });

    test(
      'FinishRest completes native timer without cancelling its sound',
      () async {
        final store = _FakeStore();
        final restTimerCoordinator = _FakeRestTimerCoordinator();
        final bloc = ActiveExerciseBloc(
          localStorage: store,
          trainingExercise: _trainingExercise(),
          restTimerCoordinator: restTimerCoordinator,
        );

        bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
        await pumpEventQueue();
        bloc.add(const CompleteSet());
        await pumpEventQueue();

        bloc.add(const FinishRest());
        await pumpEventQueue();

        expect(bloc.state.status, ActiveExerciseStatus.executing);
        expect(restTimerCoordinator.finishCalls, 1);
        expect(restTimerCoordinator.cancelCalls, 0);
      },
    );

    test(
      'each rest uses a unique native session id at the same millisecond',
      () async {
        final restTimerCoordinator = _FakeRestTimerCoordinator();
        final bloc = ActiveExerciseBloc(
          localStorage: _FakeStore(),
          now: () => DateTime.utc(2026, 9, 12, 10),
          trainingExercise: _trainingExercise(),
          restTimerCoordinator: restTimerCoordinator,
        );

        bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
        await pumpEventQueue();
        bloc.add(const CompleteSet());
        await pumpEventQueue();
        bloc.add(const FinishRest());
        await pumpEventQueue();
        bloc.add(const CompleteSet());
        await pumpEventQueue();

        addTearDown(bloc.close);
        expect(restTimerCoordinator.startedSessions, hasLength(2));
        expect(
          restTimerCoordinator.startedSessions.first.endsAt,
          restTimerCoordinator.startedSessions.last.endsAt,
        );
        expect(
          restTimerCoordinator.startedSessions.first.id,
          isNot(restTimerCoordinator.startedSessions.last.id),
        );
      },
    );

    test('AbandonExercise keeps saved progress for later resume', () async {
      final store = _FakeStore();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: _trainingExercise(),
      );

      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      bloc.add(const CompleteSet(weightKg: 80));
      await pumpEventQueue();
      bloc.add(const SkipRest());
      await pumpEventQueue();

      bloc.add(const AbandonExercise());
      await pumpEventQueue();

      final saved = store.getActiveWorkout('ex-1');
      expect(saved, isNotNull);
      expect(saved!.completedSets, 1);
      expect(saved.lastWeightKg, 80);
    });
  });

  // Decision D7 (owner, 2026-11-18): «+30 s» during the rest. ExtendRest goes
  // through the same serialized handler, persists the new end in Hive (the
  // single source of truth) and re-syncs the native timer by starting it again
  // with the SAME session id (no cancel, so no native stop/start churn).
  group('ExtendRest (D7)', () {
    late DateTime clock;
    late _FakeStore store;
    late _FakeRestTimerCoordinator native;

    ActiveExerciseBloc newBloc({int sets = 3}) => ActiveExerciseBloc(
      localStorage: store,
      trainingExercise: _trainingExercise(sets: sets),
      restTimerCoordinator: native,
      now: () => clock,
    );

    Future<ActiveExerciseBloc> resting({int sets = 3, int completed = 1})
        async {
      final bloc = newBloc(sets: sets);
      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      for (var i = 0; i < completed; i++) {
        if (i > 0) {
          bloc.add(const SkipRest());
          await pumpEventQueue();
        }
        bloc.add(const CompleteSet(reps: 8, weightKg: 62.5, rir: 2));
        await pumpEventQueue();
      }
      return bloc;
    }

    setUp(() {
      clock = DateTime.utc(2026, 11, 18, 10);
      store = _FakeStore();
      native = _FakeRestTimerCoordinator();
    });

    test('adds 30 s, persists it and restarts native with the same id',
        () async {
      final bloc = await resting();
      addTearDown(bloc.close);
      final firstEnd = bloc.state.restEndsAt!;
      final firstId = native.startedSessions.single.id;
      clock = clock.add(const Duration(seconds: 20));

      bloc.add(const ExtendRest());
      await pumpEventQueue();

      final extended = firstEnd.add(const Duration(seconds: 30));
      expect(bloc.state.status, ActiveExerciseStatus.resting);
      expect(bloc.state.restEndsAt, extended);
      expect(store.getActiveWorkout('ex-1')!.restEndsAt, extended);
      expect(native.startedSessions, hasLength(2));
      expect(native.startedSessions.last.id, firstId);
      expect(native.startedSessions.last.endsAt, extended);
      expect(native.cancelCalls, 0);
      expect(native.finishCalls, 0);
      // Nothing else in the draft changes.
      final saved = store.getActiveWorkout('ex-1')!;
      expect(saved.completedSets, 1);
      expect(saved.currentSet, 2);
      expect(saved.completedSetData, [
        {'set_number': 1, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
      ]);
    });

    test('repeated taps add up, one native start each, same id', () async {
      final bloc = await resting();
      addTearDown(bloc.close);
      final firstEnd = bloc.state.restEndsAt!;
      final firstId = native.startedSessions.single.id;

      bloc
        ..add(const ExtendRest())
        ..add(const ExtendRest())
        ..add(const ExtendRest());
      await pumpEventQueue();

      expect(bloc.state.restEndsAt, firstEnd.add(const Duration(seconds: 90)));
      expect(native.startedSessions, hasLength(4));
      expect(native.startedSessions.map((s) => s.id).toSet(), {firstId});
      expect(native.cancelCalls, 0);
    });

    test('caps the end at now + 30 minutes', () async {
      final bloc = await resting();
      addTearDown(bloc.close);
      for (var i = 0; i < 70; i++) {
        bloc.add(const ExtendRest());
      }
      await pumpEventQueue();

      expect(bloc.state.restEndsAt, clock.add(const Duration(minutes: 30)));
      expect(
        store.getActiveWorkout('ex-1')!.restEndsAt,
        clock.add(const Duration(minutes: 30)),
      );
    });

    test('is ignored while executing, after the rest ended and when done',
        () async {
      final bloc = newBloc(sets: 1);
      addTearDown(bloc.close);
      bloc.add(const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'));
      await pumpEventQueue();
      final executingDraft = store.getActiveWorkout('ex-1');
      bloc.add(const ExtendRest());
      await pumpEventQueue();
      expect(bloc.state.isExecuting, isTrue);
      expect(bloc.state.restEndsAt, isNull);
      expect(identical(store.getActiveWorkout('ex-1'), executingDraft), isTrue);
      expect(native.startedSessions, isEmpty);

      // Expired but not yet processed: the pending FinishRest wins.
      final other = await resting();
      addTearDown(other.close);
      final end = other.state.restEndsAt!;
      final starts = native.startedSessions.length;
      clock = end;
      other.add(const ExtendRest());
      await pumpEventQueue();
      expect(other.state.restEndsAt, end);
      expect(native.startedSessions, hasLength(starts));

      // Done (last set, no rest left).
      clock = end.add(const Duration(seconds: 1));
      other.add(const FinishRest());
      await pumpEventQueue();
      expect(other.state.isExecuting, isTrue);
      other.add(const ExtendRest());
      await pumpEventQueue();
      expect(other.state.isExecuting, isTrue);
      expect(other.state.restEndsAt, isNull);
    });

    test('final rest can be extended and still ends in done', () async {
      final bloc = await resting(sets: 1);
      addTearDown(bloc.close);
      expect(bloc.state.status, ActiveExerciseStatus.finalResting);
      final firstEnd = bloc.state.restEndsAt!;

      bloc.add(const ExtendRest());
      await pumpEventQueue();
      expect(bloc.state.status, ActiveExerciseStatus.finalResting);
      expect(bloc.state.restEndsAt, firstEnd.add(const Duration(seconds: 30)));
      expect(bloc.state.completionOperationId, isNull);

      bloc.add(FinishRest(restEndsAt: bloc.state.restEndsAt));
      await pumpEventQueue();
      expect(bloc.state.status, ActiveExerciseStatus.done);
      expect(bloc.state.completionOperationId, isNotNull);
      expect(
        store.getActiveWorkout('ex-1')!.completionOperationId,
        bloc.state.completionOperationId,
      );
      expect(native.finishCalls, 1);
    });

    test('a stale FinishRest from the previous end is ignored', () async {
      final bloc = await resting();
      addTearDown(bloc.close);
      final oldEnd = bloc.state.restEndsAt!;

      // The tick of the outgoing footer can be queued behind the extension.
      bloc
        ..add(const ExtendRest())
        ..add(FinishRest(restEndsAt: oldEnd));
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.resting);
      expect(bloc.state.restEndsAt, oldEnd.add(const Duration(seconds: 30)));
      expect(native.finishCalls, 0);
      expect(native.cancelCalls, 0);

      bloc.add(FinishRest(restEndsAt: bloc.state.restEndsAt));
      await pumpEventQueue();
      expect(bloc.state.status, ActiveExerciseStatus.executing);
      expect(native.finishCalls, 1);
    });

    test('a FinishRest queued before the extension wins (tap too late)',
        () async {
      final bloc = await resting();
      addTearDown(bloc.close);
      final oldEnd = bloc.state.restEndsAt!;

      bloc
        ..add(FinishRest(restEndsAt: oldEnd))
        ..add(const ExtendRest());
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.executing);
      expect(bloc.state.restEndsAt, isNull);
      expect(native.finishCalls, 1);
      expect(native.startedSessions, hasLength(1));
    });

    test('restore after an extension resumes the extended rest', () async {
      final first = await resting();
      first.add(const ExtendRest());
      await pumpEventQueue();
      final extended = first.state.restEndsAt!;
      await first.close();

      final restarted = newBloc();
      addTearDown(restarted.close);
      restarted.add(
        const StartExercise(trainingId: 't-1', exerciseId: 'ex-1'),
      );
      await pumpEventQueue();

      expect(restarted.state.status, ActiveExerciseStatus.resting);
      expect(restarted.state.restEndsAt, extended);
      expect(native.startedSessions.last.endsAt, extended);

      // The restored rest can be extended again.
      restarted.add(const ExtendRest());
      await pumpEventQueue();
      expect(
        store.getActiveWorkout('ex-1')!.restEndsAt,
        extended.add(const Duration(seconds: 30)),
      );
      expect(
        native.startedSessions.last.id,
        native.startedSessions[native.startedSessions.length - 2].id,
      );
    });

    test('SkipRest after an extension cancels the native timer once',
        () async {
      final bloc = await resting();
      addTearDown(bloc.close);
      bloc.add(const ExtendRest());
      await pumpEventQueue();

      bloc.add(const SkipRest());
      await pumpEventQueue();

      expect(bloc.state.status, ActiveExerciseStatus.executing);
      expect(store.getActiveWorkout('ex-1')!.restEndsAt, isNull);
      expect(native.cancelCalls, 1);
      expect(native.finishCalls, 0);
    });

    test('the next rest gets a new native id after an extended one', () async {
      final bloc = await resting();
      addTearDown(bloc.close);
      bloc.add(const ExtendRest());
      await pumpEventQueue();
      final extendedId = native.startedSessions.last.id;
      bloc.add(const SkipRest());
      await pumpEventQueue();
      bloc.add(const CompleteSet(reps: 8));
      await pumpEventQueue();

      expect(native.startedSessions.last.id, isNot(extendedId));
    });
  });
}
