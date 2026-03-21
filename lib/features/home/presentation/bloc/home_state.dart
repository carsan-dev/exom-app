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
  const HomeLoaded(this.summary);
}

class HomeRestDay extends HomeState {
  final HomeSummaryEntity summary;
  const HomeRestDay(this.summary);
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
}
