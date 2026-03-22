part of 'home_bloc.dart';

abstract class HomeEvent {
  const HomeEvent();
}

class HomeLoadRequested extends HomeEvent {
  const HomeLoadRequested();
}

class HomeDateSelected extends HomeEvent {
  final DateTime date;
  const HomeDateSelected(this.date);
}
