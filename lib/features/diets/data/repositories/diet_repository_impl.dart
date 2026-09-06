import 'package:exom_app/features/diets/data/datasources/diet_remote_datasource.dart';
import 'package:exom_app/features/diets/data/models/diet_model.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class DietRepositoryImpl implements DietRepository {
  final DietRemoteDataSource _remoteDataSource;

  const DietRepositoryImpl(this._remoteDataSource);

  @override
  Future<DietHistory> getDietHistory({String? date}) async {
    final history = await _remoteDataSource.getDietHistory(date: date);
    return DietHistory(
      entries: history.entries
          .map(
            (entry) => DietHistoryEntry(
              diet: _mapToEntity(entry.diet),
              legacyAvailable: entry.legacyAvailable,
            ),
          )
          .toList(growable: false),
      unresolvedMealIds: history.unresolvedMealIds,
    );
  }

  @override
  Future<DietEntity?> getTodayDiet({String? date}) async {
    final model = await _remoteDataSource.getTodayDiet(date: date);
    if (model == null) return null;
    return _mapToEntity(model);
  }

  @override
  Future<WeeklyDietEntity> getWeeklyDiet(String weekStart) async {
    final model = await _remoteDataSource.getWeeklyDiet(weekStart);
    return WeeklyDietEntity(
      weekStart: model.weekStart,
      weekEnd: model.weekEnd,
      days: model.days
          .map(
            (day) => WeeklyDietDayEntity(
              date: day.date,
              diet: day.diet == null ? null : _mapToEntity(day.diet!),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<DietPeriodEntity> getMonthlyDiet(int year, int month) async {
    final model = await _remoteDataSource.getMonthlyDiet(year, month);
    return DietPeriodEntity(
      start: model.monthStart,
      end: model.monthEnd,
      days: model.days
          .map(
            (day) => DietPeriodDayEntity(
              date: day.date,
              diet: day.diet == null ? null : _mapToEntity(day.diet!),
            ),
          )
          .toList(growable: false),
    );
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
  Future<void> unmarkMealCompleted(String mealId, String date) {
    return _remoteDataSource.unmarkMealCompleted(mealId, date);
  }

  @override
  Future<Set<String>> getCompletedMealIds({String? date}) {
    return _remoteDataSource.getCompletedMealIds(date: date);
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
          .map(
            (i) => MealIngredientEntity(
              id: i.id,
              name: i.name,
              quantity: i.quantity,
              unit: i.unit,
              gramsEquivalent: i.gramsEquivalent,
              icon: i.icon,
            ),
          )
          .toList(),
      variants: model.variants.map(_mapMealToEntity).toList(),
    );
  }
}
