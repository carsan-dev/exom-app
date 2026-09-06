import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';

abstract class DietRepository {
  Future<DietHistory> getDietHistory({String? date});
  Future<DietEntity?> getTodayDiet({String? date});
  Future<WeeklyDietEntity> getWeeklyDiet(String weekStart);
  Future<DietPeriodEntity> getMonthlyDiet(int year, int month);
  Future<MealEntity> getMeal(String mealId);
  Future<void> markMealCompleted(String mealId, String date);
  Future<void> unmarkMealCompleted(String mealId, String date);
  Future<Set<String>> getCompletedMealIds({String? date});
}
