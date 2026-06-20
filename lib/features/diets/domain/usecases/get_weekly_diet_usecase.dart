import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class GetWeeklyDietUseCase {
  final DietRepository _repository;

  const GetWeeklyDietUseCase(this._repository);

  Future<WeeklyDietEntity> call(String weekStart) =>
      _repository.getWeeklyDiet(weekStart);
}
