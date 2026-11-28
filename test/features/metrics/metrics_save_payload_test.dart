// L6-UX5: saving a metric sends the payload as built by the form, explicit
// nulls included (a cleared saved value must reach the API as null), and the
// cached weight history keeps one entry per date: saving a date that is
// already in it replaces that entry instead of adding a second one.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/metrics/data/datasources/metrics_remote_datasource.dart';
import 'package:exom_app/features/metrics/data/models/body_metric_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every POST /metrics with [saved] and records the request bodies;
/// [offline] makes every request fail as without connection.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.saved);

  final Map<String, Object?> saved;
  final bodies = <Object?>[];

  /// When set, every request fails as without connection.
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      bodies.add(jsonDecode(utf8.decode(bytes)));
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': saved}),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// In-memory cache; the Hive-backed one is not opened in unit tests.
class _Storage extends LocalStorage {
  final cache = <String, Object?>{};

  @override
  Future<void> cacheData(String key, dynamic value) async {
    cache[key] = value;
  }

  @override
  Map<String, dynamic>? getCachedMap(String key) {
    final value = cache[key];
    return value is Map<String, dynamic> ? value : null;
  }

  @override
  List<dynamic>? getCachedList(String key) {
    final value = cache[key];
    return value is List<dynamic> ? value : null;
  }
}

({MetricsRemoteDataSourceImpl datasource, _Adapter adapter, _Storage storage})
_env(Map<String, Object?> saved) {
  final api = ApiClient(
    useAuth: false,
    baseUrl: 'https://exom.test.invalid/api/v1',
  );
  final adapter = _Adapter(saved);
  api.dio.httpClientAdapter = adapter;
  addTearDown(() => api.dio.close(force: true));
  final storage = _Storage();
  return (
    datasource: MetricsRemoteDataSourceImpl(api, storage),
    adapter: adapter,
    storage: storage,
  );
}

