import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/navigation/page_aware_bottom_sheet.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_video_preview.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_timer_inline.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class ActiveExercisePageArgs {
  final TrainingBloc trainingBloc;
  final TrainingExerciseEntity trainingExercise;
  final String trainingName;
  final String trainingType;
  final String trainingLevel;
  final double? initialWeightKg;

  const ActiveExercisePageArgs({
    required this.trainingBloc,
    required this.trainingExercise,
    required this.trainingName,
    required this.trainingType,
    required this.trainingLevel,
    this.initialWeightKg,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Color _typeColor(BuildContext context, String type) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;

    switch (type.toUpperCase()) {
      case 'FUERZA':
        return context.trainingAccent;
      case 'CARDIO':
        return semantic.info;
      case 'HIIT':
        return semantic.accent;
      case 'FLEXIBILIDAD':
        return semantic.warning;
      default:
        return palette.textDisabled;
    }
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
        context.pop();
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
          l10n.activeExerciseCloseMessage(
            state.completedSets,
            state.totalSets,
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
    final weight = await _showWeightSheet(
      context,
      l10n,
      previousWeight: state.weightKg,
    );
    if (!mounted) return;

    context.read<ActiveExerciseBloc>().add(CompleteSet(weightKg: weight));
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

  Future<void> _openInfoSheet(ActiveExerciseState state) async {
    await showPageAwareModalBottomSheet<void>(
      context: context,
      backgroundColor: context.exomPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.38,
        maxChildSize: 0.9,
        builder: (_, scrollController) => _ExerciseInfoSheet(
          scrollController: scrollController,
          exercise: widget.args.trainingExercise.exercise,
          trainingLevel: widget.args.trainingLevel,
          trainingExercise: widget.args.trainingExercise,
          weightKg: state.weightKg,
          trainingType: widget.args.trainingType,
        ),
      ),
    );
  }

  String _formatWeight(double weight) {
    return weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exercise = widget.args.trainingExercise.exercise;
    final typeColor = _typeColor(context, widget.args.trainingType);

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }

        if (!_handledCompletion && state.isDone) {
          _handledCompletion = true;
          context.read<TrainingBloc>().add(
            MarkExerciseCompleted(
              trainingExerciseId: widget.args.trainingExercise.id,
              exerciseId: exercise.id,
              completed: true,
              weightUsed: state.weightKg,
            ),
          );
          context.pop();
        }
      },
      child: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
        builder: (context, state) {
          final palette = context.exomPalette;
          final semantic = context.exomSemantic;
          final prescriptionLabel = state.weightKg == null
              ? state.repsOrDuration
              : '${state.repsOrDuration} x ${_formatWeight(state.weightKg!)} kg';

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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        Row(
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
                                    exercise.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _CircleIconButton(
                              icon: Icons.info_outline_rounded,
                              onTap: () => _openInfoSheet(state),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: ExerciseVideoPreview(
                                  title: exercise.name,
                                  videoUrl: exercise.videoUrl,
                                  thumbnailUrl: exercise.thumbnailUrl,
                                  onTap: _openVideoPlayer,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                flex: 4,
                                child: Container(
                                  width: double.infinity,
                                  decoration: GlassDecoration.card(
                                    borderRadius: 28,
                                  ),
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              borderRadius:
                                                  BorderRadius.circular(999),
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
                                      const Spacer(),
                                      Text(
                                        l10n.exerciseSetProgress(
                                          state.currentSet,
                                          state.totalSets,
                                        ),
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        prescriptionLabel,
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      LinearProgressIndicator(
                                        value: state.totalSets == 0
                                            ? 0
                                            : state.completedSets /
                                                  state.totalSets,
                                        minHeight: 8,
                                        backgroundColor: palette.surfaceVariant,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              state.isDone
                                                  ? semantic.success
                                                  : typeColor,
                                            ),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        l10n.exerciseSeriesProgress(
                                          state.completedSets,
                                          state.totalSets,
                                        ),
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                flex: 4,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: switch (state.status) {
                                    ActiveExerciseStatus.executing => Container(
                                      key: const ValueKey('executing'),
                                      width: double.infinity,
                                      decoration: GlassDecoration.card(
                                        borderRadius: 28,
                                      ),
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (state.weightKg != null) ...[
                                            Text(
                                              l10n.activeExerciseLastWeight(
                                                _formatWeight(state.weightKg!),
                                              ),
                                              style: TextStyle(
                                                color: palette.textSecondary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                          const Spacer(),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () => _onCompleteSetPressed(
                                                state,
                                                l10n,
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: state
                                                            .currentSet ==
                                                        state.totalSets
                                                    ? semantic.success
                                                    : typeColor,
                                                foregroundColor:
                                                    palette.onPrimary,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 18,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              child: Text(
                                                l10n.completeSetButton
                                                    .toUpperCase(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ActiveExerciseStatus.resting => RestTimerInline(
                                      key: ValueKey(
                                        state.restEndsAt?.millisecondsSinceEpoch,
                                      ),
                                      totalSeconds: state.restSeconds,
                                      restEndsAt: state.restEndsAt!,
                                      subtitle: l10n.exerciseSetProgress(
                                        state.currentSet,
                                        state.totalSets,
                                      ),
                                      onSkip: () => context
                                          .read<ActiveExerciseBloc>()
                                          .add(const SkipRest()),
                                      onFinished: () => context
                                          .read<ActiveExerciseBloc>()
                                          .add(const SkipRest()),
                                    ),
                                    ActiveExerciseStatus.done => Container(
                                      key: const ValueKey('done'),
                                      width: double.infinity,
                                      decoration: GlassDecoration.card(
                                        borderRadius: 28,
                                      ),
                                      alignment: Alignment.center,
                                      child: const LoadingWidget(),
                                    ),
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

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

class _ExerciseInfoSheet extends StatelessWidget {
  final ScrollController scrollController;
  final ExerciseEntity exercise;
  final TrainingExerciseEntity trainingExercise;
  final String trainingLevel;
  final String trainingType;
  final double? weightKg;

  const _ExerciseInfoSheet({
    required this.scrollController,
    required this.exercise,
    required this.trainingExercise,
    required this.trainingLevel,
    required this.trainingType,
    this.weightKg,
  });

  Color _typeColor(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;

    switch (trainingType.toUpperCase()) {
      case 'FUERZA':
        return context.trainingAccent;
      case 'CARDIO':
        return semantic.info;
      case 'HIIT':
        return semantic.accent;
      case 'FLEXIBILIDAD':
        return semantic.warning;
      default:
        return palette.textDisabled;
    }
  }

  bool _hasContent(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final typeColor = _typeColor(context);
    final weightLabel = weightKg == null
        ? null
        : l10n.activeExerciseLastWeight(
            weightKg!.toStringAsFixed(weightKg! % 1 == 0 ? 0 : 1),
          );

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      children: [
        Center(
          child: Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: palette.divider,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          exercise.name,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              label: l10n.exerciseMetadata(
                trainingExercise.sets,
                trainingExercise.repsOrDuration,
                trainingExercise.restSeconds,
              ),
              color: typeColor,
            ),
            _InfoChip(label: trainingLevel, color: palette.textSecondary),
            if (weightLabel != null)
              _InfoChip(label: weightLabel, color: palette.textSecondary),
          ],
        ),
        if (_hasContent(exercise.techniqueText)) ...[
          const SizedBox(height: 24),
          _InfoSection(
            title: l10n.technique,
            text: exercise.techniqueText!,
          ),
        ],
        if (_hasContent(exercise.commonErrorsText)) ...[
          const SizedBox(height: 18),
          _InfoSection(
            title: l10n.commonMistakes,
            text: exercise.commonErrorsText!,
          ),
        ],
        if (_hasContent(exercise.explanationText)) ...[
          const SizedBox(height: 18),
          _InfoSection(
            title: l10n.explanation,
            text: exercise.explanationText!,
          ),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final String text;

  const _InfoSection({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
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

Future<double?> _showWeightSheet(
  BuildContext context,
  AppLocalizations l10n, {
  double? previousWeight,
}) async {
  final palette = context.exomPalette;
  final controller = TextEditingController(
    text: previousWeight != null
        ? previousWeight.toStringAsFixed(previousWeight % 1 == 0 ? 0 : 1)
        : '',
  );
  double? result;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
              l10n.weightInputTitle,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              style: TextStyle(color: palette.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: l10n.weightInputHint,
                hintStyle: TextStyle(color: palette.textDisabled),
                suffixText: 'kg',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.weightInputSkip),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final value = double.tryParse(
                        controller.text.trim().replaceAll(',', '.'),
                      );
                      result = value;
                      Navigator.of(ctx).pop();
                    },
                    child: Text(l10n.weightInputSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return result;
}
