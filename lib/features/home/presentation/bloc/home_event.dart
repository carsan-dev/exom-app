part of 'home_bloc.dart';

abstract class HomeEvent {
  const HomeEvent();
}

class HomeLoadRequested extends HomeEvent {
  const HomeLoadRequested();
}
