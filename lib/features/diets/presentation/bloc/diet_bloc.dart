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

  Future<void> _onDietLoad(
    DietLoadRequested event,
    Emitter<DietState> emit,
  ) async {
    emit(const DietLoading());
    try {
      final targetDate = _resolvedDate(event.date);
      final results = await Future.wait([
        _getTodayDietUseCase(targetDate),
        _getCompletedMealsUseCase(targetDate),
      ]);
      final diet = results[0] as DietEntity?;
      if (diet == null) {
        emit(DietNoContent(selectedDate: targetDate));
      } else {
        emit(
          DietLoaded(
            diet,
            completedMealIds: results[1] as Set<String>,
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
        _getMealUseCase(event.mealId),
        _getCompletedMealsUseCase(targetDate),
      ]);
      final meal = results[0] as MealEntity;
      final completedMealIds = results[1] as Set<String>;
      emit(
        MealDetailLoaded(
          meal,
          isCompleted: completedMealIds.contains(event.mealId),
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
      final updated = Set<String>.from(current.completedMealIds);
      if (event.completed) {
        updated.add(event.mealId);
      } else {
        updated.remove(event.mealId);
      }
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
      emit(current.copyWith(isCompleted: event.completed));

      try {
        if (event.completed) {
          await _markMealCompletedUseCase(event.mealId, date);
        } else {
          await _unmarkMealCompletedUseCase(event.mealId, date);
        }
      } catch (_) {
        emit(current.copyWith(isCompleted: previous));
      }
    }
  }
}
