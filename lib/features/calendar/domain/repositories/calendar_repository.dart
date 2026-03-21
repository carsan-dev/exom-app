import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';

abstract class CalendarRepository {
  Future<List<CalendarDayEntity>> getMonthCalendar(int year, int month);
  Future<WeekSummaryEntity> getWeekSummary(String weekStart);
}
