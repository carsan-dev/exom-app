import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_timer.dart';

class _SilentRestCoordinator implements RestTimerCoordinator {
  @override
  RestTimerSession? get activeSession => null;
  @override
  Future<void> start(RestTimerSession session) async {}
  @override
  Future<void> finish() async {}
  @override
  Future<void> cancel() async {}
}

class _Store implements ActiveWorkoutLocalStore {
  final values = <String, ActiveWorkoutHiveModel>{};
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String id) => values[id];
  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel value) async {
    values[value.exerciseId] = value;
  }

  @override
  Future<void> removeActiveWorkout(String id) async {
    values.remove(id);
  }
}

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
  sets: 1,
  repsOrDuration: '1440s',
  measureType: ExerciseMeasureType.seconds,
  targetValue: 1440,
  timedPrescription: config,
  restSeconds: 30,
  exercise: ExerciseEntity(id: 'exercise', name: 'Carrera', muscleGroups: []),
);

void main() {
  setUpAll(() async {
    final loader = FontLoader('CabinetGrotesk');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(
        rootBundle.load('assets/fonts/CabinetGrotesk-$weight.ttf'),
      );
    }
    await loader.load();
  });
  for (final scenario in [
    'double tap',
    'cancel',
    'back',
    'background',
    'unmount',
    'stale owner',
    'replacement',
  ]) {
    testWidgets('canonical timer cannot start early: $scenario', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 10);
      var ownerCurrent = true;
      Object identity = 'exercise-1';
      final bloc = ActiveExerciseBloc(
        localStorage: _Store(),
        trainingExercise: exercise,
        now: () => now,
      );
      bloc.add(
        const StartExercise(trainingId: 'training', exerciseId: 'occurrence'),
      );
      await tester.pump();
      Widget app() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
              builder: (_, state) => ExecutionTimer(
                state: state,
                now: () => now,
                runKey: identity,
                isOwnerCurrent: () => ownerCurrent,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pump();
      final start = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Iniciar tiempo'),
          )
          .onPressed!;
      start();
      if (scenario == 'double tap') start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(Dialog), findsOneWidget);
      expect(bloc.state.timedStartedAt, isNull);
      if (scenario == 'cancel') await tester.tap(find.text('Cancel'));
      if (scenario == 'back') await tester.binding.handlePopRoute();
      if (scenario == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }
      if (scenario == 'unmount') await tester.pumpWidget(const SizedBox());
      if (scenario == 'stale owner') ownerCurrent = false;
      if (scenario == 'replacement') {
        identity = 'exercise-2';
        await tester.pumpWidget(app());
      }
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 50));
      expect(bloc.state.timedStartedAt, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(bloc.state.timedStartedAt != null, scenario == 'double tap');
      expect(bloc.state.completedSets, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(bloc.close);
    });
  }

  testWidgets(
    'pause cancels exact run, resume is immediate, reset requires fresh preparation',
    (tester) async {
      var now = DateTime(2026, 10, 10);
      const channel = MethodChannel('com.exommethod.exom/execution_timer');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      final coordinator = ExecutionTimerCoordinator(now: () => now);
      final bloc = ActiveExerciseBloc(
        localStorage: _Store(),
        trainingExercise: exercise,
        now: () => now,
      );
      bloc.add(
        const StartExercise(trainingId: 'training', exerciseId: 'occurrence'),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: bloc,
            child: Scaffold(
              body: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
                builder: (_, state) => ExecutionTimer(
                  state: state,
                  now: () => now,
                  coordinator: coordinator,
                ),
              ),
            ),
          ),
        ),
      );
      bloc.add(const ToggleExecutionTimer());
      await tester.pump();
      await tester.pump();
      expect(calls.single.method, 'start');
      final originalDeadline = (calls.single.arguments as Map)['endsAtMillis'];
      // Backgrounding an already running exercise leaves native expiry armed.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(calls.length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      now = now.add(const Duration(seconds: 10));
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      await tester.pump();
      expect(calls.last.method, 'cancel');
      expect(bloc.state.timedElapsedMs, 10000);
      now = now.add(const Duration(seconds: 20));
      await tester.tap(find.text('Reanudar'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(Dialog), findsNothing);
      expect(calls.last.method, 'start');
      expect((calls.last.arguments as Map)['durationSeconds'], 1430);
      expect(
        (calls.last.arguments as Map)['endsAtMillis'],
        originalDeadline + 20000,
      );
      await tester.tap(find.text('Reiniciar tiempo'));
      await tester.pump();
      await tester.pump();
      expect(calls.last.method, 'cancel');
      await tester.tap(find.text('Iniciar tiempo'));
      await tester.pump();
      expect(find.byType(Dialog), findsOneWidget);
      expect(bloc.state.timedElapsedMs, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(bloc.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  testWidgets(
    'circuit round key replacement removes old preparation without starting either round',
    (tester) async {
      final store = _Store();
      Widget app(int round) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CircuitExecutionTimer(
            key: ValueKey(round),
            store: store,
            exercise: exercise,
            trainingId: 'training',
            date: '2026-10-10',
            round: round,
          ),
        ),
      );
      await tester.pumpWidget(app(1));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Iniciar tiempo'));
      await tester.pump();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.pumpWidget(app(2));
      await tester.pump();
      await tester.pump();
      expect(find.byType(Dialog), findsNothing);
      expect(
        store.values.values.every((value) => value.timedStartedAt == null),
        true,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final expired in [false, true]) {
    testWidgets(
      'restored running timer schedules only a future canonical deadline: expired=$expired',
      (tester) async {
        final now = DateTime(2026, 10, 10);
        final store = _Store();
        final started = now.subtract(Duration(seconds: expired ? 2000 : 5));
        store.values['occurrence'] = ActiveWorkoutHiveModel(
          trainingId: 'training',
          exerciseId: 'occurrence',
          currentSet: 1,
          completedSets: 0,
          timedTotalSeconds: 1440,
          timedStartedAt: started,
          timedElapsedMs: 10000,
        );
        const channel = MethodChannel('com.exommethod.exom/execution_timer');
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return null;
            });
        final coordinator = ExecutionTimerCoordinator(now: () => now);
        final bloc = ActiveExerciseBloc(
          restTimerCoordinator: _SilentRestCoordinator(),
          localStorage: store,
          trainingExercise: exercise,
          now: () => now,
        );
        bloc.add(
          const StartExercise(trainingId: 'training', exerciseId: 'occurrence'),
        );
        await tester.pump();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: bloc,
              child: Scaffold(
                body: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
                  builder: (_, state) => ExecutionTimer(
                    state: state,
                    now: () => now,
                    coordinator: coordinator,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(calls.length, expired ? 0 : 1);
        if (!expired) {
          expect((calls.single.arguments as Map)['durationSeconds'], 1425);
          expect(
            (calls.single.arguments as Map)['endsAtMillis'],
            started.add(const Duration(seconds: 1430)).millisecondsSinceEpoch,
          );
          bloc.add(const CompleteSet());
          await tester.pump();
          await tester.pump();
          expect(calls.last.method, 'cancel');
          expect(bloc.state.completedSets, 1);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(bloc.close);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      },
    );
  }

  testWidgets(
    'F007 execution at mobile width: start, pause, current/next, end and explicit progress',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = DateTime(2026, 10, 10);
      final store = _Store();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: exercise,
        now: () => now,
      );
      final boundary = GlobalKey();
      bloc.add(
        const StartExercise(trainingId: 'training', exerciseId: 'occurrence'),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: bloc,
            child: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                appBar: AppBar(title: const Text('Carrera')),
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
                    builder: (context, state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.instructions(1440),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ExecutionTimer(state: state, now: () => now),
                        const Text('30 s de descanso entre series'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Ahora: Corre'), findsOneWidget);
      expect(find.text('Siguiente: Camina'), findsOneWidget);
      expect(find.text('Tramo: 2:00 · Total restante: 24:00'), findsOneWidget);
      await capture(tester, boundary, 'app-prepared');
      await tester.tap(find.text('Iniciar tiempo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(bloc.state.timedStartedAt, isNull);
      expect(bloc.state.timedElapsedMs, 0);
      expect(find.byType(Dialog), findsOneWidget);
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 50));
      expect(bloc.state.timedStartedAt, isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(bloc.state.timedElapsedMs, 0);
      expect(bloc.state.timedStartedAt, isNull);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('En marcha'), findsOneWidget);
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(bloc.state.timedStartedAt, isNull);
      // Restore a real persisted deadline as after a process interruption, without
      // relying on callbacks or changing system time.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(bloc.close);
      store.values['occurrence'] = ActiveWorkoutHiveModel(
        trainingId: 'training',
        exerciseId: 'occurrence',
        currentSet: 1,
        completedSets: 0,
        timedTotalSeconds: 1440,
        timedPrescription: config,
        timedElapsedMs: 125000,
      );
      final restored = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: exercise,
      );
      restored.add(
        const StartExercise(trainingId: 'training', exerciseId: 'occurrence'),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: restored,
            child: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                appBar: AppBar(title: const Text('Carrera')),
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
                    builder: (context, state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.instructions(1440),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ExecutionTimer(state: state, now: () => now),
                        const Text('30 s de descanso entre series'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Ahora: Camina'), findsOneWidget);
      expect(find.text('Siguiente: Corre'), findsOneWidget);
      expect(find.text('En pausa'), findsOneWidget);
      expect(find.text('Tramo: 0:55 · Total restante: 21:55'), findsOneWidget);
      await capture(tester, boundary, 'app-paused-walking');
      expect(restored.state.completedSets, 0);
      expect(restored.state.setPerformances, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(restored.close);
    },
  );
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  // Opt-in artifact writing; ordinary suite remains independent of workspace layout.
  const output = String.fromEnvironment('F007_VISUAL_DIR');
  if (output.isEmpty) return;
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
