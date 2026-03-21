import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class GetMealUseCase {
  final DietRepository _repository;

  const GetMealUseCase(this._repository);

  Future<MealEntity> call(String mealId) => _repository.getMeal(mealId);
}
