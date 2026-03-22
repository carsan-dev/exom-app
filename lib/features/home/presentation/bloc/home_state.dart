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
  const HomeLoaded(this.summary, {required this.selectedDate});
}

class HomeRestDay extends HomeState {
  final HomeSummaryEntity summary;
  final DateTime selectedDate;
  const HomeRestDay(this.summary, {required this.selectedDate});
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
}
