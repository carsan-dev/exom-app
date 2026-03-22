import 'package:exom_app/features/diets/data/datasources/diet_remote_datasource.dart';
import 'package:exom_app/features/diets/data/models/diet_model.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class DietRepositoryImpl implements DietRepository {
  final DietRemoteDataSource _remoteDataSource;

  const DietRepositoryImpl(this._remoteDataSource);

  @override
  Future<DietEntity?> getTodayDiet() async {
    final model = await _remoteDataSource.getTodayDiet();
    if (model == null) return null;
    return _mapToEntity(model);
  }

  @override
  Future<MealEntity> getMeal(String mealId) async {
    final model = await _remoteDataSource.getMeal(mealId);
    return _mapMealToEntity(model);
  }

  @override
  Future<void> markMealCompleted(String mealId, String date) {
    return _remoteDataSource.markMealCompleted(mealId, date);
  }

  @override
  Future<Set<String>> getCompletedMealIds() {
    return _remoteDataSource.getCompletedMealIds();
  }

  DietEntity _mapToEntity(DietModel model) {
    return DietEntity(
      id: model.id,
      name: model.name,
      totalCalories: model.totalCalories,
      totalProteinG: model.totalProteinG,
      totalCarbsG: model.totalCarbsG,
      totalFatG: model.totalFatG,
      meals: model.meals.map(_mapMealToEntity).toList(),
    );
  }

  MealEntity _mapMealToEntity(MealModel model) {
    return MealEntity(
      id: model.id,
      type: model.type,
      name: model.name,
      imageUrl: model.imageUrl,
      calories: model.calories,
      proteinG: model.proteinG,
      carbsG: model.carbsG,
      fatG: model.fatG,
      nutritionalBadges: model.nutritionalBadges,
      ingredients: model.ingredients
          .map((i) => MealIngredientEntity(
                name: i.name,
                quantity: i.quantity,
                unit: i.unit,
              ))
          .toList(),
    );
  }
}
