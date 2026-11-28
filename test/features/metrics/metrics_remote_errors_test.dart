// L4-I1: the metrics datasource used to swallow every error and return
// null / [] for `/metrics/latest` and `/metrics/weight-history`, so «Progreso»
// could not tell "no records" from "request failed". It now propagates the
// DioException (as the diets datasource does) and keeps:
//   * 200 with `data: null` / `data: []` (what the API answers when the user
//     has no records) → null / [];
//   * 404 on `/metrics/latest` → null (legacy "no record" answer, as diets);
//   * offline with a cached copy → the cached copy.
// The other readers keep their visible behaviour: the day form
// (MetricsLoadRequested) and ProfileBloc.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/network_utils.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/metrics/data/datasources/metrics_remote_datasource.dart';
import 'package:exom_app/features/metrics/data/repositories/metrics_repository_impl.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the fake server does for one path.
sealed class _Reply {
  const _Reply();
}

class _Ok extends _Reply {
  const _Ok(this.data);
  final Object? data;
}

class _Status extends _Reply {
  const _Status(this.code);
  final int code;
}

class _Fail extends _Reply {
  const _Fail(this.type);
  final DioExceptionType type;
}

/// A 200 whose body is sent as is (e.g. a captive portal's HTML page).
class _Raw extends _Reply {
  const _Raw(this.body, {this.contentType = Headers.jsonContentType});
  final String body;
  final String contentType;
}

class _Adapter implements HttpClientAdapter {
  final replies = <String, _Reply>{};
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final reply = replies[options.path] ?? const _Status(500);
    switch (reply) {
      case _Ok(:final data):
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': data,
            'timestamp': '2026-11-19T10:00:00.000Z',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      case _Status(:final code):
        return ResponseBody.fromString(
          jsonEncode({'success': false, 'statusCode': code}),
          code,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      case _Fail(:final type):
        throw DioException(requestOptions: options, type: type);
      case _Raw(:final body, :final contentType):
        return ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentTypeHeader: [contentType],
          },
        );
    }
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

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  final profile = _Profile();

  @override
  Future<ProfileEntity> getProfile() async => profile;
}

const _latestPath = '/metrics/latest';
const _historyPath = '/metrics/weight-history';

const _latestJson = <String, Object?>{
  'id': 'm-1',
  'date': '2026-11-18',
  'weight_kg': 78.6,
  'waist_cm': 80,
};

const _historyJson = <Map<String, Object?>>[
  {'date': '2026-11-11', 'weight_kg': 79.0},
  {'date': '2026-11-18', 'weight_kg': 78.6},
];

class _Env {
  _Env() {
    api.dio.httpClientAdapter = adapter;
  }

  final adapter = _Adapter();
  final storage = _Storage();
  final api = ApiClient(
    useAuth: false,
    baseUrl: 'https://exom.test.invalid/api/v1',
  );

  late final datasource = MetricsRemoteDataSourceImpl(api, storage);
  late final repository = MetricsRepositoryImpl(datasource);

  MetricsBloc metricsBloc() => MetricsBloc(
    saveMetricUseCase: SaveMetricUseCase(repository),
    metricsRepository: repository,
  );

  ProfileBloc profileBloc() {
    final profiles = _ProfileRepository();
    return ProfileBloc(
      getProfileUseCase: GetProfileUseCase(profiles),
      updateProfileUseCase: UpdateProfileUseCase(profiles),
      uploadAvatarUseCase: UploadAvatarUseCase(profiles),
      metricsRepository: repository,
    );
  }

  void reply(String path, _Reply reply) => adapter.replies[path] = reply;
}

_Env _env() {
  final env = _Env();
  addTearDown(() => env.api.dio.close(force: true));
  return env;
}

Matcher _dioError({required bool offline, int? status}) => isA<DioException>()
    .having(isOfflineError, 'offline', offline)
    .having((e) => e.response?.statusCode, 'status', status);

const _offlineTypes = [
  DioExceptionType.connectionError,
  DioExceptionType.connectionTimeout,
  DioExceptionType.receiveTimeout,
];

