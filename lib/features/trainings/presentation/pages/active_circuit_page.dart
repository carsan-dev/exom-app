import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/utils/training_type_utils.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
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

enum _CircuitStatus { executing, roundResting, done }

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

  Color _typeColor(BuildContext context) {
    return trainingAccentColor(
      context,
      accentColor: widget.args.accentColorHex,
      types: widget.args.trainingTypes,
    );
  }

  TrainingExerciseEntity get _currentExercise =>
      widget.args.exercises[_currentExerciseIndex];

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

  void _completeCurrentSeries() {
    if (_status != _CircuitStatus.executing) return;

    final isLastExercise =
        _currentExerciseIndex >= widget.args.exercises.length - 1;
    final isLastRound = _currentRound >= widget.args.rounds;

    if (!isLastExercise) {
      setState(() {
        _currentExerciseIndex += 1;
      });
      return;
    }

    if (!isLastRound) {
      setState(() {
        _status = _CircuitStatus.roundResting;
        _restEndsAt = DateTime.now().add(
          Duration(
            seconds: widget.args.restBetweenRoundsSeconds.clamp(0, 3600),
          ),
        );
      });
      return;
    }

    _finishCircuit();
  }

  void _startNextRound() {
    if (_status != _CircuitStatus.roundResting) return;

    setState(() {
      _currentRound += 1;
      _currentExerciseIndex = 0;
      _status = _CircuitStatus.executing;
      _restEndsAt = null;
    });
  }

  void _finishCircuit() {
    if (_markedComplete) return;
    _markedComplete = true;

    for (final trainingExercise in widget.args.exercises) {
      context.read<TrainingBloc>().add(
        MarkExerciseCompleted(
          trainingExerciseId: trainingExercise.id,
          exerciseId: trainingExercise.exercise.id,
          completed: true,
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
                            onTap: null,
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
                                        : l10n.activeExerciseExecuting,
                                    color:
                                        _status == _CircuitStatus.roundResting
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
                                _currentExercise.repsOrDuration,
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
              child: _status == _CircuitStatus.roundResting
                  ? _RoundRestFooter(
                      key: ValueKey(
                        'round-rest-${_restEndsAt?.millisecondsSinceEpoch}',
                      ),
                      totalSeconds: widget.args.restBetweenRoundsSeconds,
                      restEndsAt: _restEndsAt ?? DateTime.now(),
                      onSkip: _startNextRound,
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

  const _RoundRestFooter({
    super.key,
    required this.totalSeconds,
    required this.restEndsAt,
    required this.onSkip,
  });

  @override
  State<_RoundRestFooter> createState() => _RoundRestFooterState();
}

class _RoundRestFooterState extends State<_RoundRestFooter> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
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
                  l10n.circuitRoundRestTitle,
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
