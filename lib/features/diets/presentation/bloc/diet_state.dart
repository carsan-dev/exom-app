part of 'diet_bloc.dart';

abstract class DietState {
  const DietState();
}

class DietInitial extends DietState {
  const DietInitial();
}

class DietLoading extends DietState {
  const DietLoading();
}

class DietLoaded extends DietState {
  final DietEntity diet;
  final Set<String> completedMealIds;

  const DietLoaded(this.diet, {this.completedMealIds = const {}});

  DietLoaded copyWith({DietEntity? diet, Set<String>? completedMealIds}) {
    return DietLoaded(
      diet ?? this.diet,
      completedMealIds: completedMealIds ?? this.completedMealIds,
    );
  }
}

class DietNoContent extends DietState {
  const DietNoContent();
}

class MealDetailLoaded extends DietState {
  final MealEntity meal;
  const MealDetailLoaded(this.meal);
}

class DietError extends DietState {
  final String message;
  const DietError(this.message);
}
