import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/utils/training_type_utils.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/circuit_progression.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_video_preview.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ActiveCircuitPageArgs {
  final TrainingBloc trainingBloc;
  final String trainingName;
  final List<String> trainingTypes;
  final String? accentColorHex;
  final String trainingLevel;
  final String blockId;
  final String blockName;
  final int rounds;
  final int restBetweenRoundsSeconds;
  final List<TrainingExerciseEntity> exercises;

  const ActiveCircuitPageArgs({
    required this.trainingBloc,
    required this.trainingName,
    required this.trainingTypes,
    required this.accentColorHex,
    required this.trainingLevel,
    required this.blockId,
    required this.blockName,
    required this.rounds,
    required this.restBetweenRoundsSeconds,
    required this.exercises,
  });
}

enum _CircuitStatus { executing, exerciseResting, roundResting, done }

class ActiveCircuitPage extends StatelessWidget {
  final String trainingId;
  final String blockId;
  final ActiveCircuitPageArgs? args;

  const ActiveCircuitPage({
    super.key,
    required this.trainingId,
    required this.blockId,
    required this.args,
  });

  @override
  Widget build(BuildContext context) {
    final pageArgs = args;
    if (pageArgs == null || pageArgs.exercises.isEmpty) {
      return ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: const Center(child: Text('Missing active circuit context')),
        ),
      );
    }

    return BlocProvider<TrainingBloc>.value(
      value: pageArgs.trainingBloc,
      child: _ActiveCircuitView(trainingId: trainingId, args: pageArgs),
    );
  }
}

class _ActiveCircuitView extends StatefulWidget {
  final String trainingId;
  final ActiveCircuitPageArgs args;

  const _ActiveCircuitView({required this.trainingId, required this.args});

  @override
  State<_ActiveCircuitView> createState() => _ActiveCircuitViewState();
}

class _ActiveCircuitViewState extends State<_ActiveCircuitView> {
  var _currentRound = 1;
  var _currentExerciseIndex = 0;
  var _status = _CircuitStatus.executing;
  DateTime? _restEndsAt;
  bool _markedComplete = false;
  final Map<String, List<SetPerformance>> _performances = {};

  Color _typeColor(BuildContext context) {
    return trainingAccentColor(
      context,
      accentColor: widget.args.accentColorHex,
      types: widget.args.trainingTypes,
    );
  }

  TrainingExerciseEntity get _currentExercise =>
      widget.args.exercises[_currentExerciseIndex];

