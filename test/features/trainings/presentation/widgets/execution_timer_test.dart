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
  testWidgets(
    'F007 execution at mobile width: start, pause, current/next, end and explicit progress',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _Store();
      final bloc = ActiveExerciseBloc(
        localStorage: store,
        trainingExercise: exercise,
      );
      final boundary = GlobalKey();
      bloc.add(
        const StartExercise(trainingId: 'training', exerciseId: 'occurrence'),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
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
                        ExecutionTimer(state: state),
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
                        ExecutionTimer(state: state),
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
