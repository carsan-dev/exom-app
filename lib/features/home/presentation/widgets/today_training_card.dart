import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/utils/training_type_utils.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';

class TodayTrainingCard extends StatelessWidget {
  const TodayTrainingCard({super.key, required this.summary});

  final HomeSummaryEntity summary;

  Color _typeColor(BuildContext context, String? type) {
    return trainingTypeColor(context, type);
  }

  String _typeLabel(BuildContext context, String? type) {
    return trainingTypeLabel(context, type);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final color = _typeColor(context, summary.trainingType);

    return Semantics(
      label: '${l10n.todaysTrainingTitle}: ${summary.trainingName ?? l10n.trainingUntitledLabel}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: GlassDecoration.accentCard(color),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.12), Colors.transparent],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.fitness_center, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.todaysTrainingTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.trainingName ?? l10n.trainingUntitledLabel,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _typeLabel(context, summary.trainingType),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.timer_outlined,
                  label: '${summary.trainingDurationMin ?? '--'} min',
                  color: semantic.info,
                ),
                const SizedBox(width: 12),
                if (summary.trainingCompleted)
                  _StatChip(
                    icon: Icons.check_circle_outline,
                    label: l10n.completed,
                    color: semantic.success,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.progress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      summary.totalExercises > 0
                          ? '${summary.exercisesCompleted}/${summary.totalExercises} ${l10n.exercises}'
                          : summary.trainingCompleted
                          ? '100%'
                          : '0%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: summary.totalExercises > 0
                          ? summary.exercisesCompleted / summary.totalExercises
                          : (summary.trainingCompleted ? 1 : 0),
                      backgroundColor: palette.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: summary.trainingId != null
                    ? () async {
                        HapticFeedback.selectionClick();
                        await context.push('/trainings/${summary.trainingId}');
                        if (context.mounted) {
                          context.read<HomeBloc>().add(
                            const HomeLoadRequested(),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  summary.trainingCompleted
                      ? l10n.viewTrainingButton
                      : summary.exercisesCompleted > 0
                      ? l10n.continueTrainingButton
                      : l10n.startTrainingButton,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: palette.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
