part of 'calendar_bloc.dart';

abstract class CalendarState {
  const CalendarState();
}

class CalendarInitial extends CalendarState {
  const CalendarInitial();
}

class CalendarLoading extends CalendarState {
  const CalendarLoading();
}

class CalendarLoaded extends CalendarState {
  final List<CalendarDayEntity> days;
  final WeekSummaryEntity? weekSummary;
  final List<ChallengeEntity> challenges;
  final DateTime selectedDate;
  final int year;
  final int month;

  const CalendarLoaded({
    required this.days,
    this.weekSummary,
    required this.challenges,
    required this.selectedDate,
    required this.year,
    required this.month,
  });
}

class CalendarError extends CalendarState {
  final String message;
  final ApiException? apiException;

  const CalendarError({required this.message, this.apiException});
}
