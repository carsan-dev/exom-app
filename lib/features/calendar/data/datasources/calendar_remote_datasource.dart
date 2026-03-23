import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/calendar/data/models/calendar_day_model.dart';
import 'package:exom_app/features/calendar/data/models/week_summary_model.dart';

abstract class CalendarRemoteDataSource {
  Future<List<CalendarDayModel>> getMonthCalendar(int year, int month);
  Future<WeekSummaryModel> getWeekSummary(String weekStart);
}

class CalendarRemoteDataSourceImpl implements CalendarRemoteDataSource {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  const CalendarRemoteDataSourceImpl(this._apiClient, this._localStorage);

  @override
  Future<List<CalendarDayModel>> getMonthCalendar(int year, int month) async {
    final cacheKey = 'calendar_month_${year}_$month';

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/calendar/month',
        queryParameters: {'year': year, 'month': month},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['data'];
        if (items is List) {
          final normalized = items
              .whereType<Map<String, dynamic>>()
              .map(Map<String, dynamic>.from)
              .toList(growable: false);
          await _localStorage.cacheData(cacheKey, normalized);
          return normalized
              .map(CalendarDayModel.fromJson)
              .toList(growable: false);
        }
      }
      return [];
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedList(cacheKey);
        if (cached != null) {
          return cached
              .whereType<Map<String, dynamic>>()
              .map(CalendarDayModel.fromJson)
              .toList(growable: false);
        }
      }
      rethrow;
    }
  }

  @override
  Future<WeekSummaryModel> getWeekSummary(String weekStart) async {
    final cacheKey = 'calendar_week_$weekStart';

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/calendar/week-summary',
        queryParameters: {'week_start': weekStart},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          await _localStorage.cacheData(cacheKey, inner);
          return WeekSummaryModel.fromJson(inner);
        }
      }
      throw Exception('Invalid week summary response');
    } catch (error) {
      if (isOfflineError(error)) {
        final cached = _localStorage.getCachedMap(cacheKey);
        if (cached != null) {
          return WeekSummaryModel.fromJson(cached);
        }
      }
      rethrow;
    }
  }
}
