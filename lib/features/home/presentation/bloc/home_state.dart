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
  const HomeLoaded(
    this.summary, {
    required this.selectedDate,
    this.refreshError,
  });
}

class HomeRestDay extends HomeState {
  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  /// See [HomeLoaded.refreshError].
  final String? refreshError;
  const HomeRestDay(
    this.summary, {
    required this.selectedDate,
    this.refreshError,
  });
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
}
