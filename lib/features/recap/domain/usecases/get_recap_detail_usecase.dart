import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';

class GetRecapDetailUseCase {
  final RecapRepository _repository;

  const GetRecapDetailUseCase(this._repository);

  Future<RecapEntity> call(String id) => _repository.getMyRecapById(id);
}
