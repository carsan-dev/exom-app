import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';

class SubmitRecapUseCase {
  final RecapRepository _repository;

  const SubmitRecapUseCase(this._repository);

  Future<void> call(String id) => _repository.submitRecap(id);
}
