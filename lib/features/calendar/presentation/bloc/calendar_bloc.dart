import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_week_summary_usecase.dart';

part 'calendar_event.dart';
part 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final GetMonthCalendarUseCase _getMonthCalendarUseCase;
  final GetWeekSummaryUseCase _getWeekSummaryUseCase;

  CalendarBloc({
    required GetMonthCalendarUseCase getMonthCalendarUseCase,
    required GetWeekSummaryUseCase getWeekSummaryUseCase,
  }) : _getMonthCalendarUseCase = getMonthCalendarUseCase,
       _getWeekSummaryUseCase = getWeekSummaryUseCase,
       super(const CalendarInitial()) {
    on<CalendarMonthLoadRequested>(_onMonthLoadRequested);
    on<CalendarDaySelected>(_onDaySelected);
  }

  Future<void> _onMonthLoadRequested(
    CalendarMonthLoadRequested event,
    Emitter<CalendarState> emit,
  ) async {
    emit(const CalendarLoading());
    try {
      final days = await _getMonthCalendarUseCase(event.year, event.month);

      final selectedDate =
          event.selectedDate ?? DateTime(event.year, event.month);
      final weekStart = _getWeekStart(selectedDate);
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);

      WeekSummaryEntity? weekSummary;
      try {
        weekSummary = await _getWeekSummaryUseCase(weekStartStr);
      } catch (_) {
        // Week summary is optional — don't fail the whole load
      }

      emit(
        CalendarLoaded(
          days: days,
          weekSummary: weekSummary,
          selectedDate: selectedDate,
          year: event.year,
          month: event.month,
        ),
      );
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onDaySelected(
    CalendarDaySelected event,
    Emitter<CalendarState> emit,
  ) async {
    final current = state;
    if (current is! CalendarLoaded) return;

    final weekStart = _getWeekStart(event.date);
    final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);

    WeekSummaryEntity? weekSummary = current.weekSummary;
    try {
      weekSummary = await _getWeekSummaryUseCase(weekStartStr);
    } catch (_) {}

    emit(
      CalendarLoaded(
        days: current.days,
        weekSummary: weekSummary,
        selectedDate: event.date,
        year: current.year,
        month: current.month,
      ),
    );
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday; // Monday = 1
    return date.subtract(Duration(days: weekday - 1));
  }
}
