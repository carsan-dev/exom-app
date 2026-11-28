import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/metrics/data/models/body_metric_model.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:intl/intl.dart';

abstract class MetricsRemoteDataSource {
  Future<BodyMetricModel> saveMetric(Map<String, dynamic> data);
  Future<BodyMetricModel?> getLatestMetric({String? date});
  Future<List<BodyMetricModel>> getWeightHistory();

  /// [getLatestMetric] (latest of all time) and [getWeightHistory] with their
  /// origin: `fromCache` is true only for the offline cache fallback.
  Future<MetricsRead<BodyMetricModel?>> getLatestMetricWithSource();
  Future<MetricsRead<List<BodyMetricModel>>> getWeightHistoryWithSource();
}

class MetricsRemoteDataSourceImpl implements MetricsRemoteDataSource {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  /// Source of «today» for [saveMetric] (the local day, as the form sends
  /// it).
  final DateTime Function() _clock;

  const MetricsRemoteDataSourceImpl(
    this._apiClient,
    this._localStorage, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  @override
  Future<BodyMetricModel> saveMetric(Map<String, dynamic> data) async {
    return _localStorage.sessionTask(() async {
      final response = await _apiClient.dio.post<dynamic>(
        '/metrics',
        data: data,
      );
      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw Exception('Invalid metric response');
      }

      final inner = payload['data'];
      if (inner is! Map<String, dynamic>) {
        throw Exception('Invalid metric response');
      }

      await _localStorage.cacheData('metrics_latest', inner);
      await _localStorage.cacheData('home_latest_metric', inner);
      // The offline copy of the saved date, read by a later load of that
      // date (M-6): without it the form showed the values from before the
      // save. The key is the requested date, as `_readLatestMetric` uses it.
      final savedDate = _dayOf(data['date']) ?? _dayOf(inner['date']);
      if (savedDate != null) {
        await _localStorage.cacheData('metrics_latest_$savedDate', inner);
      }

      final history =
          (_localStorage.getCachedList('metrics_weight_history') ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
      // Read before the saved entry joins the history (M-5).
      final lastWeightDay = _lastWeightDay(history);
      // One entry per date: a save of a date already cached replaces it.
      final savedDay = _dayOf(inner['date']);
      final sameDay = savedDay == null
          ? -1
          : history.indexWhere((entry) => _dayOf(entry['date']) == savedDay);
      final updatedHistory = sameDay == -1
          ? [inner, ...history]
          : (history..[sameDay] = inner);
      await _localStorage.cacheData('metrics_weight_history', updatedHistory);
      await _refreshProfileWeight(
        data,
        inner,
        savedDay: savedDate,
        lastWeightDay: lastWeightDay,
      );

      return BodyMetricModel.fromJson(inner);
    });
  }

  @override
  Future<BodyMetricModel?> getLatestMetric({String? date}) async {
    return (await _readLatestMetric(date: date)).value;
  }

  @override
  Future<MetricsRead<BodyMetricModel?>> getLatestMetricWithSource() {
    return _readLatestMetric();
  }

  /// The single implementation behind [getLatestMetric] and
  /// [getLatestMetricWithSource]: only the cache fallback is marked.
  Future<MetricsRead<BodyMetricModel?>> _readLatestMetric({String? date}) {
    return _localStorage.sessionTask(() async {
      final cacheKey = date == null ? 'metrics_latest' : 'metrics_latest_$date';
      try {
        final response = await _apiClient.dio.get<dynamic>(
          '/metrics/latest',
          queryParameters: date != null ? {'date': date} : null,
        );
        final inner = _envelopeData(response.data, '/metrics/latest');
        if (inner == null) return const MetricsRead(null);
        if (inner is! Map<String, dynamic>) {
          throw const FormatException('Unexpected /metrics/latest response');
        }
        await _localStorage.cacheData(cacheKey, inner);
        await _localStorage.cacheData('home_latest_metric', inner);
        return MetricsRead(BodyMetricModel.fromJson(inner));
      } on DioException catch (error) {
        // A request cancelled by a session change (logout or user switch)
        // is not a network error: report it as LocalSessionChanged.
        _localStorage.guardSession();
        // The API answers 200 with `data: null` when there is no record; a
        // 404 is still read as "no record", as the diets datasource does.
        if (error.response?.statusCode == 404) return const MetricsRead(null);
        if (isOfflineError(error)) {
          final cached = _localStorage.getCachedMap(cacheKey);
          if (cached != null) {
            return MetricsRead(
              BodyMetricModel.fromJson(cached),
              fromCache: true,
            );
          }
        }
        // Network and server errors reach the caller: «Progreso» must tell
        // them apart from an account without records.
        rethrow;
      }
    });
  }

  @override
  Future<List<BodyMetricModel>> getWeightHistory() async {
    return (await _readWeightHistory()).value;
  }

  @override
  Future<MetricsRead<List<BodyMetricModel>>> getWeightHistoryWithSource() {
    return _readWeightHistory();
  }

  /// The single implementation behind [getWeightHistory] and
  /// [getWeightHistoryWithSource]: only the cache fallback is marked.
  Future<MetricsRead<List<BodyMetricModel>>> _readWeightHistory() {
    return _localStorage.sessionTask(() async {
      try {
        final response = await _apiClient.dio.get<dynamic>(
          '/metrics/weight-history',
        );
        final items = _envelopeData(response.data, '/metrics/weight-history');
        if (items == null) return const MetricsRead(<BodyMetricModel>[]);
        if (items is! List) {
          throw const FormatException(
            'Unexpected /metrics/weight-history response',
          );
        }
        final normalized = items
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false);
        await _localStorage.cacheData('metrics_weight_history', normalized);
        return MetricsRead(
          normalized.map(BodyMetricModel.fromJson).toList(growable: false),
        );
      } on DioException catch (error) {
        // A request cancelled by a session change (logout or user switch)
        // is not a network error: report it as LocalSessionChanged.
        _localStorage.guardSession();
        if (isOfflineError(error)) {
          final cached = _localStorage.getCachedList('metrics_weight_history');
          if (cached != null) {
            return MetricsRead(
              cached
                  .whereType<Map<String, dynamic>>()
                  .map(BodyMetricModel.fromJson)
                  .toList(growable: false),
              fromCache: true,
            );
          }
        }
        // The API answers 200 with `data: []` when there is no record; any
        // other failure reaches the caller.
        rethrow;
      }
    });
  }