void main() {
  test('the POST body keeps the explicit nulls', () async {
    final env = _env({'id': 'm-1', 'date': '2026-11-18', 'weight_kg': 78.6});
    await env.datasource.saveMetric({
      'date': '2026-11-18',
      'weight_kg': 78.6,
      'muscle_mass_kg': null,
      'waist_cm': null,
    });
    expect(env.adapter.bodies, [
      {
        'date': '2026-11-18',
        'weight_kg': 78.6,
        'muscle_mass_kg': null,
        'waist_cm': null,
      },
    ]);
  });

  test(
    'saving a date already in the cached history replaces its entry',
    () async {
      final saved = <String, Object?>{
        'id': 'm-2',
        'date': '2026-11-18T00:00:00.000Z',
        'weight_kg': 78.0,
      };
      final env = _env(saved);
      env.storage.cache['metrics_weight_history'] = <dynamic>[
        <String, dynamic>{
          'date': '2026-11-11T00:00:00.000Z',
          'weight_kg': 79.0,
        },
        <String, dynamic>{
          'date': '2026-11-18T00:00:00.000Z',
          'weight_kg': 78.6,
        },
      ];
      await env.datasource.saveMetric({
        'date': '2026-11-18',
        'weight_kg': 78.0,
      });
      expect(env.storage.cache['metrics_weight_history'], [
        {'date': '2026-11-11T00:00:00.000Z', 'weight_kg': 79.0},
        saved,
      ]);
    },
  );

  test('saving a new date still adds it to the cached history', () async {
    final saved = <String, Object?>{
      'id': 'm-3',
      'date': '2026-11-25',
      'weight_kg': 77.5,
    };
    final env = _env(saved);
    env.storage.cache['metrics_weight_history'] = <dynamic>[
      <String, dynamic>{'date': '2026-11-18', 'weight_kg': 78.6},
    ];
    await env.datasource.saveMetric({'date': '2026-11-25', 'weight_kg': 77.5});
    expect(env.storage.cache['metrics_weight_history'], [
      saved,
      {'date': '2026-11-18', 'weight_kg': 78.6},
    ]);
  });

  // `_dayOf` reads the first ten characters of a date string; anything shorter
  // or missing has no day and must neither match another entry nor throw.
  group('a saved or cached date without a full day', () {
    final cachedHistory = <dynamic>[
      <String, dynamic>{'date': '2026-11-18', 'weight_kg': 78.6},
      <String, dynamic>{'date': '2026-11-11T00:00:00.000Z', 'weight_kg': 79.0},
    ];

    for (final (name, saved) in <(String, Map<String, Object?>)>[
      ('short date', {'id': 'm-4', 'date': '2026-11', 'weight_kg': 77.0}),
      ('empty date', {'id': 'm-5', 'date': '', 'weight_kg': 77.0}),
      ('null date', {'id': 'm-6', 'date': null, 'weight_kg': 77.0}),
      ('no date', {'id': 'm-7', 'weight_kg': 77.0}),
    ]) {
      test('$name: added in front, no cached day replaced', () async {
        final env = _env(saved);
        env.storage.cache['metrics_weight_history'] = <dynamic>[
          ...cachedHistory,
        ];
        await env.datasource.saveMetric({
          'date': '2026-11-18',
          'weight_kg': 77.0,
        });
        expect(env.storage.cache['metrics_weight_history'], [
          saved,
          ...cachedHistory,
        ]);
      });
    }

    test(
      'cached entries with a short or missing date are never replaced',
      () async {
        final saved = <String, Object?>{
          'id': 'm-9',
          'date': '2026-11-18',
          'weight_kg': 77.0,
        };
        final env = _env(saved);
        final odd = <dynamic>[
          <String, dynamic>{'date': '2026-11', 'weight_kg': 70.0},
          <String, dynamic>{'weight_kg': 71.0},
          <String, dynamic>{'date': null, 'weight_kg': 72.0},
          <String, dynamic>{'date': 20261118, 'weight_kg': 73.0},
        ];
        env.storage.cache['metrics_weight_history'] = <dynamic>[...odd];
        await env.datasource.saveMetric({
          'date': '2026-11-18',
          'weight_kg': 77.0,
        });
        expect(env.storage.cache['metrics_weight_history'], [saved, ...odd]);
      },
    );
  });

  // M-6: the save did not refresh the cache of its date, so a later load of
  // that date without connection filled the form with the values from before
  // the save.
  group('the cache of the saved date', () {
    test(
      'saving a date writes metrics_latest_<date> with the answer',
      () async {
        final saved = <String, Object?>{
          'id': 'm-11',
          'date': '2026-11-20T00:00:00.000Z',
          'weight_kg': 80.0,
          'waist_cm': 82.0,
        };
        final env = _env(saved);
        env.storage.cache['metrics_latest_2026-11-20'] = <String, dynamic>{
          'id': 'm-11',
          'date': '2026-11-20T00:00:00.000Z',
          'weight_kg': 80.0,
          'waist_cm': 80.0,
        };
        await env.datasource.saveMetric({
          'date': '2026-11-20',
          'waist_cm': 82.0,
        });
        expect(env.storage.cache['metrics_latest_2026-11-20'], saved);
      },
    );

    test('only that date key is added to the keys the save wrote', () async {
      final env = _env({'id': 'm-12', 'date': '2026-11-20', 'weight_kg': 80.0});
      await env.datasource.saveMetric({
        'date': '2026-11-20',
        'weight_kg': 80.0,
      });
      expect(env.storage.cache.keys.toSet(), {
        'metrics_latest',
        'home_latest_metric',
        'metrics_weight_history',
        'metrics_latest_2026-11-20',
      });
    });

    test('a later load of that date without connection reads the saved '
        'values', () async {
      final saved = <String, Object?>{
        'id': 'm-13',
        'date': '2026-11-20T00:00:00.000Z',
        'waist_cm': 82.0,
      };
      final env = _env(saved);
      await env.datasource.saveMetric({'date': '2026-11-20', 'waist_cm': 82.0});
      env.adapter.offline = true;
      final model = await env.datasource.getLatestMetric(date: '2026-11-20');
      expect(model?.waistCm, 82.0);
    });
  });

  test('a saved muscle_mass_kg: null stays null in the answer and the cache, '
      'never 0', () async {
    final saved = <String, Object?>{
      'id': 'm-10',
      'date': '2026-11-18',
      'weight_kg': 78.6,
      'muscle_mass_kg': null,
    };
    final env = _env(saved);
    final model = await env.datasource.saveMetric({
      'date': '2026-11-18',
      'weight_kg': 78.6,
      'muscle_mass_kg': null,
    });
    expect(model.muscleMassKg, isNull);
    for (final key in ['metrics_latest', 'home_latest_metric']) {
      final cached = env.storage.getCachedMap(key);
      expect(cached, isNotNull, reason: key);
      expect(cached!.containsKey('muscle_mass_kg'), isTrue, reason: key);
      expect(cached['muscle_mass_kg'], isNull, reason: key);
      expect(
        BodyMetricModel.fromJson(cached).muscleMassKg,
        isNull,
        reason: key,
      );
    }
  });
}