  Future<void> _openVideoPlayer() async {
    final exercise = _currentExercise.exercise;
    final videoUrl = exercise.videoUrl?.trim();
    if (videoUrl == null || videoUrl.isEmpty) return;

    final uri = Uri.tryParse(videoUrl);
    if (uri == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ExerciseVideoPlayerPage(title: exercise.name, videoUri: uri),
      ),
    );
  }

  String _formatPrescription(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final lower = trimmed.toLowerCase();
    final hasUnit = RegExp(
      r'(rep|repet|seg|sec|min|s\b|kg|kilo|lb|libra|cada|c/l|max|amrap|rm)',
    ).hasMatch(lower);
    if (hasUnit) return trimmed;

    final looksLikeReps = RegExp(
      r'^\d+([-,/]\d+)?$',
    ).hasMatch(trimmed.replaceAll(' ', ''));
    return looksLikeReps ? '$trimmed reps' : trimmed;
  }

  Future<bool> _confirmExit() async {
    if (_status == _CircuitStatus.done) return true;

    final l10n = AppLocalizations.of(context);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activeExerciseCloseTitle),
        content: Text(
          l10n.activeExerciseCloseMessage(
            _currentExerciseIndex,
            widget.args.exercises.length * widget.args.rounds,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.continueButton),
          ),
        ],
      ),
    );

    return shouldLeave == true;
  }

  Future<void> _completeCurrentSeries() async {
    if (_status != _CircuitStatus.executing) return;

    final tracking = await _requestPerformance(_currentExercise);
    if (!mounted || tracking == null) return;
    final performance = tracking.performance;
    if (performance != null) {
      _performances.update(
        _currentExercise.id,
        (sets) => [...sets, performance],
        ifAbsent: () => [performance],
      );
    }

    final progression = advanceCircuit(
      currentRound: _currentRound,
      totalRounds: widget.args.rounds,
      currentExerciseIndex: _currentExerciseIndex,
      exerciseCount: widget.args.exercises.length,
      exerciseRestSeconds: _currentExercise.restSeconds,
      roundRestSeconds: widget.args.restBetweenRoundsSeconds,
    );
    if (progression.restKind == CircuitRestKind.done) {
      _finishCircuit();
      return;
    }

    setState(() {
      if (progression.restKind == CircuitRestKind.round) {
        _status = _CircuitStatus.roundResting;
      } else if (progression.restKind == CircuitRestKind.exercise) {
        _status = _CircuitStatus.exerciseResting;
      }
      if (progression.restKind == CircuitRestKind.none) {
        _currentRound = progression.nextRound;
        _currentExerciseIndex = progression.nextExerciseIndex;
      } else {
        _restEndsAt = DateTime.now().add(
          Duration(seconds: progression.restSeconds),
        );
        if (progression.restKind == CircuitRestKind.exercise) {
          _currentExerciseIndex = progression.nextExerciseIndex;
        }
      }
    });
  }

  Future<({SetPerformance? performance, bool skipped})?> _requestPerformance(
    TrainingExerciseEntity trainingExercise,
  ) async {
    final l10n = AppLocalizations.of(context);
    final repsController = TextEditingController();
    final previousWeight = _performances[trainingExercise.id]?.last.weightKg;
    final weightController = TextEditingController(
      text: previousWeight?.toString() ?? '',
    );
    String? error;
    final result =
        await showDialog<({SetPerformance? performance, bool skipped})>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: Text(l10n.setPerformanceTitle(_currentRound)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.setPerformancePrescription(
                      trainingExercise.repsOrDuration,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: repsController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.setPerformanceReps,
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.setPerformanceWeightOptional,
                      suffixText: 'kg',
                    ),
                  ),
                ],
              ),
              actions: [
                if (!trainingExercise.requestSetTracking)
                  TextButton(
                    onPressed: () => Navigator.of(
                      dialogContext,
                    ).pop((performance: null, skipped: true)),
                    child: Text(l10n.completeWithoutTracking),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final reps = int.tryParse(repsController.text.trim());
                    final weightText = weightController.text.trim();
                    final weight = weightText.isEmpty
                        ? null
                        : double.tryParse(weightText.replaceAll(',', '.'));
                    if (trainingExercise.requestSetTracking &&
                        (reps == null || reps < 1)) {
                      setDialogState(
                        () => error = l10n.setPerformanceRepsError,
                      );
                      return;
                    }
                    if (reps != null && reps < 1) {
                      setDialogState(
                        () => error = l10n.setPerformanceRepsError,
                      );
                      return;
                    }
                    if (weight != null && weight < 0) {
                      setDialogState(
                        () => error = l10n.setPerformanceWeightError,
                      );
                      return;
                    }
                    if (reps == null && weight == null) {
                      setDialogState(
                        () => error = l10n.setPerformanceDataError,
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop((
                      performance: SetPerformance(
                        setNumber: _currentRound,
                        reps: reps,
                        weightKg: weight,
                      ),
                      skipped: false,
                    ));
                  },
                  child: Text(l10n.weightInputSave),
                ),
              ],
            ),
          ),
        );
    repsController.dispose();
    weightController.dispose();
    return result;
  }

  void _finishRest() {
    if (_status != _CircuitStatus.roundResting &&
        _status != _CircuitStatus.exerciseResting) {
      return;
    }

    setState(() {
      if (_status == _CircuitStatus.roundResting) {
        _currentRound += 1;
        _currentExerciseIndex = 0;
      }
      _status = _CircuitStatus.executing;
      _restEndsAt = null;
    });
  }

  void _finishCircuit() {
    if (_markedComplete) return;
    _markedComplete = true;

    for (final trainingExercise in widget.args.exercises) {
      final sets = _performances[trainingExercise.id];
      context.read<TrainingBloc>().add(
        MarkExerciseCompleted(
          trainingExerciseId: trainingExercise.id,
          exerciseId: trainingExercise.exercise.id,
          completed: true,
          weightUsed: sets == null || sets.isEmpty ? null : sets.last.weightKg,
          sets: sets,
        ),
      );
    }

    setState(() {
      _status = _CircuitStatus.done;
    });
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final color = _typeColor(context);
    final exercise = _currentExercise.exercise;
    final completedSeries =
        ((_currentRound - 1) * widget.args.exercises.length) +
        _currentExerciseIndex;
    final totalSeries = widget.args.exercises.length * widget.args.rounds;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldClose = await _confirmExit();
        if (!context.mounted || !shouldClose) return;
        context.pop();
      },
      child: ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.close_rounded,
                        onTap: () async {
                          final shouldClose = await _confirmExit();
                          if (!context.mounted || !shouldClose) return;
                          context.pop();
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              widget.args.trainingName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.args.blockName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 200,
                          child: ExerciseVideoPreview(
                            title: exercise.name,
                            videoUrl: exercise.videoUrl,
                            thumbnailUrl: exercise.thumbnailUrl,
                            onTap: _openVideoPlayer,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: GlassDecoration.card(borderRadius: 24),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _StatusPill(
                                    label:
                                        _status == _CircuitStatus.roundResting
                                        ? l10n.circuitRoundRestTitle
                                        : _status ==
                                              _CircuitStatus.exerciseResting
                                        ? l10n.circuitExerciseRestTitle
                                        : l10n.activeExerciseExecuting,
                                    color:
                                        _status ==
                                                _CircuitStatus.roundResting ||
                                            _status ==
                                                _CircuitStatus.exerciseResting
                                        ? semantic.warning
                                        : color,
                                  ),
                                  const Spacer(),
                                  Text(
                                    widget.args.trainingLevel,
                                    style: TextStyle(
                                      color: palette.textDisabled,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                l10n.circuitRoundProgress(
                                  _currentRound,
                                  widget.args.rounds,
                                ),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.circuitExerciseProgress(
                                  _currentExerciseIndex + 1,
                                  widget.args.exercises.length,
                                ),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                exercise.name,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatPrescription(
                                  _currentExercise.repsOrDuration,
                                ),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: totalSeries == 0
                                    ? 0
                                    : completedSeries / totalSeries,
                                minHeight: 8,
                                backgroundColor: palette.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _status == _CircuitStatus.done
                                      ? semantic.success
                                      : color,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ],
                          ),
                        ),
                        if (exercise.techniqueText?.trim().isNotEmpty == true)
                          _DetailSection(
                            title: l10n.technique,
                            text: exercise.techniqueText!,
                          ),
                        if (exercise.commonErrorsText?.trim().isNotEmpty ==
                            true)
                          _DetailSection(
                            title: l10n.commonMistakes,
                            text: exercise.commonErrorsText!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child:
                  _status == _CircuitStatus.roundResting ||
                      _status == _CircuitStatus.exerciseResting
                  ? _RoundRestFooter(
                      key: ValueKey(
                        'round-rest-${_restEndsAt?.millisecondsSinceEpoch}',
                      ),
                      totalSeconds: _status == _CircuitStatus.roundResting
                          ? widget.args.restBetweenRoundsSeconds
                          : widget
                                .args
                                .exercises[_currentExerciseIndex - 1]
                                .restSeconds,
                      restEndsAt: _restEndsAt ?? DateTime.now(),
                      title: _status == _CircuitStatus.roundResting
                          ? l10n.circuitRoundRestTitle
                          : l10n.circuitExerciseRestTitle,
                      nextExerciseName: _status == _CircuitStatus.roundResting
                          ? widget.args.exercises.first.exercise.name
                          : _currentExercise.exercise.name,
                      onSkip: _finishRest,
                    )
                  : SizedBox(
                      key: const ValueKey('circuit-executing-footer'),
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _completeCurrentSeries,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: palette.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        child: Text(l10n.completeSetButton.toUpperCase()),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Material(
      color: palette.surfaceVariant.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: palette.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoundRestFooter extends StatefulWidget {
  final int totalSeconds;
  final DateTime restEndsAt;
  final VoidCallback onSkip;
  final String title;
  final String nextExerciseName;

  const _RoundRestFooter({
    super.key,
    required this.totalSeconds,
    required this.restEndsAt,
    required this.onSkip,
    required this.title,
    required this.nextExerciseName,
  });

  @override
  State<_RoundRestFooter> createState() => _RoundRestFooterState();
}

class _RoundRestFooterState extends State<_RoundRestFooter> {
  Timer? _ticker;
  bool _didFinish = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0 && !_didFinish) {
        _didFinish = true;
        _ticker?.cancel();
        widget.onSkip();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _remainingSeconds {
    final remainingMs = widget.restEndsAt
        .difference(DateTime.now())
        .inMilliseconds;
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final remaining = _remainingSeconds;

    return Container(
      decoration: GlassDecoration.card(borderRadius: 22),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: palette.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(remaining),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.restTimerNextExercise(widget.nextExerciseName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: widget.onSkip,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            child: Text(l10n.restTimerSkip.toUpperCase()),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String text;

  const _DetailSection({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      decoration: GlassDecoration.card(borderRadius: 20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
