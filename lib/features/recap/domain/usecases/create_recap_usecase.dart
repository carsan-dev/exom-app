import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';

class CreateRecapUseCase {
  final RecapRepository _repository;

  const CreateRecapUseCase(this._repository);

  Future<RecapEntity> call(Map<String, dynamic> data) =>
      _repository.createRecap(data);
}
