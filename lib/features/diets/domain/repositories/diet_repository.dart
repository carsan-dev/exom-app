import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';

abstract class DietRepository {
  Future<DietEntity?> getTodayDiet({String? date});
  Future<MealEntity> getMeal(String mealId);
  Future<void> markMealCompleted(String mealId, String date);
  Future<void> unmarkMealCompleted(String mealId, String date);
  Future<Set<String>> getCompletedMealIds({String? date});
}
