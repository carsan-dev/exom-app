import 'dart:async';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'execution_start_countdown.dart';
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
  final Object? runKey;
  final ExecutionTimerCoordinator? coordinator;
  final bool Function()? isOwnerCurrent;
  const CircuitExecutionTimer({
    super.key,
    required this.store,
    required this.exercise,
    required this.trainingId,
    required this.date,
    required this.round,
    this.runKey,
    this.coordinator,
    this.isOwnerCurrent,
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
          ExecutionTimer(
            state: state,
            coordinator: coordinator,
            isOwnerCurrent: isOwnerCurrent,
            runKey: (runKey, trainingId, date, exercise.id, round),
          ),
        ],
      ),
    ),
  );
}

class ExecutionTimer extends StatefulWidget {
  final ActiveExerciseState state;
  final ExecutionTimerCoordinator? coordinator;
  final bool Function()? isOwnerCurrent;
  final Object? runKey;
  final DateTime Function()? now;
  const ExecutionTimer({
    super.key,
    required this.state,
    this.coordinator,
    this.isOwnerCurrent,
    this.runKey,
    this.now,
  });
  @override
  State<ExecutionTimer> createState() => _ExecutionTimerState();
}

class _ExecutionTimerState extends State<ExecutionTimer> {
  Timer? _refresh;
  final Object _fallbackKey = Object();
  Object? _scheduledKey;
  bool _preparing = false;
  DialogRoute<bool>? _preparationRoute;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  bool get _ownerCurrent => widget.isOwnerCurrent?.call() ?? true;

  @override
  void didUpdateWidget(ExecutionTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _synchronize();
  }

  void _synchronize() {
    final state = widget.state;
    final started = state.timedStartedAt;
    final key = (
      widget.runKey ?? _fallbackKey,
      state.currentSet,
      started,
      state.timedElapsedMs,
    );
    if (!_ownerCurrent || !state.isExecuting || started == null) {
      final prior = _scheduledKey;
      _scheduledKey = null;
      if (prior != null) {
        unawaited(widget.coordinator?.cancel(prior) ?? Future<void>.value());
      }
      return;
    }
    if (_scheduledKey == key) return;
    final prior = _scheduledKey;
    if (prior != null) {
      unawaited(widget.coordinator?.cancel(prior) ?? Future<void>.value());
    }
    _scheduledKey = key;
    final deadline = started.add(
      Duration(
        milliseconds: state.timedTotalSeconds! * 1000 - state.timedElapsedMs,
      ),
    );
    unawaited(
      widget.coordinator?.start(key: key, deadline: deadline) ??
          Future<void>.value(),
    );
  }

  Future<void> _toggle() async {
    if (_preparing || !_ownerCurrent) return;
    final bloc = context.read<ActiveExerciseBloc>();
    final original = bloc.state;
    if (original.timedStartedAt != null || original.timedElapsedMs > 0) {
      bloc.add(const ToggleExecutionTimer());
      return;
    }
    final pageRoute = ModalRoute.of(context);
    final originalKey = widget.runKey;
    bool valid() =>
        mounted &&
        _ownerCurrent &&
        widget.runKey == originalKey &&
        !bloc.isClosed &&
        bloc.state.isExecuting &&
        bloc.state.currentSet == original.currentSet &&
        bloc.state.sessionId == original.sessionId &&
        bloc.state.timedStartedAt == null &&
        bloc.state.timedElapsedMs == 0;
    _preparing = true;
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExecutionStartCountdown(isValid: valid, now: widget.now),
    );
    _preparationRoute = route;
    final start = await Navigator.of(context).push(route);
    // Dialog pop starts, rather than completes, the closing animation.
    await route.completed;
    if (!mounted) return;
    _preparing = false;
    _preparationRoute = null;
    if (start == true &&
        valid() &&
        pageRoute?.isCurrent == true &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed)) {
      bloc.add(const ToggleExecutionTimer());
    }
  }

  @override
  void initState() {
    super.initState();
    _synchronize();
    // Refresh paints the deadline-derived state; callbacks never add elapsed time.
    _refresh = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    final key = _scheduledKey;
    if (key != null) {
      unawaited(widget.coordinator?.cancel(key) ?? Future<void>.value());
    }
    final route = _preparationRoute;
    if (route != null) {
      // Removing the owning page must not leave a modal on the next page.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.navigator != null && route.isActive) {
          route.navigator!.removeRoute(route);
        }
      });
    }
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
    final phase = config.phase(total, state.elapsedAt(_now));
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
                  onPressed: _toggle,
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
