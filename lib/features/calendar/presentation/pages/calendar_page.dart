import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return BlocProvider(
      create: (_) => GetIt.I<CalendarBloc>()
        ..add(CalendarMonthLoadRequested(year: now.year, month: now.month)),
      child: const _CalendarView(),
    );
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  bool _showTrainings = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, state) {
            if (state is CalendarLoading || state is CalendarInitial) {
              return const ShimmerList(count: 3, itemHeight: 200);
            }
            if (state is CalendarError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.textDisabled, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Error al cargar el calendario',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        final now = DateTime.now();
                        context.read<CalendarBloc>().add(
                          CalendarMonthLoadRequested(year: now.year, month: now.month),
                        );
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            if (state is CalendarLoaded) {
              return _buildContent(context, state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CalendarLoaded state) {
    final dayMap = <DateTime, CalendarDayEntity>{};
    for (final day in state.days) {
      final key = DateTime(day.date.year, day.date.month, day.date.day);
      dayMap[key] = day;
    }

    return Column(
      children: [
        // Month header
        _MonthHeader(
          year: state.year,
          month: state.month,
          onPrevious: () => _changeMonth(context, state, -1),
          onNext: () => _changeMonth(context, state, 1),
          onTitleTap: () => _showMonthYearPicker(context, state),
        ),

        // Toggle: Entrenos / Dietas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              _ToggleChip(
                label: 'Entrenos',
                icon: Icons.fitness_center,
                isSelected: _showTrainings,
                onTap: () => setState(() => _showTrainings = true),
              ),
              const SizedBox(width: 10),
              _ToggleChip(
                label: 'Dietas',
                icon: Icons.restaurant_menu,
                isSelected: !_showTrainings,
                onTap: () => setState(() => _showTrainings = false),
              ),
            ],
          ),
        ),

        // Calendar + details
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _buildCalendar(context, state, dayMap),
              _buildWeekProgress(state),
              _buildSelectedDayCard(context, state, dayMap),
            ],
          ),
        ),
      ],
    );
  }

  void _changeMonth(BuildContext context, CalendarLoaded state, int delta) {
    var year = state.year;
    var month = state.month + delta;
    if (month > 12) {
      month = 1;
      year++;
    } else if (month < 1) {
      month = 12;
      year--;
    }
    context.read<CalendarBloc>().add(
      CalendarMonthLoadRequested(year: year, month: month),
    );
  }

  Future<void> _showMonthYearPicker(BuildContext context, CalendarLoaded state) async {
    final bloc = context.read<CalendarBloc>();
    int selectedYear = state.year;
    int selectedMonth = state.month;

    final result = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => _MonthYearPickerDialog(
        initialYear: selectedYear,
        initialMonth: selectedMonth,
      ),
    );

    if (result != null) {
      bloc.add(CalendarMonthLoadRequested(year: result[0], month: result[1]));
    }
  }

  Widget _buildCalendar(
    BuildContext context,
    CalendarLoaded state,
    Map<DateTime, CalendarDayEntity> dayMap,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
        headerVisible: false,
        daysOfWeekHeight: 32,
        rowHeight: 48,
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: AppColors.textDisabled,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: AppColors.textDisabled,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          weekendTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          cellMargin: const EdgeInsets.all(4),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            final key = DateTime(date.year, date.month, date.day);
            final day = dayMap[key];
            if (day == null) return null;
            return _buildMarker(day);
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

  Widget? _buildMarker(CalendarDayEntity day) {
    if (_showTrainings) {
      if (!day.hasTraining && !day.isRestDay) return null;
      if (day.isRestDay) {
        return _markerDot(AppColors.textDisabled);
      }
      return _markerDot(
        day.trainingCompleted ? AppColors.success : AppColors.primary,
      );
    } else {
      if (!day.hasDiet) return null;
      return _markerDot(
        day.dietCompleted ? AppColors.success : AppColors.secondary,
      );
    }
  }

  Widget _markerDot(Color color) {
    return Positioned(
      bottom: 4,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildWeekProgress(CalendarLoaded state) {
    final summary = state.weekSummary;
    if (summary == null) return const SizedBox.shrink();

    final int completed;
    final int total;
    final String label;
    final Color color;

    if (_showTrainings) {
      completed = summary.trainingsCompleted;
      total = summary.trainingsAssigned;
      label = 'entrenos completados esta semana';
      color = AppColors.primary;
    } else {
      completed = summary.mealsCompleted;
      total = summary.totalMeals;
      label = 'comidas completadas esta semana';
      color = AppColors.secondary;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$completed/$total',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayCard(
    BuildContext context,
    CalendarLoaded state,
    Map<DateTime, CalendarDayEntity> dayMap,
  ) {
    if (state.selectedDate == DateTime(0)) return const SizedBox.shrink();

    final key = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );
    final day = dayMap[key];
    final isToday = isSameDay(state.selectedDate, DateTime.now());
    final dateLabel = isToday
        ? 'Hoy'
        : DateFormat('d \'de\' MMMM', 'es').format(state.selectedDate);

    if (day == null) {
      return _emptyDayCard(dateLabel);
    }

    if (day.isRestDay) {
      return _restDayCard(dateLabel);
    }

    if (_showTrainings) {
      return _trainingDayCard(context, day, dateLabel);
    } else {
      return _dietDayCard(context, day, dateLabel);
    }
  }

  Widget _emptyDayCard(String dateLabel) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_busy, color: AppColors.textDisabled, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sin actividad asignada',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _restDayCard(String dateLabel) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.hotel, color: AppColors.textDisabled, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Día de descanso',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingDayCard(BuildContext context, CalendarDayEntity day, String dateLabel) {
    if (!day.hasTraining) return _emptyDayCard(dateLabel);

    final statusColor = day.trainingCompleted ? AppColors.success : AppColors.primary;
    final statusLabel = day.trainingCompleted ? 'Completado' : 'Pendiente';
    final statusIcon = day.trainingCompleted ? Icons.check_circle : Icons.schedule;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.trainingCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.fitness_center, color: statusColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entrenamiento • $dateLabel',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/trainings'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver detalle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dietDayCard(BuildContext context, CalendarDayEntity day, String dateLabel) {
    if (!day.hasDiet) return _emptyDayCard(dateLabel);

    final statusColor = day.dietCompleted ? AppColors.success : AppColors.secondary;
    final statusLabel = day.dietCompleted ? 'Completada' : 'Pendiente';
    final statusIcon = day.dietCompleted ? Icons.check_circle : Icons.schedule;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.dietCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.restaurant_menu, color: statusColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Nutritivo • $dateLabel',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/diets'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver Plan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month Header ──────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final int year;
  final int month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTitleTap;

  const _MonthHeader({
    required this.year,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM', 'es').format(DateTime(year, month));
    final capitalMonth = monthName[0].toUpperCase() + monthName.substring(1);
    final title = '$capitalMonth de $year';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle Chip ───────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderMedium,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Month/Year Picker Dialog ──────────────────────────────────────────────────

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;

  const _MonthYearPickerDialog({
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  late int _month;

  static const _monthLabels = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Month grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final m = index + 1;
                final isSelected = m == _month;
                return GestureDetector(
                  onTap: () => setState(() => _month = m),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _monthLabels[index],
                      style: TextStyle(
                        color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, [_year, _month]),
                child: const Text('Ir al mes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
