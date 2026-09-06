import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class GetMealUseCase {
  final DietRepository _repository;

  const GetMealUseCase(this._repository);

  Future<MealEntity> call(String mealId, {String? date}) async {
    if (date == null) return _repository.getMeal(mealId);
    // A date-specific sheet must use the assigned (possibly frozen) content,
    // never replace it with a mutable catalog lookup by meal ID.
    final diet = await _repository.getTodayDiet(date: date);
    for (final meal in diet?.meals ?? <MealEntity>[]) {
      if (meal.id == mealId) return meal;
      for (final variant in meal.variants) {
        if (variant.id == mealId) return variant;
      }
    }
    throw StateError('La comida no pertenece al plan de esta fecha');
  }
}
