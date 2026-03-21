import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/calendar/data/models/calendar_day_model.dart';
import 'package:exom_app/features/calendar/data/models/week_summary_model.dart';

abstract class CalendarRemoteDataSource {
  Future<List<CalendarDayModel>> getMonthCalendar(int year, int month);
  Future<WeekSummaryModel> getWeekSummary(String weekStart);
}

class CalendarRemoteDataSourceImpl implements CalendarRemoteDataSource {
  final ApiClient _apiClient;

  const CalendarRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<CalendarDayModel>> getMonthCalendar(int year, int month) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/calendar/month',
      queryParameters: {'year': year, 'month': month},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final items = data['data'];
      if (items is List) {
        return items
            .map((e) => CalendarDayModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<WeekSummaryModel> getWeekSummary(String weekStart) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/calendar/week-summary',
      queryParameters: {'week_start': weekStart},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return WeekSummaryModel.fromJson(inner);
      }
    }
    throw Exception('Invalid week summary response');
  }
}
