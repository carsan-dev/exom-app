import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/services/pending_progress_overlay.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/home/data/models/home_summary_model.dart';

abstract class HomeRemoteDataSource {
  Future<HomeSummaryModel> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  });
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  static const _emptyMarker = '__empty__';

  const HomeRemoteDataSourceImpl(this._apiClient, this._localStorage);

  @override
  Future<HomeSummaryModel> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) async {
    return _localStorage.sessionTask(() async {
      final dateKey = _dateKey(date ?? DateTime.now());
      // E1 D1: errors of the requests answered from the saved copy.
      final failures = <Object>[];

      final results = await Future.wait<Map<String, dynamic>?>(([
        _getTrainingToday(
          date: date,
          cacheKey: 'home_training_$dateKey',
          failures: failures,
        ),
        _getDietToday(
          date: date,
          cacheKey: 'home_diet_$dateKey',
          failures: failures,
        ),
        includeSharedData ? _getStreak(failures) : Future.value(),
        includeSharedData ? _getProfile(failures) : Future.value(),
        includeSharedData ? _getLatestMetric(failures) : Future.value(),
        _getDayProgress(
          date: date,
          cacheKey: 'home_progress_$dateKey',
          failures: failures,
        ),
      ]));

      return HomeSummaryModel.fromParts(
        training: results[0],
        diet: results[1],
        streak: results[2],
        profile: results[3],
        latestMetric: results[4],
        progress: results[5],
        staleReason: _staleReasonOf(failures),
      );
    });
  }

  /// E1 D1: the reason the summary is (partly) the saved copy, `null` when
  /// every request answered. A rejected or failed request (401, 403, 5xx...)
  /// wins over a connectivity failure, so it is never presented as offline;
  /// otherwise the reason is the connectivity failure (status 0).
  static String? _staleReasonOf(List<Object> failures) {
    if (failures.isEmpty) return null;
    final chosen = failures.firstWhere(
      (error) => !isOfflineError(error),
      orElse: () => failures.first,
    );
    return (ApiException.maybeFrom(chosen) ?? chosen).toString();
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _cacheNullableMap(
    String key,
    Map<String, dynamic>? value,
  ) async {
    return _localStorage.sessionTask(() async {
      await _localStorage.cacheData(key, value ?? {_emptyMarker: true});
    });
  }

  Map<String, dynamic>? _getCachedNullableMap(String key) {
    final cached = _localStorage.getCachedMap(key);
    if (cached == null) {
      return null;
    }

    if (cached[_emptyMarker] == true) {
      return null;
    }

    return cached;
  }

  Future<Map<String, dynamic>?> _getTrainingToday({
    DateTime? date,
    required String cacheKey,
    required List<Object> failures,
  }) async {
    return _localStorage.sessionTask(() async {
      try {
        final queryParams = date != null ? {'date': _dateKey(date)} : null;
        late Response<dynamic> response;
        for (var attempt = 0; attempt < 3; attempt++) {
          response = await _apiClient.dio.get<dynamic>(
            '/trainings/day',
            queryParameters: queryParams,
          );
          if (response.statusCode != 204 && response.data != null) break;
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 250 * (attempt + 1)),
            );
          }
        }
        if (response.statusCode == 204 || response.data == null) {
          return null;
        }
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final inner = data['data'] as Map<String, dynamic>?;
          await _cacheNullableMap(cacheKey, inner);
          return inner;
        }
        return _getCachedNullableMap(cacheKey);
      } on DioException catch (e) {
        if (e.response?.statusCode == 204 || e.response?.statusCode == 404) {
          return null;
        }
        failures.add(e);
        return _getCachedNullableMap(cacheKey);
      } catch (e) {
        failures.add(e);
        return _getCachedNullableMap(cacheKey);
      }
    });
  }

  Future<Map<String, dynamic>?> _getDietToday({
    DateTime? date,
    required String cacheKey,
    required List<Object> failures,
  }) async {
    return _localStorage.sessionTask(() async {
      try {
        final queryParams = date != null ? {'date': _dateKey(date)} : null;
        final response = await _apiClient.dio.get<dynamic>(
          '/diets/today',
          queryParameters: queryParams,
        );
        if (response.statusCode == 204 || response.data == null) {
          await _cacheNullableMap(cacheKey, null);
          return null;
        }
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final inner = data['data'] as Map<String, dynamic>?;
          await _cacheNullableMap(cacheKey, inner);
          return inner;
        }
        return _getCachedNullableMap(cacheKey);
      } on DioException catch (e) {
        if (e.response?.statusCode == 204 || e.response?.statusCode == 404) {
          await _cacheNullableMap(cacheKey, null);
          return null;
        }
        failures.add(e);
        return _getCachedNullableMap(cacheKey);
      } catch (e) {
        failures.add(e);
        return _getCachedNullableMap(cacheKey);
      }
    });
  }

  Future<Map<String, dynamic>?> _getStreak(List<Object> failures) async {
    return _localStorage.sessionTask(() async {
      try {
        final response = await _apiClient.dio.get<dynamic>('/streaks/me');
        if (response.data == null) return _getCachedNullableMap('home_streak');
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final inner = data['data'] as Map<String, dynamic>?;
          await _cacheNullableMap('home_streak', inner);
          return inner;
        }
        return _getCachedNullableMap('home_streak');
      } catch (e) {
        failures.add(e);
        return _getCachedNullableMap('home_streak');
      }
    });
  }

  Future<Map<String, dynamic>?> _getProfile(List<Object> failures) async {
    return _localStorage.sessionTask(() async {
      try {
        final response = await _apiClient.dio.get<dynamic>('/profile/me');
        if (response.data == null) return _getCachedNullableMap('home_profile');
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final inner = data['data'] as Map<String, dynamic>?;
          await _cacheNullableMap('home_profile', inner);
          return inner;
        }
        return _getCachedNullableMap('home_profile');
      } catch (e) {
        failures.add(e);
        return _getCachedNullableMap('home_profile');
      }
    });
  }

  Future<Map<String, dynamic>?> _getLatestMetric(List<Object> failures) async {
    return _localStorage.sessionTask(() async {
      try {
        final response = await _apiClient.dio.get<dynamic>('/metrics/latest');
        if (response.data == null) {
          return _getCachedNullableMap('home_latest_metric');
        }
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final inner = data['data'] as Map<String, dynamic>?;
          await _cacheNullableMap('home_latest_metric', inner);
          return inner;
        }
        return _getCachedNullableMap('home_latest_metric');
      } catch (e) {
        failures.add(e);
        return _getCachedNullableMap('home_latest_metric');
      }
    });
  }

  Future<Map<String, dynamic>?> _getDayProgress({
    DateTime? date,
    required String cacheKey,
    required List<Object> failures,
  }) async {
    return _localStorage.sessionTask(() async {
      try {
        final target = date ?? DateTime.now();
        final response = await _apiClient.dio.get<dynamic>(
          '/progress',
          queryParameters: {'date': _dateKey(target)},
        );
        if (response.data == null) return _getCachedNullableMap(cacheKey);
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final inner = (data['data'] as Map<String, dynamic>?) ?? data;
          final targetDate = _dateKey(target);
          final merged = overlayPendingProgressActions(
            progress: inner,
            actions: _localStorage.getPendingSyncActions(),
            date: targetDate,
          );
          await _cacheNullableMap(cacheKey, merged);
          return merged;
        }
        return _getCachedNullableMap(cacheKey);
      } catch (e) {
        failures.add(e);
        final cached = _getCachedNullableMap(cacheKey);
        if (cached == null) return null;
        final target = date ?? DateTime.now();
        return overlayPendingProgressActions(
          progress: cached,
          actions: _localStorage.getPendingSyncActions(),
          date: _dateKey(target),
        );
      }
    });
  }
}
