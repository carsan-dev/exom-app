import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';

class UpdateRecapUseCase {
  final RecapRepository _repository;

  const UpdateRecapUseCase(this._repository);

  Future<RecapEntity> call(String id, Map<String, dynamic> data) =>
      _repository.updateRecap(id, data);
}
