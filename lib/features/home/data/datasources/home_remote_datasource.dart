import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/home/data/models/home_summary_model.dart';

abstract class HomeRemoteDataSource {
  Future<HomeSummaryModel> getHomeSummary({DateTime? date});
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  static const _emptyMarker = '__empty__';

  const HomeRemoteDataSourceImpl(this._apiClient, this._localStorage);

  @override
  Future<HomeSummaryModel> getHomeSummary({DateTime? date}) async {
    final dateKey = _dateKey(date ?? DateTime.now());

    final results = await Future.wait<Map<String, dynamic>?>(([
      _getTrainingToday(date: date, cacheKey: 'home_training_$dateKey'),
      _getDietToday(date: date, cacheKey: 'home_diet_$dateKey'),
      _getStreak(),
      _getProfile(),
      _getLatestMetric(),
      _getDayProgress(date: date, cacheKey: 'home_progress_$dateKey'),
    ]));

    return HomeSummaryModel.fromParts(
      training: results[0],
      diet: results[1],
      streak: results[2],
      profile: results[3],
      latestMetric: results[4],
      progress: results[5],
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _cacheNullableMap(
    String key,
    Map<String, dynamic>? value,
  ) async {
    await _localStorage.cacheData(key, value ?? {_emptyMarker: true});
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
  }) async {
    try {
      final queryParams = date != null ? {'date': _dateKey(date)} : null;
      final response = await _apiClient.dio.get<dynamic>(
        '/trainings/today',
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
      return _getCachedNullableMap(cacheKey);
    } catch (_) {
      return _getCachedNullableMap(cacheKey);
    }
  }

  Future<Map<String, dynamic>?> _getDietToday({
    DateTime? date,
    required String cacheKey,
  }) async {
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
      return _getCachedNullableMap(cacheKey);
    } catch (_) {
      return _getCachedNullableMap(cacheKey);
    }
  }

  Future<Map<String, dynamic>?> _getStreak() async {
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
    } catch (_) {
      return _getCachedNullableMap('home_streak');
    }
  }

  Future<Map<String, dynamic>?> _getProfile() async {
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
    } catch (_) {
      return _getCachedNullableMap('home_profile');
    }
  }

  Future<Map<String, dynamic>?> _getLatestMetric() async {
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
    } catch (_) {
      return _getCachedNullableMap('home_latest_metric');
    }
  }

  Future<Map<String, dynamic>?> _getDayProgress({
    DateTime? date,
    required String cacheKey,
  }) async {
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
        await _cacheNullableMap(cacheKey, inner);
        return inner;
      }
      return _getCachedNullableMap(cacheKey);
    } catch (_) {
      return _getCachedNullableMap(cacheKey);
    }
  }
}
