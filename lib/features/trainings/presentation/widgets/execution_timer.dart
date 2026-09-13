import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';

class CircuitExecutionTimer extends StatelessWidget {
  final ActiveWorkoutLocalStore store;
  final TrainingExerciseEntity exercise;
  final String trainingId;
  final String date;
  final int round;
  const CircuitExecutionTimer({
    super.key,
    required this.store,
    required this.exercise,
    required this.trainingId,
    required this.date,
    required this.round,
  });
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        ActiveExerciseBloc(localStorage: store, trainingExercise: exercise)
          ..add(
            StartExercise(
              trainingId: trainingId,
              exerciseId: '${exercise.id}:interval:$round',
              assignmentDate: date,
            ),
          ),
    child: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatExercisePrescription(
              exercise,
              savedTotalSeconds: state.timedTotalSeconds,
              savedTimedPrescription: state.timedPrescription,
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ExecutionTimer(state: state),
        ],
      ),
    ),
  );
}

class ExecutionTimer extends StatefulWidget {
  final ActiveExerciseState state;
  const ExecutionTimer({super.key, required this.state});
  @override
  State<ExecutionTimer> createState() => _ExecutionTimerState();
}

class _ExecutionTimerState extends State<ExecutionTimer> {
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    // Refresh paints the deadline-derived state; callbacks never add elapsed time.
    _refresh = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  String clock(int milliseconds) {
    final seconds = (milliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final total = state.timedTotalSeconds!;
    final config =
        state.timedPrescription ??
        const TimedPrescription(unit: TimeDisplayUnit.seconds);
    final phase = config.phase(total, state.elapsedAt(DateTime.now()));
    final done = phase.totalRemainingMilliseconds == 0;
    final running = state.timedStartedAt != null && !done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            done ? 'Tiempo finalizado' : 'Ahora: ${phase.action}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            done
                ? 'Registra la serie cuando termines.'
                : 'Tramo: ${clock(phase.remainingMilliseconds)} · Total restante: ${clock(phase.totalRemainingMilliseconds)}',
          ),
          if (phase.nextAction != null) Text('Siguiente: ${phase.nextAction}'),
          if (!done)
            Text(
              running
                  ? 'En marcha'
                  : state.timedElapsedMs > 0
                  ? 'En pausa'
                  : 'Preparado',
            ),
          Wrap(
            spacing: 8,
            children: [
              if (!done)
                FilledButton(
                  onPressed: () => context.read<ActiveExerciseBloc>().add(
                    const ToggleExecutionTimer(),
                  ),
                  child: Text(
                    running
                        ? 'Pausar'
                        : state.timedElapsedMs > 0
                        ? 'Reanudar'
                        : 'Iniciar tiempo',
                  ),
                ),
              TextButton(
                onPressed: () => context.read<ActiveExerciseBloc>().add(
                  const ResetExecutionTimer(),
                ),
                child: const Text('Reiniciar tiempo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
