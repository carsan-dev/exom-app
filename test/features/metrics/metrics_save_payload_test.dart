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
import 'package:flutter_test/flutter_test.dart';

/// Answers every POST /metrics with [saved] and records the request bodies.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.saved);

  final Map<String, Object?> saved;
  final bodies = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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
}
