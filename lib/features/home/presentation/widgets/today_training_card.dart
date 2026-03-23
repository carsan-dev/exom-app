import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';

class TodayTrainingCard extends StatelessWidget {
  final HomeSummaryEntity summary;

  const TodayTrainingCard({super.key, required this.summary});

  Color _typeColor(String? type) {
    switch (type?.toUpperCase()) {
      case 'FUERZA':
        return AppColors.primary;
      case 'CARDIO':
        return AppColors.secondary;
      case 'HIIT':
        return AppColors.accent;
      case 'FLEXIBILIDAD':
        return AppColors.warning;
      default:
        return AppColors.textDisabled;
    }
  }

  String _typeLabel(String? type) {
    switch (type?.toUpperCase()) {
      case 'FUERZA':
        return 'Fuerza';
      case 'CARDIO':
        return 'Cardio';
      case 'HIIT':
        return 'HIIT';
      case 'FLEXIBILIDAD':
        return 'Flexibilidad';
      default:
        return type ?? 'Entrenamiento';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(summary.trainingType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.15), AppColors.card],
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
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.fitness_center, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entrenamiento de hoy',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.trainingName ?? 'Sin nombre',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
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
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _typeLabel(summary.trainingType),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.timer_outlined,
                  label: '${summary.trainingDurationMin ?? '--'} min',
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 12),
                if (summary.trainingCompleted)
                  _StatChip(
                    icon: Icons.check_circle_outline,
                    label: 'Completado',
                    color: AppColors.success,
                  ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progreso',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      summary.totalExercises > 0
                          ? '${summary.exercisesCompleted}/${summary.totalExercises} ejercicios'
                          : summary.trainingCompleted
                          ? '100%'
                          : '0%',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.totalExercises > 0
                        ? summary.exercisesCompleted / summary.totalExercises
                        : (summary.trainingCompleted ? 1.0 : 0.0),
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: summary.trainingId != null
                    ? () async {
                        await context.push('/trainings/${summary.trainingId}');
                        if (context.mounted) {
                          context.read<HomeBloc>().add(
                            const HomeLoadRequested(),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Ver entrenamiento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: AppColors.textOnPrimary,
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
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

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
