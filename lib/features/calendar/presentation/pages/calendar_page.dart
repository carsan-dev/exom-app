import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/l10n/app_localizations.dart';
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
      create: (_) =>
          GetIt.I<CalendarBloc>()
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

  String _apiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        if (state is CalendarLoading || state is CalendarInitial) {
          return const ShimmerList(count: 3, itemHeight: 200);
        }
        if (state is CalendarError) {
          return _buildErrorState(context, state);
        }
        if (state is CalendarLoaded) {
          return _buildContent(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorState(BuildContext context, CalendarError state) {
    void retry() {
      final now = DateTime.now();
      context.read<CalendarBloc>().add(
        CalendarMonthLoadRequested(year: now.year, month: now.month),
      );
    }

    final apiException = state.apiException;
    if (apiException?.isNetworkError == true) {
      return NoConnectionWidget(onRetry: retry);
    }
    if (apiException?.isServerError == true) {
      return ServerErrorWidget(
        errorCode: apiException!.statusCode.toString(),
        onRetry: retry,
      );
    }
    return ErrorWidget2(
      message: apiException != null
          ? localizedApiError(context, apiException)
          : AppLocalizations.of(context).calendarLoadError,
      onRetry: retry,
    );
  }

  Widget _buildContent(BuildContext context, CalendarLoaded state) {
    final l10n = AppLocalizations.of(context);
    final dayMap = <DateTime, CalendarDayEntity>{};
    for (final day in state.days) {
      final key = DateTime(day.date.year, day.date.month, day.date.day);
      dayMap[key] = day;
    }

    final hasActivities = state.days.any(
      (d) => d.hasTraining || d.hasDiet || d.isRestDay,
    );

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
                label: l10n.training,
                icon: Icons.fitness_center,
                isSelected: _showTrainings,
                onTap: () => setState(() => _showTrainings = true),
              ),
              const SizedBox(width: 10),
              _ToggleChip(
                label: l10n.diets,
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
              if (!hasActivities)
                EmptyWidget(
                  message: l10n.noActivitiesThisMonth,
                  subtitle: l10n.noActivitiesThisMonthSubtitle,
                  icon: Icons.event_busy_outlined,
                )
              else ...[
                _buildWeekProgress(context, state),
                _buildSelectedDayCard(context, state, dayMap),
              ],
              _buildChallengesShortcut(context),
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

  Future<void> _showMonthYearPicker(
    BuildContext context,
    CalendarLoaded state,
  ) async {
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
    final palette = context.exomPalette;
    final locale = Localizations.localeOf(context).toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: TableCalendar<CalendarDayEntity>(
        firstDay: DateTime(2024),
        lastDay: DateTime(2030),
        focusedDay: DateTime(state.year, state.month),
        selectedDayPredicate: (day) => isSameDay(day, state.selectedDate),
        startingDayOfWeek: StartingDayOfWeek.monday,
        locale: locale,
        headerVisible: false,
        daysOfWeekHeight: 32,
        rowHeight: 48,
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: palette.textDisabled,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: palette.textDisabled,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: TextStyle(color: palette.textPrimary, fontSize: 14),
          weekendTextStyle: TextStyle(color: palette.textPrimary, fontSize: 14),
          todayDecoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: palette.primary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          selectedDecoration: BoxDecoration(
            color: palette.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: palette.onPrimary,
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
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    if (_showTrainings) {
      if (!day.hasTraining && !day.isRestDay) return null;
      if (day.isRestDay) {
        return _markerDot(palette.textDisabled);
      }
      return _markerDot(
        day.trainingCompleted ? semantic.success : palette.primary,
      );
    } else {
      if (!day.hasDiet) return null;
      return _markerDot(
        day.dietCompleted ? semantic.success : semantic.calorie,
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

  Widget _buildWeekProgress(BuildContext context, CalendarLoaded state) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final summary = state.weekSummary;
    if (summary == null) return const SizedBox.shrink();

    final int completed;
    final int total;
    final String label;
    final Color color;

    if (_showTrainings) {
      completed = summary.trainingsCompleted;
      total = summary.trainingsAssigned;
      label = l10n.trainingsCompletedThisWeek;
      color = palette.primary;
    } else {
      completed = summary.mealsCompleted;
      total = summary.totalMeals;
      label = l10n.mealsCompletedThisWeek;
      color = semantic.calorie;
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
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
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
    final locale = Localizations.localeOf(context).toString();
    final l10n = AppLocalizations.of(context);
    final String dateLabel;
    if (isToday) {
      dateLabel = l10n.todayLabel;
    } else {
      final formattedDate = DateFormat.MMMMd(locale).format(state.selectedDate);
      dateLabel = toBeginningOfSentenceCase(formattedDate) ?? formattedDate;
    }

    if (day == null) {
      return _emptyDayCard(context, dateLabel);
    }

    if (day.isRestDay) {
      return _restDayCard(context, dateLabel);
    }

    if (_showTrainings) {
      return _trainingDayCard(context, day, dateLabel);
    } else {
      return _dietDayCard(context, day, dateLabel);
    }
  }

  Widget _emptyDayCard(BuildContext context, String dateLabel) {
    final palette = context.exomPalette;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.event_busy,
              color: palette.textDisabled,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.noActivityAssigned,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _restDayCard(BuildContext context, String dateLabel) {
    final palette = context.exomPalette;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.hotel, color: palette.textDisabled, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.restDayTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingDayCard(
    BuildContext context,
    CalendarDayEntity day,
    String dateLabel,
  ) {
    if (!day.hasTraining) return _emptyDayCard(context, dateLabel);

    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);

    final statusColor = day.trainingCompleted
        ? semantic.success
        : palette.primary;
    final statusLabel = day.trainingCompleted ? l10n.completed : l10n.pending;
    final statusIcon = day.trainingCompleted
        ? Icons.check_circle
        : Icons.schedule;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider),
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
                  color: palette.primarySoft,
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
                      '${l10n.training} • $dateLabel',
                      style: TextStyle(
                        color: palette.textPrimary,
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
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
              onPressed: () =>
                  context.go('/trainings?date=${_apiDate(day.date)}'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(l10n.openDetail),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.primary,
                side: BorderSide(color: palette.primary),
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

  Widget _buildChallengesShortcut(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: OutlinedButton.icon(
        onPressed: () => context.go('/challenges'),
        icon: Icon(Icons.emoji_events_outlined, size: 18, color: palette.primary),
        label: Text(l10n.challengesMenuItem),
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.primary.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _dietDayCard(
    BuildContext context,
    CalendarDayEntity day,
    String dateLabel,
  ) {
    if (!day.hasDiet) return _emptyDayCard(context, dateLabel);

    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);

    final statusColor = day.dietCompleted ? semantic.success : semantic.calorie;
    final statusLabel = day.dietCompleted
        ? l10n.completedFeminine
        : l10n.pending;
    final statusIcon = day.dietCompleted ? Icons.check_circle : Icons.schedule;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider),
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
                  color: semantic.calorie.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.nutritionPlanDefault} • $dateLabel',
                      style: TextStyle(
                        color: palette.textPrimary,
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
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
              onPressed: () => context.go('/diets?date=${_apiDate(day.date)}'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(l10n.openPlan),
              style: OutlinedButton.styleFrom(
                foregroundColor: semantic.calorie,
                side: BorderSide(color: semantic.calorie),
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
    final palette = context.exomPalette;
    final locale = Localizations.localeOf(context).toString();
    final formattedTitle = DateFormat.yMMMM(
      locale,
    ).format(DateTime(year, month));
    final title = toBeginningOfSentenceCase(formattedTitle);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: Icon(Icons.chevron_left, color: palette.textSecondary),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: palette.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(Icons.chevron_right, color: palette.textSecondary),
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
    final palette = context.exomPalette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? palette.primary : palette.borderSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? palette.onPrimary : palette.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? palette.onPrimary : palette.textSecondary,
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

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: palette.surface,
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
                  icon: Icon(Icons.chevron_left, color: palette.textSecondary),
                ),
                Text(
                  '$_year',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: Icon(Icons.chevron_right, color: palette.textSecondary),
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
                      color: isSelected
                          ? palette.primary
                          : palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _monthLabel(context, m),
                      style: TextStyle(
                        color: isSelected
                            ? palette.onPrimary
                            : palette.textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
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
                child: Text(l10n.goToMonthButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(BuildContext context, int month) {
    final locale = Localizations.localeOf(context).toString();
    final label = DateFormat.MMM(locale).format(DateTime(2000, month));
    return toBeginningOfSentenceCase(label);
  }
}