void main() {
  group('datasource /metrics/latest', () {
    test('200 with data null (API answer with no records) → null', () async {
      final env = _env()..reply(_latestPath, const _Ok(null));
      expect(await env.datasource.getLatestMetric(), isNull);
    });

    test('200 with a record → the record, cached', () async {
      final env = _env()..reply(_latestPath, const _Ok(_latestJson));
      final metric = await env.datasource.getLatestMetric();
      expect(metric?.weightKg, 78.6);
      expect(env.storage.cache['metrics_latest'], isNotNull);
    });

    test('404 → null (no record)', () async {
      final env = _env()..reply(_latestPath, const _Status(404));
      expect(await env.datasource.getLatestMetric(), isNull);
    });

    for (final code in [500, 503]) {
      test('$code → throws, not null', () async {
        final env = _env()..reply(_latestPath, _Status(code));
        await expectLater(
          env.datasource.getLatestMetric(),
          throwsA(_dioError(offline: false, status: code)),
        );
      });
    }

    test(
      '5xx with a cached copy still throws (cache is offline-only)',
      () async {
        final env = _env()..reply(_latestPath, const _Status(500));
        env.storage.cache['metrics_latest'] = Map<String, dynamic>.from(
          _latestJson,
        );
        await expectLater(
          env.datasource.getLatestMetric(),
          throwsA(_dioError(offline: false, status: 500)),
        );
      },
    );

    for (final type in _offlineTypes) {
      test('${type.name} without cache → throws an offline error', () async {
        final env = _env()..reply(_latestPath, _Fail(type));
        await expectLater(
          env.datasource.getLatestMetric(),
          throwsA(_dioError(offline: true)),
        );
      });
    }

    test('offline with cache → cached record (unchanged)', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError));
      env.storage.cache['metrics_latest'] = Map<String, dynamic>.from(
        _latestJson,
      );
      final metric = await env.datasource.getLatestMetric();
      expect(metric?.id, 'm-1');
    });
  });

  group('datasource /metrics/weight-history', () {
    test('200 with [] (API answer with no records) → []', () async {
      final env = _env()..reply(_historyPath, const _Ok(<Object?>[]));
      expect(await env.datasource.getWeightHistory(), isEmpty);
    });

    test('200 with points → points', () async {
      final env = _env()..reply(_historyPath, const _Ok(_historyJson));
      final history = await env.datasource.getWeightHistory();
      expect(history.map((m) => m.weightKg), [79.0, 78.6]);
    });

    test('500 → throws, not []', () async {
      final env = _env()..reply(_historyPath, const _Status(500));
      await expectLater(
        env.datasource.getWeightHistory(),
        throwsA(_dioError(offline: false, status: 500)),
      );
    });

    for (final type in _offlineTypes) {
      test('${type.name} without cache → throws an offline error', () async {
        final env = _env()..reply(_historyPath, _Fail(type));
        await expectLater(
          env.datasource.getWeightHistory(),
          throwsA(_dioError(offline: true)),
        );
      });
    }

    test('offline with cache → cached points (unchanged)', () async {
      final env = _env()
        ..reply(_historyPath, const _Fail(DioExceptionType.connectionError));
      env.storage.cache['metrics_weight_history'] = <Object?>[
        for (final item in _historyJson) Map<String, dynamic>.from(item),
      ];
      final history = await env.datasource.getWeightHistory();
      expect(history, hasLength(2));
    });
  });

  group('repository', () {
    test('propagates the datasource error', () async {
      final env = _env()
        ..reply(_latestPath, const _Status(500))
        ..reply(_historyPath, const _Status(502));
      await expectLater(
        env.repository.getLatestMetric(),
        throwsA(_dioError(offline: false, status: 500)),
      );
      await expectLater(
        env.repository.getWeightHistory(),
        throwsA(_dioError(offline: false, status: 502)),
      );
    });

    test('maps legitimate empty answers to null / []', () async {
      final env = _env()
        ..reply(_latestPath, const _Ok(null))
        ..reply(_historyPath, const _Ok(<Object?>[]));
      expect(await env.repository.getLatestMetric(), isNull);
      expect(await env.repository.getWeightHistory(), isEmpty);
    });
  });

  group('MetricsBloc history («Progreso»)', () {
    Future<MetricsState> load(_Env env) async {
      final bloc = env.metricsBloc();
      addTearDown(bloc.close);
      bloc.add(const MetricsHistoryRequested());
      return bloc.stream.firstWhere(
        (s) => s is MetricsHistoryLoaded || s is MetricsHistoryFailure,
      );
    }

    test('5xx reaches MetricsHistoryFailure(offline: false)', () async {
      final env = _env()
        ..reply(_latestPath, const _Ok(_latestJson))
        ..reply(_historyPath, const _Status(500));
      final state = await load(env);
      expect(
        state,
        isA<MetricsHistoryFailure>().having((s) => s.offline, 'offline', false),
      );
    });

    test(
      'no connection reaches MetricsHistoryFailure(offline: true)',
      () async {
        final env = _env()
          ..reply(_latestPath, const _Fail(DioExceptionType.connectionError))
          ..reply(_historyPath, const _Fail(DioExceptionType.connectionError));
        final state = await load(env);
        expect(
          state,
          isA<MetricsHistoryFailure>().having(
            (s) => s.offline,
            'offline',
            true,
          ),
        );
      },
    );

    test('a real empty account is MetricsHistoryLoaded([], null)', () async {
      final env = _env()
        ..reply(_latestPath, const _Ok(null))
        ..reply(_historyPath, const _Ok(<Object?>[]));
      final state = await load(env);
      expect(
        state,
        isA<MetricsHistoryLoaded>()
            .having((s) => s.weightHistory, 'weightHistory', isEmpty)
            .having((s) => s.latest, 'latest', isNull),
      );
    });
  });

  // L6-UX7 (a): the day form used to read a failed load as a day without
  // metrics (MetricsLoaded(null)) and offered to save over it. Only «no
  // record» (200 with data null, 404) is an empty day; a failure is reported.
  group('day form (MetricsLoadRequested): a failure is not an empty day', () {
    for (final (name, reply, offline) in <(String, _Reply, bool)>[
      ('500', const _Status(500), false),
      ('no connection', const _Fail(DioExceptionType.connectionError), true),
      ('timeout', const _Fail(DioExceptionType.receiveTimeout), true),
    ]) {
      test('$name → MetricsLoadFailed (offline: $offline)', () async {
        final env = _env()..reply(_latestPath, reply);
        final bloc = env.metricsBloc();
        addTearDown(bloc.close);
        bloc.add(const MetricsLoadRequested(date: '2026-11-19'));
        final state = await bloc.stream.firstWhere(
          (s) => s is MetricsLoaded || s is MetricsLoadFailed,
        );
        expect(
          state,
          isA<MetricsLoadFailed>()
              .having((s) => s.date, 'date', '2026-11-19')
              .having((s) => s.offline, 'offline', offline)
              .having((s) => s.sessionChanged, 'sessionChanged', isFalse),
        );
      });
    }

    for (final (name, reply) in <(String, _Reply)>[
      ('200 with data null', const _Ok(null)),
      ('404', const _Status(404)),
    ]) {
      test('$name → MetricsLoaded(null): a day without a record', () async {
        final env = _env()..reply(_latestPath, reply);
        final bloc = env.metricsBloc();
        addTearDown(bloc.close);
        bloc.add(const MetricsLoadRequested(date: '2026-11-19'));
        final state = await bloc.stream.firstWhere(
          (s) => s is MetricsLoaded || s is MetricsLoadFailed,
        );
        expect(
          state,
          isA<MetricsLoaded>().having((s) => s.current, 'current', isNull),
        );
      });
    }
  });

  group('ProfileBloc keeps loading the profile when metrics fail', () {
    Future<ProfileState> load(_Env env) async {
      final bloc = env.profileBloc();
      addTearDown(bloc.close);
      bloc.add(const ProfileLoadRequested());
      return bloc.stream.firstWhere(
        (s) => s is ProfileLoaded || s is ProfileError,
      );
    }

    test('5xx on both metric calls → ProfileLoaded with [] / null', () async {
      final env = _env()
        ..reply(_latestPath, const _Status(500))
        ..reply(_historyPath, const _Status(500));
      final state = await load(env);
      expect(
        state,
        isA<ProfileLoaded>()
            .having((s) => s.weightHistory, 'weightHistory', isEmpty)
            .having((s) => s.latestMetric, 'latestMetric', isNull),
      );
    });

    test('offline without cache → ProfileLoaded with [] / null', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError))
        ..reply(_historyPath, const _Fail(DioExceptionType.receiveTimeout));
      final state = await load(env);
      expect(state, isA<ProfileLoaded>());
    });

    test('one metric failing keeps the other one', () async {
      final env = _env()
        ..reply(_latestPath, const _Status(500))
        ..reply(_historyPath, const _Ok(_historyJson));
      final state = await load(env);
      expect(
        state,
        isA<ProfileLoaded>()
            .having((s) => s.weightHistory, 'weightHistory', hasLength(2))
            .having((s) => s.latestMetric, 'latestMetric', isNull),
      );
    });

    test('data loads as before', () async {
      final env = _env()
        ..reply(_latestPath, const _Ok(_latestJson))
        ..reply(_historyPath, const _Ok(_historyJson));
      final state = await load(env);
      expect(
        state,
        isA<ProfileLoaded>()
            .having((s) => s.latestMetric?.weightKg, 'latest kg', 78.6)
            .having((s) => s.weightHistory, 'weightHistory', hasLength(2)),
      );
    });
  });

  // Review 3, D5: a 200 that is not the API envelope (a captive portal's HTML
  // page, a body of another shape) is an unexpected answer, not an account
  // without records. `data: null` / `data: []` stay empty.
  group('datasource: a 200 with an unexpected body is an error', () {
    const html = _Raw(
      '<html><body>Wi-Fi login</body></html>',
      contentType: 'text/html',
    );
    final unexpected = <String, _Reply>{
      'HTML page': html,
      'top-level list': const _Raw('[]'),
      'envelope without data': const _Raw('{"success":true}'),
      'data of another type': const _Ok('no-records'),
    };

    unexpected.forEach((name, reply) {
      test('/metrics/latest, $name → throws, not null', () async {
        final env = _env()..reply(_latestPath, reply);
        await expectLater(
          env.datasource.getLatestMetric(),
          throwsA(isA<FormatException>()),
        );
        expect(env.storage.cache, isEmpty);
      });
    });

    final unexpectedHistory = <String, _Reply>{
      ...unexpected,
      'data is a map': const _Ok(<String, Object?>{}),
    };
    unexpectedHistory.forEach((name, reply) {
      test('/metrics/weight-history, $name → throws, not []', () async {
        final env = _env()..reply(_historyPath, reply);
        await expectLater(
          env.datasource.getWeightHistory(),
          throwsA(isA<FormatException>()),
        );
        expect(env.storage.cache, isEmpty);
      });
    });

    test('/metrics/latest with data: {} is still a record answer', () async {
      final env = _env()..reply(_latestPath, const _Ok(<String, Object?>{}));
      expect(await env.datasource.getLatestMetric(), isNotNull);
    });

    test('/metrics/weight-history with data: null stays []', () async {
      final env = _env()..reply(_historyPath, const _Ok(null));
      expect(await env.datasource.getWeightHistory(), isEmpty);
    });

    test('«Progreso» shows an error, not the empty account', () async {
      final env = _env()
        ..reply(_latestPath, html)
        ..reply(_historyPath, html);
      final bloc = env.metricsBloc();
      addTearDown(bloc.close);
      bloc.add(const MetricsHistoryRequested());
      final state = await bloc.stream.firstWhere(
        (s) => s is MetricsHistoryLoaded || s is MetricsHistoryFailure,
      );
      expect(
        state,
        isA<MetricsHistoryFailure>().having((s) => s.offline, 'offline', false),
      );
    });

    test('ProfileBloc keeps loading the profile', () async {
      final env = _env()
        ..reply(_latestPath, html)
        ..reply(_historyPath, html);
      final bloc = env.profileBloc();
      addTearDown(bloc.close);
      bloc.add(const ProfileLoadRequested());
      final state = await bloc.stream.firstWhere(
        (s) => s is ProfileLoaded || s is ProfileError,
      );
      expect(state, isA<ProfileLoaded>());
    });
  });

  // Review 3, D4: one half failing must not hide the other one, and must not
  // be shown as empty either.
  group('MetricsBloc «Progreso» with only one half available', () {
    Future<MetricsState> load(_Env env) async {
      final bloc = env.metricsBloc();
      addTearDown(bloc.close);
      bloc.add(const MetricsHistoryRequested());
      return bloc.stream.firstWhere(
        (s) => s is MetricsHistoryLoaded || s is MetricsHistoryFailure,
      );
    }

    test('offline with only the history cached → the history', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError))
        ..reply(_historyPath, const _Fail(DioExceptionType.connectionError));
      env.storage.cache['metrics_weight_history'] = <Object?>[
        for (final item in _historyJson) Map<String, dynamic>.from(item),
      ];
      expect(
        await load(env),
        isA<MetricsHistoryLoaded>()
            .having((s) => s.weightHistory, 'weightHistory', hasLength(2))
            .having((s) => s.latest, 'latest', isNull),
      );
    });

    test('latest failing with weights in the history → the history', () async {
      final env = _env()
        ..reply(_latestPath, const _Status(500))
        ..reply(_historyPath, const _Ok(_historyJson));
      expect(
        await load(env),
        isA<MetricsHistoryLoaded>()
            .having((s) => s.weightHistory, 'weightHistory', hasLength(2))
            .having((s) => s.latest, 'latest', isNull),
      );
    });

    test('latest failing with an empty history is a failure', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError))
        ..reply(_historyPath, const _Ok(<Object?>[]));
      expect(
        await load(env),
        isA<MetricsHistoryFailure>().having((s) => s.offline, 'offline', true),
      );
    });

    // Showing the latest record alone would claim "no weight registered" for
    // the half that failed: it stays a failure.
    test('offline with only the latest record cached is a failure', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError))
        ..reply(_historyPath, const _Fail(DioExceptionType.connectionError));
      env.storage.cache['metrics_latest'] = Map<String, dynamic>.from(
        _latestJson,
      );
      expect(
        await load(env),
        isA<MetricsHistoryFailure>().having((s) => s.offline, 'offline', true),
      );
    });

    test('a session change in the latest half is a failure', () async {
      final bloc = MetricsBloc(
        saveMetricUseCase: SaveMetricUseCase(_LatestSessionChangedRepository()),
        metricsRepository: _LatestSessionChangedRepository(),
      );
      addTearDown(bloc.close);
      bloc.add(const MetricsHistoryRequested());
      final state = await bloc.stream.firstWhere(
        (s) => s is MetricsHistoryLoaded || s is MetricsHistoryFailure,
      );
      expect(state, isA<MetricsHistoryFailure>());
    });
  });

  // L4-I12: «Progreso» must know when what it shows comes from the offline
  // cache, and why the latest record is missing. The sourced reads share the
  // network/cache logic of the plain ones and only add the origin.
  group('datasource sourced reads report the origin', () {
    test('latest from the network → fromCache false', () async {
      final env = _env()..reply(_latestPath, const _Ok(_latestJson));
      final read = await env.datasource.getLatestMetricWithSource();
      expect(read.value?.id, 'm-1');
      expect(read.fromCache, isFalse);
      expect(env.storage.cache['metrics_latest'], isNotNull);
    });

    test('latest 200 with data null / 404 → null, fromCache false', () async {
      for (final reply in <_Reply>[const _Ok(null), const _Status(404)]) {
        final env = _env()..reply(_latestPath, reply);
        final read = await env.datasource.getLatestMetricWithSource();
        expect(read.value, isNull);
        expect(read.fromCache, isFalse);
      }
    });

    test('latest offline with cache → cached record, fromCache true', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError));
      env.storage.cache['metrics_latest'] = Map<String, dynamic>.from(
        _latestJson,
      );
      final read = await env.datasource.getLatestMetricWithSource();
      expect(read.value?.id, 'm-1');
      expect(read.fromCache, isTrue);
    });

    test('latest errors are rethrown as by the plain read', () async {
      final server = _env()..reply(_latestPath, const _Status(500));
      server.storage.cache['metrics_latest'] = Map<String, dynamic>.from(
        _latestJson,
      );
      await expectLater(
        server.datasource.getLatestMetricWithSource(),
        throwsA(_dioError(offline: false, status: 500)),
      );
      final offline = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError));
      await expectLater(
        offline.datasource.getLatestMetricWithSource(),
        throwsA(_dioError(offline: true)),
      );
      final format = _env()..reply(_latestPath, const _Raw('[]'));
      await expectLater(
        format.datasource.getLatestMetricWithSource(),
        throwsA(isA<FormatException>()),
      );
    });

    test('history from the network → fromCache false, cached', () async {
      final env = _env()..reply(_historyPath, const _Ok(_historyJson));
      final read = await env.datasource.getWeightHistoryWithSource();
      expect(read.value.map((m) => m.weightKg), [79.0, 78.6]);
      expect(read.fromCache, isFalse);
      expect(env.storage.cache['metrics_weight_history'], hasLength(2));
    });

    test('history offline with cache → cached points, fromCache true', () async {
      final env = _env()
        ..reply(_historyPath, const _Fail(DioExceptionType.connectionError));
      env.storage.cache['metrics_weight_history'] = <Object?>[
        for (final item in _historyJson) Map<String, dynamic>.from(item),
      ];
      final read = await env.datasource.getWeightHistoryWithSource();
      expect(read.value, hasLength(2));
      expect(read.fromCache, isTrue);
    });

    test('history errors are rethrown as by the plain read', () async {
      final server = _env()..reply(_historyPath, const _Status(500));
      await expectLater(
        server.datasource.getWeightHistoryWithSource(),
        throwsA(_dioError(offline: false, status: 500)),
      );
      final offline = _env()
        ..reply(_historyPath, const _Fail(DioExceptionType.receiveTimeout));
      await expectLater(
        offline.datasource.getWeightHistoryWithSource(),
        throwsA(_dioError(offline: true)),
      );
      final format = _env()..reply(_historyPath, const _Ok('no-records'));
      await expectLater(
        format.datasource.getWeightHistoryWithSource(),
        throwsA(isA<FormatException>()),
      );
      expect(format.storage.cache, isEmpty);
    });
  });

  group('repository sourced reads keep the origin', () {
    test('network reads → entities, fromCache false', () async {
      final env = _env()
        ..reply(_latestPath, const _Ok(_latestJson))
        ..reply(_historyPath, const _Ok(_historyJson));
      final latest = await env.repository.getLatestMetricWithSource();
      final history = await env.repository.getWeightHistoryWithSource();
      expect(latest.value?.weightKg, 78.6);
      expect(latest.fromCache, isFalse);
      expect(history.value.map((m) => m.weightKg), [79.0, 78.6]);
      expect(history.fromCache, isFalse);
    });

    test('cached reads → entities, fromCache true', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError))
        ..reply(_historyPath, const _Fail(DioExceptionType.connectionError));
      env.storage.cache['metrics_latest'] = Map<String, dynamic>.from(
        _latestJson,
      );
      env.storage.cache['metrics_weight_history'] = <Object?>[
        for (final item in _historyJson) Map<String, dynamic>.from(item),
      ];
      final latest = await env.repository.getLatestMetricWithSource();
      final history = await env.repository.getWeightHistoryWithSource();
      expect(latest.value?.id, 'm-1');
      expect(latest.fromCache, isTrue);
      expect(history.value, hasLength(2));
      expect(history.fromCache, isTrue);
    });
  });

  group('MetricsBloc «Progreso» reports origin and missing latest', () {
    Future<MetricsState> load(_Env env) async {
      final bloc = env.metricsBloc();
      addTearDown(bloc.close);
      bloc.add(const MetricsHistoryRequested());
      return bloc.stream.firstWhere(
        (s) => s is MetricsHistoryLoaded || s is MetricsHistoryFailure,
      );
    }

    Matcher loaded({
      required bool historyFromCache,
      required bool latestFromCache,
      required MetricsLatestUnavailability unavailability,
      required bool hasLatest,
    }) => isA<MetricsHistoryLoaded>()
        .having((s) => s.weightHistory, 'weightHistory', hasLength(2))
        .having((s) => s.latest != null, 'has latest', hasLatest)
        .having((s) => s.historyFromCache, 'historyFromCache', historyFromCache)
        .having((s) => s.latestFromCache, 'latestFromCache', latestFromCache)
        .having(
          (s) => s.latestUnavailability,
          'latestUnavailability',
          unavailability,
        );

    test('both from the network → no marks', () async {
      final env = _env()
        ..reply(_latestPath, const _Ok(_latestJson))
        ..reply(_historyPath, const _Ok(_historyJson));
      expect(
        await load(env),
        loaded(
          historyFromCache: false,
          latestFromCache: false,
          unavailability: MetricsLatestUnavailability.none,
          hasLatest: true,
        ),
      );
    });

    test('offline with both cached → both marked as cache', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError))
        ..reply(_historyPath, const _Fail(DioExceptionType.connectionError));
      env.storage.cache['metrics_latest'] = Map<String, dynamic>.from(
        _latestJson,
      );
      env.storage.cache['metrics_weight_history'] = <Object?>[
        for (final item in _historyJson) Map<String, dynamic>.from(item),
      ];
      expect(
        await load(env),
        loaded(
          historyFromCache: true,
          latestFromCache: true,
          unavailability: MetricsLatestUnavailability.none,
          hasLatest: true,
        ),
      );
    });

    test('offline with only the history cached → latest offline', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionError))
        ..reply(_historyPath, const _Fail(DioExceptionType.connectionError));
      env.storage.cache['metrics_weight_history'] = <Object?>[
        for (final item in _historyJson) Map<String, dynamic>.from(item),
      ];
      expect(
        await load(env),
        loaded(
          historyFromCache: true,
          latestFromCache: false,
          unavailability: MetricsLatestUnavailability.offline,
          hasLatest: false,
        ),
      );
    });

    test('latest offline, history from the network → latest offline', () async {
      final env = _env()
        ..reply(_latestPath, const _Fail(DioExceptionType.connectionTimeout))
        ..reply(_historyPath, const _Ok(_historyJson));
      expect(
        await load(env),
        loaded(
          historyFromCache: false,
          latestFromCache: false,
          unavailability: MetricsLatestUnavailability.offline,
          hasLatest: false,
        ),
      );
    });

    for (final entry in <String, _Reply>{
      '5xx': const _Status(503),
      'unexpected body (FormatException)': const _Raw('[]'),
    }.entries) {
      test('latest ${entry.key} with a history → latest error', () async {
        final env = _env()
          ..reply(_latestPath, entry.value)
          ..reply(_historyPath, const _Ok(_historyJson));
        expect(
          await load(env),
          loaded(
            historyFromCache: false,
            latestFromCache: false,
            unavailability: MetricsLatestUnavailability.error,
            hasLatest: false,
          ),
        );
      });
    }

    test('latest 404 is "no record", not unavailable', () async {
      final env = _env()
        ..reply(_latestPath, const _Status(404))
        ..reply(_historyPath, const _Ok(_historyJson));
      expect(
        await load(env),
        loaded(
          historyFromCache: false,
          latestFromCache: false,
          unavailability: MetricsLatestUnavailability.none,
          hasLatest: false,
        ),
      );
    });
  });

  group('ProfileBloc session change is still an error', () {
    test('LocalSessionChanged from a metric call → ProfileError', () async {
      final profiles = _ProfileRepository();
      final bloc = ProfileBloc(
        getProfileUseCase: GetProfileUseCase(profiles),
        updateProfileUseCase: UpdateProfileUseCase(profiles),
        uploadAvatarUseCase: UploadAvatarUseCase(profiles),
        metricsRepository: _SessionChangedRepository(),
      );
      addTearDown(bloc.close);
      bloc.add(const ProfileLoadRequested());
      final state = await bloc.stream.firstWhere(
        (s) => s is ProfileLoaded || s is ProfileError,
      );
      expect(state, isA<ProfileError>());
    });
  });
}

