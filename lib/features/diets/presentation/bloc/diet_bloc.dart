import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/usecases/get_today_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/mark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_completed_meals_usecase.dart';

part 'diet_event.dart';
part 'diet_state.dart';

class DietBloc extends Bloc<DietEvent, DietState> {
  final GetTodayDietUseCase _getTodayDietUseCase;
  final GetMealUseCase _getMealUseCase;
  final MarkMealCompletedUseCase _markMealCompletedUseCase;
  final GetCompletedMealsUseCase _getCompletedMealsUseCase;

  DietBloc({
    required GetTodayDietUseCase getTodayDietUseCase,
    required GetMealUseCase getMealUseCase,
    required MarkMealCompletedUseCase markMealCompletedUseCase,
    required GetCompletedMealsUseCase getCompletedMealsUseCase,
  })  : _getTodayDietUseCase = getTodayDietUseCase,
        _getMealUseCase = getMealUseCase,
        _markMealCompletedUseCase = markMealCompletedUseCase,
        _getCompletedMealsUseCase = getCompletedMealsUseCase,
        super(const DietInitial()) {
    on<DietLoadRequested>(_onDietLoad);
    on<MealDetailLoadRequested>(_onMealDetailLoad);
    on<MarkMealCompleted>(_onMarkMealCompleted);
  }

  Future<void> _onDietLoad(
    DietLoadRequested event,
    Emitter<DietState> emit,
  ) async {
    emit(const DietLoading());
    try {
      final results = await Future.wait([
        _getTodayDietUseCase(),
        _getCompletedMealsUseCase(),
      ]);
      final diet = results[0] as DietEntity?;
      if (diet == null) {
        emit(const DietNoContent());
      } else {
        emit(DietLoaded(diet, completedMealIds: results[1] as Set<String>));
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
      final meal = await _getMealUseCase(event.mealId);
      emit(MealDetailLoaded(meal));
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
      // Optimistic update
      final updated = Set<String>.from(current.completedMealIds);
      if (event.completed) {
        updated.add(event.mealId);
      } else {
        updated.remove(event.mealId);
      }
      emit(current.copyWith(completedMealIds: updated));

      // Sync with backend (fire-and-forget, best effort)
      if (event.completed) {
        try {
          final today = DateTime.now();
          final date =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          await _markMealCompletedUseCase(event.mealId, date);
        } catch (_) {
          // Don't revert UI on failure — progress is informational
        }
      }
    }
  }
}
