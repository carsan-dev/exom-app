import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';

class TrainingsPage extends StatelessWidget {
  const TrainingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TrainingBloc>()..add(const TrainingsLoadRequested()),
      child: const _TrainingsView(),
    );
  }
}

class _TrainingsView extends StatelessWidget {
  const _TrainingsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingBloc, TrainingState>(
      builder: (context, state) {
        if (state is TrainingLoading || state is TrainingInitial) {
          return const ShimmerList(count: 5, itemHeight: 120);
        }
        if (state is TrainingError) {
          return ErrorWidget2(
            message: state.message,
            onRetry: () => context.read<TrainingBloc>().add(
              const TrainingsLoadRequested(),
            ),
          );
        }
        if (state is TrainingsLoaded) {
          return _buildContent(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildContent(BuildContext context, TrainingsLoaded state) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async {
        context.read<TrainingBloc>().add(const TrainingsLoadRequested());
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Today's training section
          if (state.todayTraining != null) ...[
            _SectionHeader(title: 'Entrenamiento de hoy'),
            _TodayTrainingBanner(training: state.todayTraining!),
            const SizedBox(height: 8),
          ] else ...[
            _SectionHeader(title: 'Hoy'),
            _NoTrainingToday(),
          ],

          // All trainings
          _SectionHeader(title: 'Todos los entrenamientos'),
          if (state.trainings.isEmpty)
            const EmptyWidget(
              message: 'No hay entrenamientos disponibles',
              subtitle: 'Contacta a tu entrenador para que te asigne un plan',
              icon: Icons.fitness_center_outlined,
            )
          else
            ...state.trainings.map((t) => _TrainingListItem(training: t)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TodayTrainingBanner extends StatelessWidget {
  final TrainingEntity training;

  const _TodayTrainingBanner({required this.training});

  Color _typeColor(String type) {
    switch (type.toUpperCase()) {
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

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(training.type);

    return GestureDetector(
      onTap: () async {
        await context.push('/trainings/${training.id}');
        if (context.mounted) {
          context.read<TrainingBloc>().add(const TrainingsLoadRequested());
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.25), AppColors.card],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          training.type,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        training.level,
                        style: const TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    training.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: AppColors.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${training.estimatedDurationMin ?? '--'} min',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.list_outlined,
                        color: AppColors.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${training.exercises.length} ejercicios',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _NoTrainingToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('😴', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No hay entrenamiento asignado hoy',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Disfruta tu día de descanso',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingListItem extends StatelessWidget {
  final TrainingEntity training;

  const _TrainingListItem({required this.training});

  Color _typeColor(String type) {
    switch (type.toUpperCase()) {
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

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(training.type);
    return GestureDetector(
      onTap: () async {
        await context.push('/trainings/${training.id}');
        if (context.mounted) {
          context.read<TrainingBloc>().add(const TrainingsLoadRequested());
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.fitness_center, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          training.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          training.type,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.timer_outlined,
                        color: AppColors.textDisabled,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${training.estimatedDurationMin ?? '--'} min',
                        style: const TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.list_outlined,
                        color: AppColors.textDisabled,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${training.exercises.length} ej.',
                        style: const TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textDisabled,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
