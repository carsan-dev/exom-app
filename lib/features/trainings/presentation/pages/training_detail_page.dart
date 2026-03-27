import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_timer_overlay.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/navigation/app_router.dart';

class TrainingDetailPage extends StatelessWidget {
  final String trainingId;
  final String? selectedDate;

  const TrainingDetailPage({
    super.key,
    required this.trainingId,
    this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<TrainingBloc>()
            ..add(TrainingDetailLoadRequested(trainingId, date: selectedDate)),
      child: const _TrainingDetailView(),
    );
  }
}

class _TrainingDetailView extends StatelessWidget {
  const _TrainingDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingBloc, TrainingState>(
      builder: (context, state) {
        if (state is TrainingLoading || state is TrainingInitial) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
            ),
            body: const ShimmerList(count: 6, itemHeight: 100),
          );
        }
        if (state is TrainingError) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              title: const Text('Error'),
            ),
            body: ErrorWidget2(message: state.message, onRetry: null),
          );
        }
        if (state is TrainingDetailLoaded) {
          return _DetailScaffold(state: state);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _DetailScaffold extends StatefulWidget {
  final TrainingDetailLoaded state;

  const _DetailScaffold({required this.state});

  @override
  State<_DetailScaffold> createState() => _DetailScaffoldState();
}

class _DetailScaffoldState extends State<_DetailScaffold> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Color _typeColor(BuildContext context, String type) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;

    switch (type.toUpperCase()) {
      case 'FUERZA':
        return palette.primary;
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

  @override
  Widget build(BuildContext context) {
    final training = widget.state.training;
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context)!;
    final color = _typeColor(context, training.type);
    final completed = widget.state.completedExerciseIds.length;
    final total = training.exercises.length;
    final progress = total > 0 ? completed / total : 0.0;
    final allDone = total > 0 && completed == total;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(training.name),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 160),
            children: [
              // Header card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), palette.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Badge(label: training.type, color: color),
                        _Badge(
                          label: training.level,
                          color: palette.textSecondary,
                        ),
                        if (training.estimatedDurationMin != null)
                          _Badge(
                            label: '${training.estimatedDurationMin} min',
                            icon: Icons.timer_outlined,
                            color: semantic.info,
                          ),
                        if (training.estimatedCalories != null)
                          _Badge(
                            label: '${training.estimatedCalories} kcal',
                            icon: Icons.local_fire_department_outlined,
                            color: semantic.calorie,
                          ),
                      ],
                    ),
                    if (training.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: training.tags
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#$t',
                                  style: TextStyle(
                                    color: palette.textDisabled,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Warmup
              if (training.warmupDescription != null) ...[
                _SectionTitle(
                  title: l10n.warmUp,
                  icon: Icons.whatshot_outlined,
                  color: semantic.warning,
                ),
                _DescriptionCard(text: training.warmupDescription!),
              ],

              // Exercises section
              _SectionTitle(
                title: l10n.exercises,
                icon: Icons.fitness_center,
                color: color,
                trailing: '$total ${l10n.exercises}',
              ),

              ...List.generate(training.exercises.length, (index) {
                final ex = training.exercises[index];
                final nextEx = index + 1 < training.exercises.length
                    ? training.exercises[index + 1].exercise.name
                    : null;
                return _ExerciseCard(
                  trainingExercise: ex,
                  isCompleted: widget.state.completedExerciseIds.contains(
                    ex.exercise.id,
                  ),
                  weightUsed: widget.state.exerciseWeights[ex.exercise.id],
                  nextExerciseName: nextEx,
                  onToggle: (val, {double? weightUsed}) {
                    context.read<TrainingBloc>().add(
                      MarkExerciseCompleted(
                        trainingExerciseId: ex.id,
                        exerciseId: ex.exercise.id,
                        completed: val,
                        weightUsed: weightUsed,
                      ),
                    );
                  },
                );
              }),

              // Cooldown
              if (training.cooldownDescription != null) ...[
                _SectionTitle(
                  title: l10n.cooldown,
                  icon: Icons.ac_unit_outlined,
                  color: semantic.info,
                ),
                _DescriptionCard(text: training.cooldownDescription!),
              ],

              // Quick notes
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _notesController,
                  maxLines: 3,
                  style: TextStyle(color: palette.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: l10n.addQuickNoteOptional,
                    hintStyle: TextStyle(color: palette.textDisabled),
                    prefixIcon: Icon(
                      Icons.edit_note,
                      color: palette.textDisabled,
                    ),
                    filled: true,
                    fillColor: palette.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bottom bar: progress + Completar button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.divider)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completed/$total ${l10n.completedExercisesLabel}',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: palette.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        allDone ? semantic.success : color,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (allDone) {
                          Navigator.of(context).pop(true);
                          return;
                        }

                        context.read<TrainingBloc>().add(
                          CompleteTrainingRequested(
                            notes: _notesController.text.trim().isEmpty
                                ? null
                                : _notesController.text.trim(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: allDone
                            ? semantic.success
                            : palette.primary,
                        foregroundColor: palette.onPrimary,
                      ),
                      icon: Icon(
                        allDone
                            ? Icons.check_circle_outline
                            : Icons.done_outline,
                        size: 18,
                      ),
                      label: Text(
                        allDone
                            ? l10n.workoutCompletedMessage
                            : l10n.completed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? trailing;

  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing!,
              style: TextStyle(color: palette.textDisabled, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final String text;

  const _DescriptionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final TrainingExerciseEntity trainingExercise;
  final bool isCompleted;
  final double? weightUsed;
  final String? nextExerciseName;
  final void Function(bool completed, {double? weightUsed}) onToggle;

  const _ExerciseCard({
    required this.trainingExercise,
    required this.isCompleted,
    required this.onToggle,
    this.weightUsed,
    this.nextExerciseName,
  });

  @override
  Widget build(BuildContext context) {
    final ex = trainingExercise.exercise;
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => _showExerciseDetail(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCompleted
              ? semantic.success.withValues(alpha: 0.08)
              : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? semantic.success.withValues(alpha: 0.35)
                : palette.divider,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail or placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ex.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: ex.thumbnailUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ExercisePlaceholder(),
                      errorWidget: (_, __, ___) => _ExercisePlaceholder(),
                    )
                  : _ExercisePlaceholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${trainingExercise.order}.',
                        style: TextStyle(
                          color: palette.textDisabled,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ex.name,
                          style: TextStyle(
                            color: isCompleted
                                ? semantic.success
                                : palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: semantic.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (ex.muscleGroups.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      ex.muscleGroups.join(', '),
                      style: TextStyle(
                        color: palette.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniStat(
                        icon: Icons.repeat,
                        label:
                            '${trainingExercise.sets} x ${trainingExercise.repsOrDuration}',
                      ),
                      const SizedBox(width: 12),
                      _MiniStat(
                        icon: Icons.timer_outlined,
                        label:
                            '${trainingExercise.restSeconds}s ${l10n.rest}',
                      ),
                      if (weightUsed != null) ...[
                        const SizedBox(width: 12),
                        _MiniStat(
                          icon: Icons.fitness_center,
                          label: l10n.weightBadgeLabel(
                              weightUsed!.toStringAsFixed(
                                  weightUsed! % 1 == 0 ? 0 : 1)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Icon(Icons.info_outline, color: palette.textDisabled, size: 16),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    if (!isCompleted) {
                      final weight = await _showWeightSheet(context, l10n);
                      if (!context.mounted) return;
                      onToggle(true, weightUsed: weight);
                      if (nextExerciseName != null) {
                        await RestTimerOverlay.show(
                          context,
                          restSeconds: trainingExercise.restSeconds,
                          nextExerciseName: nextExerciseName,
                        );
                      }
                    } else {
                      onToggle(false);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? semantic.success
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? semantic.success
                            : palette.textDisabled,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<double?> _showWeightSheet(
      BuildContext context, AppLocalizations l10n) async {
    final palette = context.exomPalette;
    final controller = TextEditingController();
    double? result;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                        final val = double.tryParse(
                          controller.text.trim().replaceAll(',', '.'),
                        );
                        result = val;
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

  void _showExerciseDetail(BuildContext context) {
    final ex = trainingExercise.exercise;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.exomPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => _ExerciseDetailSheet(
          exercise: ex,
          trainingExercise: trainingExercise,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _ExercisePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Container(
      width: 60,
      height: 60,
      color: palette.surfaceVariant,
      child: Icon(Icons.fitness_center, color: palette.textDisabled, size: 24),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: palette.textDisabled, size: 12),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(color: palette.textDisabled, fontSize: 11),
        ),
      ],
    );
  }
}

class _ExerciseDetailSheet extends StatelessWidget {
  final ExerciseEntity exercise;
  final TrainingExerciseEntity trainingExercise;
  final ScrollController scrollController;

  const _ExerciseDetailSheet({
    required this.exercise,
    required this.trainingExercise,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: palette.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Video player placeholder
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: palette.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (exercise.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: exercise.thumbnailUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      Icons.fitness_center,
                      color: palette.textDisabled,
                      size: 48,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.fitness_center,
                  color: palette.textDisabled,
                  size: 48,
                ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          exercise.name,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (exercise.muscleGroups.isNotEmpty)
          Text(
            exercise.muscleGroups.join(' · '),
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),

        const SizedBox(height: 16),
        // Sets/reps/rest row
        Row(
          children: [
            _SheetStat(
              label: l10n.sets,
              value: '${trainingExercise.sets}',
              icon: Icons.repeat,
            ),
            const SizedBox(width: 12),
            _SheetStat(
              label: l10n.repsOrTime,
              value: trainingExercise.repsOrDuration,
              icon: Icons.bolt,
            ),
            const SizedBox(width: 12),
            _SheetStat(
              label: l10n.restLabel,
              value: '${trainingExercise.restSeconds}s',
              icon: Icons.timer_outlined,
            ),
          ],
        ),

        if (exercise.explanationText != null) ...[
          const SizedBox(height: 20),
          _DetailSection(
            title: l10n.description,
            text: exercise.explanationText!,
          ),
        ],
        if (exercise.techniqueText != null) ...[
          const SizedBox(height: 16),
          _DetailSection(
            title: l10n.technique,
            text: exercise.techniqueText!,
          ),
        ],
        if (exercise.commonErrorsText != null) ...[
          const SizedBox(height: 16),
          _DetailSection(
            title: l10n.commonMistakes,
            text: exercise.commonErrorsText!,
            titleColor: semantic.warning,
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.feedback, extra: <String, String?>{
                'exerciseId': exercise.id,
                'exerciseName': exercise.name,
              });
            },
            icon: const Icon(Icons.feedback_outlined, size: 18),
            label: Text(AppLocalizations.of(context)!.feedbackSendFromExercise),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SheetStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SheetStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: palette.primary, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: palette.textDisabled, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String text;
  final Color? titleColor;

  const _DetailSection({
    required this.title,
    required this.text,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor ?? palette.primary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
