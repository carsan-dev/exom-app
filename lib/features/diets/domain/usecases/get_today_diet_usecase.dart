import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';

class GetTodayDietUseCase {
  final DietRepository _repository;

  const GetTodayDietUseCase(this._repository);

  Future<DietEntity?> call() => _repository.getTodayDiet();
}
