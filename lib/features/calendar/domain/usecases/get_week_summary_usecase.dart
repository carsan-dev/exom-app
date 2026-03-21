import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';

class GetWeekSummaryUseCase {
  final CalendarRepository _repository;

  const GetWeekSummaryUseCase(this._repository);

  Future<WeekSummaryEntity> call(String weekStart) {
    return _repository.getWeekSummary(weekStart);
  }
}
