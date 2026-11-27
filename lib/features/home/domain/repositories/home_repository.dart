import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';

abstract class HomeRepository {
  /// With [includeSharedData] false the date-independent fields (streak, name,
  /// avatar, latest metrics) are not requested and stay at their defaults; the
  /// caller supplies them from an earlier full load.
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  });
}
