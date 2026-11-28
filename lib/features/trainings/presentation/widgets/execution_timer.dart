import 'package:exom_app/l10n/app_localizations.dart';
import 'dart:async';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'execution_start_countdown.dart';
import 'rest_countdown.dart';
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
  Timer? _figure;
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
    _scheduleFigure();
  }

  /// Repaints the «m:ss» figures on the next whole second of the segment or
  /// of the total while running (round r3, D1), so they change in the same
  /// frame as the rule instead of up to 200 ms later. Display only: the end
  /// is still dispatched by the coordinator and the 200 ms refresh stays.
  void _scheduleFigure() {
    _figure?.cancel();
    _figure = null;
    final state = widget.state;
    final total = state.timedTotalSeconds;
    if (state.timedStartedAt == null || total == null) return;
    final config =
        state.timedPrescription ??
        const TimedPrescription(unit: TimeDisplayUnit.seconds);
    final phase = config.phase(total, state.elapsedAt(_now));
    final waits = [
      untilFigureChange(phase.remainingMilliseconds),
      untilFigureChange(phase.totalRemainingMilliseconds),
    ].whereType<Duration>();
    if (waits.isEmpty) return;
    _figure = Timer(waits.reduce((a, b) => a < b ? a : b), () {
      if (!mounted) return;
      setState(() {});
      _scheduleFigure();
    });
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
    _scheduleFigure();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _figure?.cancel();
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

  /// Rule of the current phase (L5-E3e, L5-D48 «N1 · Barra con tic»): the
  /// whole seconds left of the phase over its length, from the same reading of
  /// the clock as the clock line, so the bar steps in the rebuild of the
  /// figures ([_scheduleFigure]) and the 200 ms refresh only repaints it when
  /// nothing changed. Each phase (e.g. «Corre» → «Camina») gets a fresh rule,
  /// full and without animating; once finished the bar is empty and the scale
  /// keeps the last phase.
  Widget _phaseRule(int total, TimedPrescription config, TimedPhase phase) {
    final done = phase.totalRemainingMilliseconds == 0;
    final length = done
        ? config.phase(total, total * 1000 - 1).durationMilliseconds
        : phase.durationMilliseconds;
    return RestStepRule(
      // Time left after this phase: the same for all of it, and 0 for the
      // last phase, which the finished state keeps.
      key: ValueKey(
        phase.totalRemainingMilliseconds - phase.remainingMilliseconds,
      ),
      remainingSeconds: done || length <= 0
          ? 0
          : (phase.remainingMilliseconds / 1000).ceil(),
      totalSeconds: (length / 1000).ceil(),
    );
  }

  String clock(int milliseconds) {
    final seconds = (milliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final total = state.timedTotalSeconds!;
    final config =
        state.timedPrescription ??
        const TimedPrescription(unit: TimeDisplayUnit.seconds);
    final phase = config.phase(total, state.elapsedAt(_now));
    final done = phase.totalRemainingMilliseconds == 0;
    final running = state.timedStartedAt != null && !done;
    final singlePhase = config.segments.isEmpty;
    final figure = CountdownFigure(
      key: const Key('execution-timer-figure'),
      seconds: (phase.remainingMilliseconds / 1000).ceil(),
      pulse: running,
      figureKey: const Key('execution-timer-clock'),
    );
    final palette = context.exomPalette;
    final body = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      height: 1.4,
      color: palette.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final secondary = body.copyWith(
      fontSize: 14,
      color: palette.textSecondary,
    );
    // L5-E3a: the timer is a secondary action of the executing state; the
    // only lime action stays «Registrar serie» in the footer (principle 15).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            done ? l10n.timerFinished : l10n.timerNowAction(phase.action),
            style: body.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          // One phase (no segments): the figure below already says what the
          // segment line said, so it only stays to carry the total of
          // several phases, or the hint once finished.
          if (done || !singlePhase) ...[
            const SizedBox(height: 4),
            Text(
              done
                  ? l10n.timerLogSetWhenDone
                  : l10n.timerSegmentRemaining(
                      clock(phase.remainingMilliseconds),
                      clock(phase.totalRemainingMilliseconds),
                    ),
              style: body,
            ),
          ],
          // The big figure of the rest countdown, on the seconds left of the
          // current phase, with the same spacing as the rest (headline, 16,
          // figure, rule). It beats over the last seconds only while running;
          // paused, it stays still. Not a live region: with one phase it
          // carries the label the segment line had, otherwise the line above
          // speaks and the figure is hidden from screen readers.
          const SizedBox(height: 16),
          if (singlePhase && !done)
            Semantics(
              container: true,
              label: l10n.timerSegmentRemaining(
                clock(phase.remainingMilliseconds),
                clock(phase.totalRemainingMilliseconds),
              ),
              excludeSemantics: true,
              child: figure,
            )
          else
            ExcludeSemantics(child: figure),
          // Same rule, scale and spacing as the rest countdown (L5-E3a,
          // L5-D48), on the deadline-derived phase, so a paused timer leaves
          // it still. Decorative: the figure or the line above carries the
          // semantics.
          const SizedBox(height: RestStepRule.gapAbove),
          // The key marks the rule and its scale for tests and debugging;
          // round r2 moved it here from the bare rule (no reader in lib/ or
          // test/ used it at that point).
          ExcludeSemantics(
            key: const Key('execution-timer-rule'),
            child: _phaseRule(total, config, phase),
          ),
          const SizedBox(height: 12),
          if (phase.nextAction != null)
            Text(l10n.timerNextAction(phase.nextAction!), style: secondary),
          if (!done)
            Text(
              running
                  ? l10n.timerRunning
                  : state.timedElapsedMs > 0
                  ? l10n.timerPaused
                  : l10n.timerReady,
              style: secondary,
            ),
          const SizedBox(height: 12),
          if (!done)
            ExomSecondaryButton(
              label: running
                  ? l10n.timerPause
                  : state.timedElapsedMs > 0
                  ? l10n.timerResume
                  : l10n.timerStart,
              onPressed: _toggle,
            ),
          Center(
            child: ExomQuietButton(
              label: l10n.timerReset,
              onPressed: () => context.read<ActiveExerciseBloc>().add(
                const ResetExecutionTimer(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
