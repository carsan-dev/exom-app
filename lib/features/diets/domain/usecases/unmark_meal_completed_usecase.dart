import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class UnmarkMealCompletedUseCase {
  final DietRepository _repository;

  const UnmarkMealCompletedUseCase(this._repository);

  Future<void> call(String mealId, String date) =>
      _repository.unmarkMealCompleted(mealId, date);
}
