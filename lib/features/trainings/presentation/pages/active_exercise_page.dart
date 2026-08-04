import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/utils/training_type_utils.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_video_preview.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class ActiveExercisePageArgs {
  final TrainingBloc trainingBloc;
  final TrainingExerciseEntity trainingExercise;
  final String trainingName;
  final List<String> trainingTypes;
  final String? accentColorHex;
  final String trainingLevel;
  final double? initialWeightKg;
  final List<SetPerformance>? currentPerformances;
  final List<SetPerformance>? previousPerformances;

  const ActiveExercisePageArgs({
    required this.trainingBloc,
    required this.trainingExercise,
    required this.trainingName,
    required this.trainingTypes,
    required this.accentColorHex,
    required this.trainingLevel,
    this.initialWeightKg,
    this.currentPerformances,
    this.previousPerformances,
  });
}

class ActiveExercisePage extends StatelessWidget {
  final String trainingId;
  final String exerciseId;
  final ActiveExercisePageArgs? args;

  const ActiveExercisePage({
    super.key,
    required this.trainingId,
    required this.exerciseId,
    required this.args,
  });

  @override
  Widget build(BuildContext context) {
    final pageArgs = args;
    if (pageArgs == null) {
      return ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: const Center(
            child: ErrorWidget2(
              message: 'Missing active exercise context',
              onRetry: null,
            ),
          ),
        ),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<TrainingBloc>.value(value: pageArgs.trainingBloc),
        BlocProvider(
          create: (_) => ActiveExerciseBloc(
            localStorage: sl<LocalStorage>(),
            restTimerCoordinator: sl(),
            trainingExercise: pageArgs.trainingExercise,
            initialWeightKg: pageArgs.initialWeightKg,
          ),
        ),
      ],
      child: _ActiveExerciseView(
        trainingId: trainingId,
        exerciseId: exerciseId,
        args: pageArgs,
      ),
    );
  }
}

class _ActiveExerciseView extends StatefulWidget {
  final String trainingId;
  final String exerciseId;
  final ActiveExercisePageArgs args;

  const _ActiveExerciseView({
    required this.trainingId,
    required this.exerciseId,
    required this.args,
  });

  @override
  State<_ActiveExerciseView> createState() => _ActiveExerciseViewState();
}

class _ActiveExerciseViewState extends State<_ActiveExerciseView> {
  bool _bootstrapped = false;
  bool _handledCompletion = false;
  bool _allowPop = false;
  bool _popScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Color _typeColor(BuildContext context) {
    return trainingAccentColor(
      context,
      accentColor: widget.args.accentColorHex,
      types: widget.args.trainingTypes,
    );
  }

  void _popOnce() {
    if (!mounted || _popScheduled) return;

    _popScheduled = true;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _bootstrap() async {
    final storage = sl<LocalStorage>();
    final foreignWorkouts = storage.getForeignActiveWorkouts(widget.trainingId);

    if (foreignWorkouts.isNotEmpty) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(l10n.activeExerciseDiscardTitle),
            content: Text(l10n.activeExerciseDiscardMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.activeExerciseDiscardAction),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (shouldDiscard != true) {
        _popOnce();
        return;
      }

      await storage.clearForeignActiveWorkouts(widget.trainingId);
    }

    if (!mounted) return;
    context.read<ActiveExerciseBloc>().add(
      StartExercise(
        trainingId: widget.trainingId,
        exerciseId: widget.exerciseId,
      ),
    );

    setState(() {
      _bootstrapped = true;
    });
  }

  Future<bool> _confirmExit() async {
    final state = context.read<ActiveExerciseBloc>().state;
    if (state.isDone) return true;

    if (state.completedSets == 0) {
      context.read<ActiveExerciseBloc>().add(const AbandonExercise());
      return true;
    }

    final l10n = AppLocalizations.of(context);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activeExerciseCloseTitle),
        content: Text(
          l10n.activeExerciseCloseMessage(state.completedSets, state.totalSets),
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

    if (!mounted) return false;
    if (shouldLeave == true) {
      context.read<ActiveExerciseBloc>().add(const AbandonExercise());
      return true;
    }

    return false;
  }

  Future<void> _onCompleteSetPressed(
    ActiveExerciseState state,
    AppLocalizations l10n,
  ) async {
    final timeUnit = timePerformanceUnit(state.repsOrDuration);
    final performance = await _showSetPerformanceSheet(
      context,
      l10n,
      setNumber: state.currentSet,
      prescribedReps: state.repsOrDuration,
      previousWeight: state.weightKg,
      currentPerformance: performanceForSet(
        widget.args.currentPerformances,
        state.currentSet,
      ),
      previousPerformance: performanceForSet(
        widget.args.previousPerformances,
        state.currentSet,
      ),
      timeUnit: timeUnit,
      repsRequired: widget.args.trainingExercise.requestSetTracking,
    );
    if (!mounted || performance == null) return;

    context.read<ActiveExerciseBloc>().add(
      performance.skipped
          ? const CompleteSet()
          : CompleteSet(
              reps: performance.reps,
              seconds: performance.seconds,
              weightKg: performance.weight,
            ),
    );
  }

