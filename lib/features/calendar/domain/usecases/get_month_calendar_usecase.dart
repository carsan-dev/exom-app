import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';

class GetMonthCalendarUseCase {
  final CalendarRepository _repository;

  const GetMonthCalendarUseCase(this._repository);

  Future<List<CalendarDayEntity>> call(int year, int month) {
    return _repository.getMonthCalendar(year, month);
  }
}
