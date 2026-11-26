part of 'home_bloc.dart';

abstract class HomeState {
  const HomeState();
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  /// Set only on the state that repeats the content already on screen after
  /// a reload failed, so a pull-to-refresh can end and report the failure.
  final String? refreshError;

  /// L4b-D4: session marks of the week of [selectedDate]; `null` when the
  /// calendar is unavailable (the strip then looks as before L4b).
  final HomeWeekMarks? weekMarks;
  const HomeLoaded(
    this.summary, {
    required this.selectedDate,
    this.refreshError,
    this.weekMarks,
  });
}

class HomeRestDay extends HomeState {
  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  /// See [HomeLoaded.refreshError].
  final String? refreshError;

  /// See [HomeLoaded.weekMarks].
  final HomeWeekMarks? weekMarks;

  /// L5-D27 (exception EX-Q6): what the calendar says [selectedDate] holds.
  /// [HomeDayPlan.unknown] without the calendar of its week, so Inicio keeps
  /// the single rest-day state (Q11) until the calendar answers.
  HomeDayPlan get dayPlan =>
      weekMarks?.planFor(selectedDate) ?? HomeDayPlan.unknown;

  const HomeRestDay(
    this.summary, {
    required this.selectedDate,
    this.refreshError,
    this.weekMarks,
  });
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
}
