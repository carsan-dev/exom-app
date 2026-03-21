part of 'diet_bloc.dart';

abstract class DietEvent {
  const DietEvent();
}

class DietLoadRequested extends DietEvent {
  const DietLoadRequested();
}

class MealDetailLoadRequested extends DietEvent {
  final String mealId;
  const MealDetailLoadRequested(this.mealId);
}

class MarkMealCompleted extends DietEvent {
  final String mealId;
  final bool completed;
  const MarkMealCompleted({required this.mealId, required this.completed});
}
