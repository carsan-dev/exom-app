import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class GetCompletedMealsUseCase {
  final DietRepository _repository;

  const GetCompletedMealsUseCase(this._repository);

  Future<Set<String>> call([String? date]) =>
      _repository.getCompletedMealIds(date: date);
}
