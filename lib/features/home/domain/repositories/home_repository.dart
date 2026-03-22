import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';

abstract class HomeRepository {
  Future<HomeSummaryEntity> getHomeSummary({DateTime? date});
}
