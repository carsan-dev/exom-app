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
  final String selectedDate;

  const DietLoaded(
    this.diet, {
    this.completedMealIds = const {},
    required this.selectedDate,
  });

  DietLoaded copyWith({
    DietEntity? diet,
    Set<String>? completedMealIds,
    String? selectedDate,
  }) {
    return DietLoaded(
      diet ?? this.diet,
      completedMealIds: completedMealIds ?? this.completedMealIds,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class DietNoContent extends DietState {
  final String selectedDate;

  const DietNoContent({required this.selectedDate});
}

class MealDetailLoaded extends DietState {
  final MealEntity meal;
  final bool isCompleted;
  final Set<String> completedMealIds;
  final String selectedDate;

  const MealDetailLoaded(
    this.meal, {
    this.isCompleted = false,
    this.completedMealIds = const {},
    required this.selectedDate,
  });

  MealDetailLoaded copyWith({
    MealEntity? meal,
    bool? isCompleted,
    Set<String>? completedMealIds,
    String? selectedDate,
  }) {
    return MealDetailLoaded(
      meal ?? this.meal,
      isCompleted: isCompleted ?? this.isCompleted,
      completedMealIds: completedMealIds ?? this.completedMealIds,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class DietError extends DietState {
  final String message;
  const DietError(this.message);
}
