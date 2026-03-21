import 'package:exom_app/features/calendar/data/datasources/calendar_remote_datasource.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  final CalendarRemoteDataSource _remoteDataSource;

  const CalendarRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<CalendarDayEntity>> getMonthCalendar(int year, int month) {
    return _remoteDataSource.getMonthCalendar(year, month);
  }

  @override
  Future<WeekSummaryEntity> getWeekSummary(String weekStart) {
    return _remoteDataSource.getWeekSummary(weekStart);
  }
}
