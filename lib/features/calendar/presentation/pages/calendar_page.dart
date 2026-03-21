import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return BlocProvider(
      create: (_) => GetIt.I<CalendarBloc>()
        ..add(CalendarMonthLoadRequested(year: now.year, month: now.month)),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Calendario'),
          backgroundColor: AppColors.background,
        ),
        body: BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, state) {
            if (state is CalendarLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (state is CalendarError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Error al cargar el calendario',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        final now = DateTime.now();
                        context.read<CalendarBloc>().add(
                          CalendarMonthLoadRequested(year: now.year, month: now.month),
                        );
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            if (state is CalendarLoaded) {
              return _CalendarContent(state: state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _CalendarContent extends StatelessWidget {
  final CalendarLoaded state;

  const _CalendarContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final dayMap = <DateTime, CalendarDayEntity>{};
    for (final day in state.days) {
      final key = DateTime(day.date.year, day.date.month, day.date.day);
      dayMap[key] = day;
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _buildCalendar(context, dayMap),
        if (state.selectedDate != DateTime(0))
          _buildSelectedDayInfo(dayMap),
        if (state.weekSummary != null)
          _WeekSummaryCard(summary: state.weekSummary!),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, Map<DateTime, CalendarDayEntity> dayMap) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: TableCalendar<CalendarDayEntity>(
        firstDay: DateTime(2024),
        lastDay: DateTime(2030),
        focusedDay: DateTime(state.year, state.month),
        selectedDayPredicate: (day) => isSameDay(day, state.selectedDate),
        startingDayOfWeek: StartingDayOfWeek.monday,
        locale: 'es_ES',
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppColors.textDisabled, fontSize: 12),
          weekendStyle: TextStyle(color: AppColors.textDisabled, fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
          weekendTextStyle: const TextStyle(color: AppColors.textPrimary),
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          cellMargin: const EdgeInsets.all(4),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            final key = DateTime(date.year, date.month, date.day);
            final day = dayMap[key];
            if (day == null) return null;
            return _buildMarkers(day);
          },
        ),
        onDaySelected: (selectedDay, focusedDay) {
          context.read<CalendarBloc>().add(CalendarDaySelected(selectedDay));
        },
        onPageChanged: (focusedDay) {
          context.read<CalendarBloc>().add(
            CalendarMonthLoadRequested(
              year: focusedDay.year,
              month: focusedDay.month,
              selectedDate: state.selectedDate,
            ),
          );
        },
      ),
    );
  }

  Widget? _buildMarkers(CalendarDayEntity day) {
    if (day.isRestDay) {
      return Positioned(
        bottom: 4,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.textDisabled,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    final dots = <Widget>[];

    if (day.hasTraining) {
      dots.add(Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: day.trainingCompleted ? AppColors.success : AppColors.warning,
          shape: BoxShape.circle,
        ),
      ));
    }

    if (day.hasDiet) {
      dots.add(Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: day.dietCompleted ? AppColors.success : AppColors.warning,
          shape: BoxShape.circle,
        ),
      ));
    }

    if (dots.isEmpty) return null;

    return Positioned(
      bottom: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: dots.map((dot) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: dot,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedDayInfo(Map<DateTime, CalendarDayEntity> dayMap) {
    final key = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );
    final day = dayMap[key];

    if (day == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Text(
          'Sin actividad asignada para este día',
          style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (day.isRestDay)
            _infoRow(Icons.hotel, 'Día de descanso', AppColors.textDisabled)
          else ...[
            if (day.hasTraining)
              _infoRow(
                day.trainingCompleted ? Icons.check_circle : Icons.fitness_center,
                day.trainingCompleted ? 'Entrenamiento completado' : 'Entrenamiento pendiente',
                day.trainingCompleted ? AppColors.success : AppColors.warning,
              ),
            if (day.hasDiet)
              Padding(
                padding: EdgeInsets.only(top: day.hasTraining ? 8 : 0),
                child: _infoRow(
                  day.dietCompleted ? Icons.check_circle : Icons.restaurant,
                  day.dietCompleted ? 'Dieta completada' : 'Dieta pendiente',
                  day.dietCompleted ? AppColors.success : AppColors.warning,
                ),
              ),
            if (!day.hasTraining && !day.hasDiet)
              _infoRow(Icons.event_busy, 'Sin actividad asignada', AppColors.textDisabled),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final WeekSummaryEntity summary;

  const _WeekSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen semanal',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _progressRow(
            icon: Icons.fitness_center,
            label: 'Entrenamientos',
            completed: summary.trainingsCompleted,
            total: summary.trainingsAssigned,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _progressRow(
            icon: Icons.restaurant,
            label: 'Comidas',
            completed: summary.mealsCompleted,
            total: summary.totalMeals,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _progressRow({
    required IconData icon,
    required String label,
    required int completed,
    required int total,
    required Color color,
  }) {
    final progress = total > 0 ? completed / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const Spacer(),
            Text(
              '$completed / $total',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
