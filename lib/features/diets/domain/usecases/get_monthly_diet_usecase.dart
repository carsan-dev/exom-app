import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class GetMonthlyDietUseCase {
  final DietRepository _repository;

  const GetMonthlyDietUseCase(this._repository);

  Future<DietPeriodEntity> call(int year, int month) =>
      _repository.getMonthlyDiet(year, month);
}
