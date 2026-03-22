import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/features/home/presentation/widgets/today_diet_card.dart';
import 'package:exom_app/features/home/presentation/widgets/week_day_selector.dart';
import 'package:exom_app/features/home/presentation/widgets/stats_row.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeBloc>()..add(const HomeLoadRequested()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) => _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, HomeState state) {
    if (state is HomeLoading || state is HomeInitial) {
      return const ShimmerList(count: 4, itemHeight: 160);
    }

    if (state is HomeError) {
      return ErrorWidget2(
        message: state.message,
        onRetry: () => context.read<HomeBloc>().add(const HomeLoadRequested()),
      );
    }

    if (state is HomeRestDay) {
      return _RestDayBody(summary: state.summary, selectedDate: state.selectedDate);
    }

    if (state is HomeLoaded) {
      return _LoadedBody(summary: state.summary, selectedDate: state.selectedDate);
    }

    return const SizedBox.shrink();
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime selectedDate;

  const _DateHeader({required this.selectedDate});

  String _relativeLabel(DateTime date) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final dateNorm = DateTime(date.year, date.month, date.day);
    final diff = dateNorm.difference(todayNorm).inDays;

    switch (diff) {
      case 0:  return 'Hoy';
      case 1:  return 'Mañana';
      case 2:  return 'Pasado mañana';
      case -1: return 'Ayer';
      case -2: return 'Antes de ayer';
      default:
        if (diff > 0) return 'En $diff días';
        return 'Hace ${diff.abs()} días';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE', 'es').format(selectedDate);
    final dayMonth = DateFormat('d \'de\' MMMM', 'es').format(selectedDate);
    final capitalDay = dayName[0].toUpperCase() + dayName.substring(1);
    final label = _relativeLabel(selectedDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$capitalDay $dayMonth',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.go('/calendar'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  const _LoadedBody({required this.summary, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async {
        context.read<HomeBloc>().add(const HomeLoadRequested());
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 0, bottom: 32),
        children: [
          _DateHeader(selectedDate: selectedDate),
          const SizedBox(height: 12),
          const WeekDaySelector(),
          const SizedBox(height: 20),
          TodayTrainingCard(summary: summary),
          TodayDietCard(summary: summary),
          StatsRow(summary: summary),
        ],
      ),
    );
  }
}

class _RestDayBody extends StatelessWidget {
  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  const _RestDayBody({required this.summary, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async {
        context.read<HomeBloc>().add(const HomeLoadRequested());
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 0, bottom: 32),
        children: [
          _DateHeader(selectedDate: selectedDate),
          const SizedBox(height: 12),
          const WeekDaySelector(),
          const SizedBox(height: 20),
          // Rest day card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.fitness_center,
                      color: AppColors.textDisabled,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Día de descanso',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No tienes entrenamiento asignado para hoy.\nAprovecha para recuperarte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => context.go('/calendar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Ver calendario'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StatsRow(summary: summary),
        ],
      ),
    );
  }
}
