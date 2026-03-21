import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';

abstract class DietRepository {
  Future<DietEntity?> getTodayDiet();
  Future<MealEntity> getMeal(String mealId);
  Future<void> markMealCompleted(String mealId, String date);
}
