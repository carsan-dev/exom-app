part of 'home_bloc.dart';

abstract class HomeEvent {
  const HomeEvent();
}

class HomeLoadRequested extends HomeEvent {
  final DateTime? date;

  const HomeLoadRequested({this.date});
}

class HomeDateSelected extends HomeEvent {
  final DateTime date;
  const HomeDateSelected(this.date);
}
