import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';

class GetHomeSummaryUseCase {
  final HomeRepository _repository;

  const GetHomeSummaryUseCase(this._repository);

  Future<HomeSummaryEntity> call({DateTime? date}) =>
      _repository.getHomeSummary(date: date);
}
