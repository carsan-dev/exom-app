import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_week_summary_usecase.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_challenges_usecase.dart';

part 'calendar_event.dart';
part 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final GetMonthCalendarUseCase _getMonthCalendarUseCase;
  final GetWeekSummaryUseCase _getWeekSummaryUseCase;
  final GetMyChallengesUseCase _getMyChallengesUseCase;

  CalendarBloc({
    required GetMonthCalendarUseCase getMonthCalendarUseCase,
    required GetWeekSummaryUseCase getWeekSummaryUseCase,
    required GetMyChallengesUseCase getMyChallengesUseCase,
  }) : _getMonthCalendarUseCase = getMonthCalendarUseCase,
       _getWeekSummaryUseCase = getWeekSummaryUseCase,
       _getMyChallengesUseCase = getMyChallengesUseCase,
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
      final selectedDate =
          event.selectedDate ?? DateTime(event.year, event.month);
      final weekStart = _getWeekStart(selectedDate);
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);

      final results = await Future.wait<dynamic>([
        _getMonthCalendarUseCase(event.year, event.month),
        _loadWeekSummary(weekStartStr),
        _loadChallenges(),
      ]);

      final days = results[0] as List<CalendarDayEntity>;
      final weekSummary = results[1] as WeekSummaryEntity?;
      final challenges = results[2] as List<ChallengeEntity>;

      emit(
        CalendarLoaded(
          days: days,
          weekSummary: weekSummary,
          challenges: challenges,
          selectedDate: selectedDate,
          year: event.year,
          month: event.month,
        ),
      );
    } catch (error) {
      final apiException = ApiException.maybeFrom(error);
      emit(
        CalendarError(
          message: apiException?.message ?? error.toString(),
          apiException: apiException,
        ),
      );
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
        challenges: current.challenges,
        selectedDate: event.date,
        year: current.year,
        month: current.month,
      ),
    );
  }

  Future<WeekSummaryEntity?> _loadWeekSummary(String weekStartStr) async {
    try {
      return await _getWeekSummaryUseCase(weekStartStr);
    } catch (_) {
      // Week summary is optional — don't fail the whole load.
      return null;
    }
  }

  Future<List<ChallengeEntity>> _loadChallenges() async {
    try {
      return await _getMyChallengesUseCase();
    } catch (_) {
      // Challenge markers are additive — keep the calendar usable.
      return const [];
    }
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday; // Monday = 1
    return date.subtract(Duration(days: weekday - 1));
  }
}
