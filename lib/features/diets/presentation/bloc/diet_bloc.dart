import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/usecases/get_today_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/mark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_completed_meals_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/unmark_meal_completed_usecase.dart';

part 'diet_event.dart';
part 'diet_state.dart';

class DietBloc extends Bloc<DietEvent, DietState> {
  final GetTodayDietUseCase _getTodayDietUseCase;
  final GetMealUseCase _getMealUseCase;
  final MarkMealCompletedUseCase _markMealCompletedUseCase;
  final UnmarkMealCompletedUseCase _unmarkMealCompletedUseCase;
  final GetCompletedMealsUseCase _getCompletedMealsUseCase;

  DietBloc({
    required GetTodayDietUseCase getTodayDietUseCase,
    required GetMealUseCase getMealUseCase,
    required MarkMealCompletedUseCase markMealCompletedUseCase,
    required UnmarkMealCompletedUseCase unmarkMealCompletedUseCase,
    required GetCompletedMealsUseCase getCompletedMealsUseCase,
  }) : _getTodayDietUseCase = getTodayDietUseCase,
       _getMealUseCase = getMealUseCase,
       _markMealCompletedUseCase = markMealCompletedUseCase,
       _unmarkMealCompletedUseCase = unmarkMealCompletedUseCase,
       _getCompletedMealsUseCase = getCompletedMealsUseCase,
       super(const DietInitial()) {
    on<DietLoadRequested>(_onDietLoad);
    on<MealDetailLoadRequested>(_onMealDetailLoad);
    on<MarkMealCompleted>(_onMarkMealCompleted);
  }

  String _todayDate() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  String _resolvedDate(String? date) => date ?? _todayDate();

  Set<String> _mealGroupIds(MealEntity meal) {
    return {meal.id, ...meal.variants.map((variant) => variant.id)};
  }

  Set<String> _completedMealsForToggle({
    required Set<String> currentIds,
    required String mealId,
    required bool completed,
    required Iterable<MealEntity> meals,
  }) {
    final updated = Set<String>.from(currentIds);
    final group = meals
        .map(_mealGroupIds)
        .firstWhere((ids) => ids.contains(mealId), orElse: () => {mealId});

    if (completed) {
      updated.removeAll(group);
      updated.add(mealId);
    } else {
      updated.remove(mealId);
    }

    return updated;
  }

  Future<void> _onDietLoad(
    DietLoadRequested event,
    Emitter<DietState> emit,
  ) async {
    emit(const DietLoading());
    try {
      final targetDate = _resolvedDate(event.date);
      final diet = await _getTodayDietUseCase(targetDate);
      if (diet == null) {
        emit(DietNoContent(selectedDate: targetDate));
      } else {
        Set<String> completedMealIds = {};
        try {
          completedMealIds = await _getCompletedMealsUseCase(targetDate);
        } catch (_) {}
        emit(
          DietLoaded(
            diet,
            completedMealIds: completedMealIds,
            selectedDate: targetDate,
          ),
        );
      }
    } catch (e) {
      emit(DietError(e.toString()));
    }
  }

  Future<void> _onMealDetailLoad(
    MealDetailLoadRequested event,
    Emitter<DietState> emit,
  ) async {
    emit(const DietLoading());
    try {
      final targetDate = _resolvedDate(event.date);
      final results = await Future.wait([
        _getMealUseCase(event.mealId, date: targetDate),
        _getCompletedMealsUseCase(targetDate),
      ]);
      final meal = results[0] as MealEntity;
      final completedMealIds = results[1] as Set<String>;
      emit(
        MealDetailLoaded(
          meal,
          isCompleted: completedMealIds.contains(event.mealId),
          completedMealIds: completedMealIds,
          selectedDate: targetDate,
        ),
      );
    } catch (e) {
      emit(DietError(e.toString()));
    }
  }

  Future<void> _onMarkMealCompleted(
    MarkMealCompleted event,
    Emitter<DietState> emit,
  ) async {
    final current = state;

    if (current is DietLoaded) {
      final date = current.selectedDate;
      final previous = Set<String>.from(current.completedMealIds);
      final updated = _completedMealsForToggle(
        currentIds: current.completedMealIds,
        mealId: event.mealId,
        completed: event.completed,
        meals: current.diet.meals,
      );
      emit(current.copyWith(completedMealIds: updated));

      try {
        if (event.completed) {
          await _markMealCompletedUseCase(event.mealId, date);
        } else {
          await _unmarkMealCompletedUseCase(event.mealId, date);
        }
      } catch (_) {
        emit(current.copyWith(completedMealIds: previous));
      }
      return;
    }

    if (current is MealDetailLoaded) {
      final date = current.selectedDate;
      final previous = current.isCompleted;
      final previousCompletedIds = Set<String>.from(current.completedMealIds);
      final updatedCompletedIds = _completedMealsForToggle(
        currentIds: current.completedMealIds,
        mealId: event.mealId,
        completed: event.completed,
        meals: [current.meal],
      );
      emit(
        current.copyWith(
          isCompleted: event.completed,
          completedMealIds: updatedCompletedIds,
        ),
      );

      try {
        if (event.completed) {
          await _markMealCompletedUseCase(event.mealId, date);
        } else {
          await _unmarkMealCompletedUseCase(event.mealId, date);
        }
      } catch (_) {
        emit(
          current.copyWith(
            isCompleted: previous,
            completedMealIds: previousCompletedIds,
          ),
        );
      }
    }
  }
}
