import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/validated_session_gate.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_timer.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class _WorkoutStore implements ActiveWorkoutLocalStore {
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String id) => null;
  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel value) async {}
  @override
  Future<void> removeActiveWorkout(String id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.exommethod.exom/execution_timer');
  const user = UserEntity(
    id: 'owner',
    email: 'synthetic@example.invalid',
    role: 'CLIENT',
  );
  final calls = <MethodCall>[];
  var session = const LocalAuthSession(uid: 'owner', generation: 1);
  late LocalStorage storage;
  late ValidatedSessionGate gate;
  late ExecutionTimerCoordinator coordinator;
  setUp(() async {
    await sl.reset();
    calls.clear();
    session = const LocalAuthSession(uid: 'owner', generation: 1);
    storage = LocalStorage(currentSession: () => session);
    gate = ValidatedSessionGate(() => session);
    coordinator = ExecutionTimerCoordinator(
      channel: channel,
      isAuthorized: () => gate.isAuthenticated,
    );
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerSingleton<ValidatedSessionGate>(gate);
    sl.registerSingleton<ExecutionTimerCoordinator>(coordinator);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    handleExecutionTimerSessionState(const AuthAuthenticated(user));
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await sl.reset();
  });

  test(
    'actual AuthBloc callback cancels locked validation with unchanged Firebase stamp',
    () async {
      final owner = storage.sessionStamp;
      final revision = coordinator.sessionRevision;
      await coordinator.start(
        key: 'run',
        deadline: DateTime.now().add(const Duration(minutes: 1)),
      );
      handleExecutionTimerSessionState(const AuthAccountLocked());
      await Future<void>.delayed(Duration.zero);
      expect(storage.sessionStamp, owner);
      expect(gate.isAuthenticated, false);
      expect(calls.map((call) => call.method), ['start', 'cancel']);
      expect(isExecutionTimerOwnerCurrent(owner, revision), false);
    },
  );

  test(
    'invalid gate blocks preparation and scheduling; same-owner revalidation requires new intent',
    () async {
      final owner = storage.sessionStamp;
      final revision = coordinator.sessionRevision;
      final deadline = DateTime.now().add(const Duration(minutes: 1));
      await coordinator.start(key: 'old-intent', deadline: deadline);
      handleExecutionTimerSessionState(const AuthAccountLocked());
      await Future<void>.delayed(Duration.zero);
      await coordinator.start(key: 'old-intent', deadline: deadline);
      expect(calls.map((call) => call.method), ['start', 'cancel']);
      expect(isExecutionTimerOwnerCurrent(owner, revision), false);
      handleExecutionTimerSessionState(const AuthAuthenticated(user));
      await Future<void>.delayed(Duration.zero);
      expect(isExecutionTimerOwnerCurrent(owner, revision), false);
      expect(
        isExecutionTimerOwnerCurrent(owner, coordinator.sessionRevision),
        true,
      );
      expect(calls.map((call) => call.method), ['start', 'cancel']);
      await coordinator.start(key: 'new-intent', deadline: deadline);
      expect(calls.map((call) => call.method), ['start', 'cancel', 'start']);
      expect(
        (calls.last.arguments as Map)['id'],
        isNot((calls.first.arguments as Map)['id']),
      );
    },
  );

  testWidgets(
    'lock then same-owner revalidation cannot revive an open countdown',
    (tester) async {
      var now = DateTime.now();
      // Create the bridge queue in the widget test's fake-async zone.
      await sl.unregister<ExecutionTimerCoordinator>();
      coordinator = ExecutionTimerCoordinator(
        channel: channel,
        now: () => now,
        isAuthorized: () => gate.isAuthenticated,
      );
      sl.registerSingleton<ExecutionTimerCoordinator>(coordinator);
      handleExecutionTimerSessionState(const AuthAuthenticated(user));
      const exercise = TrainingExerciseEntity(
        id: 'timed',
        order: 0,
        sets: 1,
        repsOrDuration: '60s',
        measureType: ExerciseMeasureType.seconds,
        targetValue: 60,
        restSeconds: 0,
        exercise: ExerciseEntity(
          id: 'exercise',
          name: 'Walk',
          muscleGroups: [],
        ),
      );
      final bloc = ActiveExerciseBloc(
        localStorage: _WorkoutStore(),
        trainingExercise: exercise,
        now: () => now,
      );
      bloc.add(
        const StartExercise(trainingId: 'training', exerciseId: 'timed'),
      );
      await tester.pump();
      final owner = storage.sessionStamp;
      Widget app(int revision) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
              builder: (_, state) => ExecutionTimer(
                key: ValueKey(revision),
                state: state,
                now: () => now,
                coordinator: coordinator,
                isOwnerCurrent: () =>
                    isExecutionTimerOwnerCurrent(owner, revision),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(coordinator.sessionRevision));
      await tester.pump();
      await tester.tap(find.text('Iniciar tiempo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      handleExecutionTimerSessionState(const AuthAccountLocked());
      handleExecutionTimerSessionState(const AuthAuthenticated(user));
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(bloc.state.timedStartedAt, isNull);
      expect(calls, isEmpty);
      await tester.pumpWidget(app(coordinator.sessionRevision));
      await tester.pump();
      await tester.tap(find.text('Iniciar tiempo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 50));
      expect(bloc.state.timedStartedAt, isNull);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(bloc.state.timedStartedAt, isNotNull);
      await tester.pump();
      await tester.pump();
      expect(calls.map((call) => call.method), ['start']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(bloc.close);
    },
  );

  test(
    'in-flight old start is cancelled before the new validated owner starts',
    () async {
      final accepted = Completer<void>();
      final release = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (calls.length == 1) {
              accepted.complete();
              await release.future;
            }
            return null;
          });
      final previousOwner = storage.sessionStamp;
      final previousRevision = coordinator.sessionRevision;
      final deadline = DateTime.now().add(const Duration(minutes: 1));
      final oldStart = coordinator.start(key: 'old-owner', deadline: deadline);
      await accepted.future;
      handleExecutionTimerSessionState(const AuthAccountLocked());
      session = const LocalAuthSession(uid: 'new-owner', generation: 2);
      handleExecutionTimerSessionState(const AuthAuthenticated(user));
      final newStart = coordinator.start(key: 'new-owner', deadline: deadline);
      expect(
        isExecutionTimerOwnerCurrent(previousOwner, previousRevision),
        false,
      );
      expect(
        isExecutionTimerOwnerCurrent(
          storage.sessionStamp,
          coordinator.sessionRevision,
        ),
        true,
      );
      release.complete();
      await oldStart;
      await newStart;
      expect(calls.map((call) => call.method), ['start', 'cancel', 'start']);
      expect(
        (calls[1].arguments as Map)['id'],
        (calls[0].arguments as Map)['id'],
      );
      expect(
        (calls[1].arguments as Map)['id'],
        isNot((calls[2].arguments as Map)['id']),
      );
      await coordinator.cancel('old-owner');
      expect(calls.length, 3);
    },
  );

  for (final state in [
    const AuthLoading(),
    const AuthUnauthenticated(),
    const AuthAccountDeleted(),
  ]) {
    test(
      'non-validated ${state.runtimeType} blocks owner guard with unchanged stamp',
      () async {
        final owner = storage.sessionStamp;
        final revision = coordinator.sessionRevision;
        await coordinator.start(
          key: 'run',
          deadline: DateTime.now().add(const Duration(minutes: 1)),
        );
        handleExecutionTimerSessionState(state);
        await Future<void>.delayed(Duration.zero);
        expect(storage.sessionStamp, owner);
        expect(isExecutionTimerOwnerCurrent(owner, revision), false);
        expect(calls.map((call) => call.method), ['start', 'cancel']);
      },
    );
  }
}
