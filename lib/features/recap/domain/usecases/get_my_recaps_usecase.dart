import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';

class GetMyRecapsUseCase {
  final RecapRepository _repository;

  const GetMyRecapsUseCase(this._repository);

  Future<List<RecapEntity>> call() => _repository.getMyRecaps();
}
