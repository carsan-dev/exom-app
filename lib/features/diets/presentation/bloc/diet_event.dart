part of 'diet_bloc.dart';

abstract class DietEvent {
  const DietEvent();
}

class DietLoadRequested extends DietEvent {
  final String? date;

  const DietLoadRequested({this.date});
}

class MealDetailLoadRequested extends DietEvent {
  final String mealId;
  final String? date;

  const MealDetailLoadRequested(this.mealId, {this.date});
}

class MarkMealCompleted extends DietEvent {
  final String mealId;
  final bool completed;
  const MarkMealCompleted({required this.mealId, required this.completed});
}
