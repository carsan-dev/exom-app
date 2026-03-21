import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class MarkMealCompletedUseCase {
  final DietRepository _repository;

  const MarkMealCompletedUseCase(this._repository);

  Future<void> call(String mealId, String date) =>
      _repository.markMealCompleted(mealId, date);
}