  Future<void> _openVideoPlayer() async {
    final videoUrl = widget.args.trainingExercise.exercise.videoUrl?.trim();
    if (videoUrl == null || videoUrl.isEmpty) return;

    final uri = Uri.tryParse(videoUrl);
    if (uri == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseVideoPlayerPage(
          title: widget.args.trainingExercise.exercise.name,
          videoUri: uri,
        ),
      ),
    );
  }

  String _formatWeight(double weight) {
    return weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1);
  }

  bool _hasContent(String? value) => value != null && value.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exercise = widget.args.trainingExercise.exercise;
    final typeColor = _typeColor(context);
    final solidTypeStyle = trainingColorStyle(context, typeColor);

    if (!_bootstrapped) {
      return ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: const Center(child: LoadingWidget()),
        ),
      );
    }

    return BlocListener<ActiveExerciseBloc, ActiveExerciseState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }

        if (!_handledCompletion && state.isDone) {
          _handledCompletion = true;
          context.read<TrainingBloc>().add(
            MarkExerciseCompleted(
              trainingExerciseId: widget.args.trainingExercise.id,
              exerciseId: exercise.id,
              completed: true,
              weightUsed: state.weightKg,
              sets: state.setPerformances,
            ),
          );
          _popOnce();
        }
      },
      child: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
        builder: (context, state) {
          final palette = context.exomPalette;
          final semantic = context.exomSemantic;
          final prescriptionLabel = state.weightKg == null
              ? state.repsOrDuration
              : '${state.repsOrDuration} x ${_formatWeight(state.weightKg!)} kg';
          final previousPerformance = performanceForSet(
            widget.args.previousPerformances,
            state.currentSet,
          );
          final previousPerformanceLabel = previousPerformance == null
              ? null
              : formatSetPerformance(previousPerformance);

          return PopScope<void>(
            canPop: _allowPop,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final shouldClose = await _confirmExit();
              if (!context.mounted || !shouldClose) return;
              _popOnce();
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
                                _popOnce();
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
                                    exercise.name,
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
                                decoration: GlassDecoration.card(
                                  borderRadius: 24,
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: typeColor.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            state.isResting
                                                ? l10n.activeExerciseResting
                                                : l10n.activeExerciseExecuting,
                                            style: TextStyle(
                                              color: typeColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
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
                                      l10n.exerciseSetProgress(
                                        state.currentSet,
                                        state.totalSets,
                                      ),
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      prescriptionLabel,
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (previousPerformanceLabel != null &&
                                        previousPerformanceLabel
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        l10n.setPerformancePrevious(
                                          previousPerformanceLabel,
                                        ),
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    if (state.weightKg != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.activeExerciseLastWeight(
                                          _formatWeight(state.weightKg!),
                                        ),
                                        style: TextStyle(
                                          color: palette.textDisabled,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    LinearProgressIndicator(
                                      value: state.totalSets == 0
                                          ? 0
                                          : state.completedSets /
                                                state.totalSets,
                                      minHeight: 8,
                                      backgroundColor: palette.surfaceVariant,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        state.isDone
                                            ? semantic.success
                                            : typeColor,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.exerciseSeriesProgress(
                                        state.completedSets,
                                        state.totalSets,
                                      ),
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_hasContent(exercise.techniqueText)) ...[
                                const SizedBox(height: 14),
                                _DetailSection(
                                  title: l10n.technique,
                                  text: exercise.techniqueText!,
                                ),
                              ],
                              if (_hasContent(exercise.commonErrorsText)) ...[
                                const SizedBox(height: 14),
                                _DetailSection(
                                  title: l10n.commonMistakes,
                                  text: exercise.commonErrorsText!,
                                ),
                              ],
                              if (_hasContent(exercise.explanationText)) ...[
                                const SizedBox(height: 14),
                                _DetailSection(
                                  title: l10n.explanation,
                                  text: exercise.explanationText!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    trainingFooterBottomPadding(
                      platform: defaultTargetPlatform,
                      navigationInset: MediaQuery.viewPaddingOf(context).bottom,
                      systemGestureInset: MediaQuery.systemGestureInsetsOf(
                        context,
                      ).bottom,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: switch (state.status) {
                        ActiveExerciseStatus.executing => SizedBox(
                          key: const ValueKey('footer-executing'),
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _onCompleteSetPressed(state, l10n),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  state.currentSet == state.totalSets
                                  ? semantic.success
                                  : typeColor,
                              foregroundColor:
                                  state.currentSet == state.totalSets
                                  ? palette.onPrimary
                                  : solidTypeStyle.foreground,
                              side: state.currentSet == state.totalSets
                                  ? null
                                  : BorderSide(color: solidTypeStyle.border),
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
                        ActiveExerciseStatus.resting => _RestingFooter(
                          key: ValueKey(
                            'footer-resting-${state.restEndsAt?.millisecondsSinceEpoch}',
                          ),
                          totalSeconds: state.restSeconds,
                          restEndsAt: state.restEndsAt!,
                          onSkip: () => context.read<ActiveExerciseBloc>().add(
                            const SkipRest(),
                          ),
                          onFinished: () => context
                              .read<ActiveExerciseBloc>()
                              .add(const SkipRest()),
                        ),
                        ActiveExerciseStatus.finalResting => _RestingFooter(
                          key: ValueKey(
                            'footer-final-resting-${state.restEndsAt?.millisecondsSinceEpoch}',
                          ),
                          totalSeconds: state.restSeconds,
                          restEndsAt: state.restEndsAt!,
                          onSkip: () => context.read<ActiveExerciseBloc>().add(
                            const SkipRest(),
                          ),
                          onFinished: () => context
                              .read<ActiveExerciseBloc>()
                              .add(const SkipRest()),
                        ),
                        ActiveExerciseStatus.done => Container(
                          key: const ValueKey('footer-done'),
                          decoration: GlassDecoration.card(borderRadius: 22),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                palette.primary,
                              ),
                            ),
                          ),
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

@visibleForTesting
double trainingFooterBottomPadding({
  required TargetPlatform platform,
  required double navigationInset,
  required double systemGestureInset,
}) {
  const margin = 16.0;
  if (platform != TargetPlatform.android) return margin;

  // Gesture navigation normally reports the same bottom area in both insets.
  // A larger view padding means a persistent three-button navigation bar.
  final usesButtonNavigation =
      navigationInset > systemGestureInset + precisionErrorTolerance;
  return usesButtonNavigation
      ? navigationInset + margin
      : navigationInset.clamp(margin, double.infinity);
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

class _DetailSection extends StatelessWidget {
  final String title;
  final String text;

  const _DetailSection({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Container(
      width: double.infinity,
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

class _RestingFooter extends StatefulWidget {
  final int totalSeconds;
  final DateTime restEndsAt;
  final VoidCallback onSkip;
  final VoidCallback onFinished;

  const _RestingFooter({
    super.key,
    required this.totalSeconds,
    required this.restEndsAt,
    required this.onSkip,
    required this.onFinished,
  });

  @override
  State<_RestingFooter> createState() => _RestingFooterState();
}

class _RestingFooterState extends State<_RestingFooter> {
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
        widget.onFinished();
        return;
      }
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _remainingSeconds <= 0 && !_didFinish) {
        _didFinish = true;
        _ticker?.cancel();
        widget.onFinished();
      }
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

  double get _progressValue {
    if (widget.totalSeconds <= 0) return 0;
    return _remainingSeconds.clamp(0, widget.totalSeconds) /
        widget.totalSeconds;
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) {
      return '${seconds}s';
    }
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
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _progressValue,
                    strokeWidth: 4,
                    backgroundColor: palette.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                  ),
                ),
                Text(
                  '$remaining',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.restTimerTitle,
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
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: widget.onSkip,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            child: Text(l10n.restTimerSkip.toUpperCase()),
          ),
        ],
      ),
    );
  }
}

typedef _SetPerformanceResult = ({
  int? reps,
  int? seconds,
  double? weight,
  bool skipped,
});

Future<_SetPerformanceResult?> _showSetPerformanceSheet(
  BuildContext context,
  AppLocalizations l10n, {
  required int setNumber,
  required String prescribedReps,
  required bool repsRequired,
  required TimePerformanceUnit? timeUnit,
  double? previousWeight,
  SetPerformance? currentPerformance,
  SetPerformance? previousPerformance,
}) async {
  final palette = context.exomPalette;
  final sheetDisposed = Completer<void>();
  final result = await showModalBottomSheet<_SetPerformanceResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SetPerformanceSheet(
      l10n: l10n,
      setNumber: setNumber,
      prescribedReps: prescribedReps,
      repsRequired: repsRequired,
      timeUnit: timeUnit,
      previousWeight: previousWeight,
      currentPerformance: currentPerformance,
      previousPerformance: previousPerformance,
      onDisposed: () {
        if (!sheetDisposed.isCompleted) sheetDisposed.complete();
      },
    ),
  );

  // Navigator completes the route result before its reverse transition and
  // subtree disposal finish. Wait so the parent BLoC cannot replace/pop this
  // page while the sheet still owns inherited dependencies and text inputs.
  if (!sheetDisposed.isCompleted) await sheetDisposed.future;
  return result;
}

class _SetPerformanceSheet extends StatefulWidget {
  final AppLocalizations l10n;
  final int setNumber;
  final String prescribedReps;
  final bool repsRequired;
  final TimePerformanceUnit? timeUnit;
  final double? previousWeight;
  final SetPerformance? currentPerformance;
  final SetPerformance? previousPerformance;
  final VoidCallback onDisposed;

  const _SetPerformanceSheet({
    required this.l10n,
    required this.setNumber,
    required this.prescribedReps,
    required this.repsRequired,
    required this.timeUnit,
    required this.previousWeight,
    required this.currentPerformance,
    required this.previousPerformance,
    required this.onDisposed,
  });

  @override
  State<_SetPerformanceSheet> createState() => _SetPerformanceSheetState();
}

class _SetPerformanceSheetState extends State<_SetPerformanceSheet> {
  late final TextEditingController _valueController;
  late final TextEditingController _weightController;
  String? _error;

  bool get _timeBased => widget.timeUnit != null;

  @override
  void initState() {
    super.initState();
    final currentValue = _timeBased
        ? timeInputFromSeconds(
            widget.currentPerformance?.seconds,
            widget.timeUnit,
          )
        : widget.currentPerformance?.reps;
    final weight = widget.currentPerformance?.weightKg ?? widget.previousWeight;
    _valueController = TextEditingController(
      text: currentValue?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: weight == null
          ? ''
          : weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _weightController.dispose();
    widget.onDisposed();
    super.dispose();
  }

  void _completeWithoutTracking() {
    Navigator.of(
      context,
    ).pop((reps: null, seconds: null, weight: null, skipped: true));
  }

  void _save() {
    final l10n = widget.l10n;
    final value = int.tryParse(_valueController.text.trim());
    if (widget.repsRequired && (value == null || value < 1)) {
      setState(
        () => _error = _timeBased
            ? l10n.setPerformanceSecondsError
            : l10n.setPerformanceRepsError,
      );
      return;
    }
    if (value != null && value < 1) {
      setState(
        () => _error = _timeBased
            ? l10n.setPerformanceSecondsError
            : l10n.setPerformanceRepsError,
      );
      return;
    }

    final reps = _timeBased ? null : value;
    final seconds = _timeBased
        ? secondsFromTimeInput(value, widget.timeUnit)
        : null;
    final weightText = _weightController.text.trim();
    final weight = weightText.isEmpty
        ? null
        : double.tryParse(weightText.replaceAll(',', '.'));
    if (weight != null && weight < 0) {
      setState(() => _error = l10n.setPerformanceWeightError);
      return;
    }
    if (reps == null && seconds == null && weight == null) {
      setState(() => _error = l10n.setPerformanceDataError);
      return;
    }

    Navigator.of(
      context,
    ).pop((reps: reps, seconds: seconds, weight: weight, skipped: false));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = widget.l10n;
    final currentLabel = widget.currentPerformance == null
        ? null
        : formatSetPerformance(widget.currentPerformance!);
    final previousLabel = widget.previousPerformance == null
        ? null
        : formatSetPerformance(widget.previousPerformance!);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.setPerformanceTitle(widget.setNumber),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.setPerformancePrescription(widget.prescribedReps),
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
              ),
              if (currentLabel != null && currentLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Hoy: $currentLabel',
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ],
              if (previousLabel != null && previousLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.setPerformancePrevious(previousLabel),
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: palette.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  labelText: _timeBased
                      ? widget.timeUnit == TimePerformanceUnit.minutes
                            ? 'Minutos'
                            : l10n.setPerformanceSeconds
                      : l10n.setPerformanceReps,
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: palette.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  labelText: l10n.setPerformanceWeightOptional,
                  hintStyle: TextStyle(color: palette.textDisabled),
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  if (!widget.repsRequired) ...[
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _completeWithoutTracking,
                        child: Text(
                          l10n.completeWithoutTracking,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackActions =
                          constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3;
                      final cancelButton = OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel, maxLines: 1, softWrap: false),
                      );
                      final saveButton = ElevatedButton(
                        onPressed: _save,
                        child: Text(
                          l10n.weightInputSave,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      );

                      if (stackActions) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            cancelButton,
                            const SizedBox(height: 8),
                            saveButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: cancelButton),
                          const SizedBox(width: 12),
                          Expanded(child: saveButton),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