class _SessionChangedRepository extends MetricsRepositoryImpl {
  _SessionChangedRepository() : super(_NeverDataSource());

  @override
  Future<List<BodyMetricEntity>> getWeightHistory() async =>
      throw const LocalSessionChanged();

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async => null;

  @override
  Future<MetricsRead<List<BodyMetricEntity>>>
  getWeightHistoryWithSource() async => throw const LocalSessionChanged();

  @override
  Future<MetricsRead<BodyMetricEntity?>> getLatestMetricWithSource() async =>
      const MetricsRead(null);
}

class _NeverDataSource extends Fake implements MetricsRemoteDataSource {}

/// The history (of the previous owner) arrives; the latest call reports the
/// session change.
class _LatestSessionChangedRepository extends MetricsRepositoryImpl {
  _LatestSessionChangedRepository() : super(_NeverDataSource());

  @override
  Future<List<BodyMetricEntity>> getWeightHistory() async => [
    BodyMetricEntity(id: 'a', date: DateTime(2026, 11, 18), weightKg: 91),
  ];

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async =>
      throw const LocalSessionChanged();

  // The «Progreso» load reads through these: same answers, with origin.
  @override
  Future<MetricsRead<List<BodyMetricEntity>>>
  getWeightHistoryWithSource() async => MetricsRead(await getWeightHistory());

  @override
  Future<MetricsRead<BodyMetricEntity?>> getLatestMetricWithSource() async =>
      MetricsRead(await getLatestMetric());
}