  /// Keeps `current_weight` of the cached `profile_me` (the weight the form
  /// preloads on a day without a record) in step with a saved weight that
  /// becomes the latest one (M-5): the API then sets `current_weight` to it,
  /// but `profile_me` is only rewritten by `GET`/`PUT /profile/me`. The saved
  /// weight is the latest when its day is not before the last weight of the
  /// cached history (before this save) or, without one, when it is today.
  /// Without a cached profile nothing is created.
  Future<void> _refreshProfileWeight(
    Map<String, dynamic> data,
    Map<String, dynamic> saved, {
    required String? savedDay,
    required String? lastWeightDay,
  }) async {
    final weight = saved['weight_kg'];
    if (data['weight_kg'] == null || weight is! num || savedDay == null) {
      return;
    }
    final profile = _localStorage.getCachedMap('profile_me');
    if (profile == null) return;
    final floor = lastWeightDay ?? DateFormat('yyyy-MM-dd').format(_clock());
    if (savedDay.compareTo(floor) < 0) return;
    await _localStorage.cacheData('profile_me', {
      ...profile,
      'current_weight': weight,
    });
  }

  /// The latest day of [history] with a weight, or null without one.
  static String? _lastWeightDay(List<Map<String, dynamic>> history) {
    String? last;
    for (final entry in history) {
      final day = _dayOf(entry['date']);
      if (entry['weight_kg'] == null || day == null) continue;
      if (last == null || day.compareTo(last) > 0) last = day;
    }
    return last;
  }

  /// The `yyyy-MM-dd` day of a cached `date` («2026-11-18» or an ISO
  /// timestamp), or null when it is not a date string.
  static String? _dayOf(Object? date) =>
      date is String && date.length >= 10 ? date.substring(0, 10) : null;

  /// The `data` field of the API envelope `{success, data, ...}`. A 200 of any
  /// other shape (e.g. a captive portal's HTML page) is an unexpected answer,
  /// never an account without records.
  static Object? _envelopeData(Object? body, String path) {
    if (body is! Map<String, dynamic> || !body.containsKey('data')) {
      throw FormatException('Unexpected $path response');
    }
    return body['data'];
  }
}
