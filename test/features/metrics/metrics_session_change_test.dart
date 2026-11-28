// L4-I1 (review 3, D1): the local session changes (logout or user switch)
// while `/metrics/latest` or `/metrics/weight-history` is in flight. The real
// auth interceptor rejects the stale answer with DioException(cancel); the
// metrics datasource must turn it into LocalSessionChanged, as it did before
// it started rethrowing DioException, so that no reader shows the previous
// session's data or applies an answer from an older session generation.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
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

const _latestPath = '/metrics/latest';
const _historyPath = '/metrics/weight-history';

const _latestOfA = <String, Object?>{
  'id': 'a-latest',
  'date': '2026-11-18',
  'weight_kg': 91.0,
  'waist_cm': 95,
};

const _historyOfA = <Map<String, Object?>>[
  {'date': '2026-11-11', 'weight_kg': 92.0},
  {'date': '2026-11-18', 'weight_kg': 91.0},
];

/// One Firebase-like session source shared by the auth interceptor and the
/// local storage, as in production.
class _Sessions implements AuthTokenProvider {
  LocalAuthSession? session = const LocalAuthSession(uid: 'user-a');

  @override
  LocalAuthSession? get currentSession => session;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      '${session?.uid}-token';

  void switchTo(String uid) =>
      session = LocalAuthSession(uid: uid, generation: 1);
}

/// Real session stamp; in-memory cache instead of Hive.
class _Storage extends LocalStorage {
  _Storage(_Sessions sessions)
    : super(currentSession: () => sessions.currentSession);

  final cache = <String, Object?>{};

  @override
  Future<void> cacheData(String key, dynamic value) async {
    guardSession();
    cache[key] = value;
  }

  @override
  Map<String, dynamic>? getCachedMap(String key) {
    guardSession();
    final value = cache[key];
    return value is Map<String, dynamic> ? value : null;
  }

  @override
  List<dynamic>? getCachedList(String key) {
    guardSession();
    final value = cache[key];
    return value is List<dynamic> ? value : null;
  }
}

/// Answers every path with the previous session's data; a held path waits
/// until the test releases it, so the session can change while in flight.
class _Adapter implements HttpClientAdapter {
  final held = <String>{};
  final reached = <String, Completer<void>>{};
  final gates = <String, Completer<void>>{};

  void hold(String path) {
    held.add(path);
    reached[path] = Completer<void>();
    gates[path] = Completer<void>();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (held.contains(path)) {
      reached[path]!.complete();
      await gates[path]!.future;
    }
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': path == _historyPath ? _historyOfA : _latestOfA,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> getProfile() async => _Profile();
}

class _Env {
  _Env() {
    api.dio.httpClientAdapter = adapter;
  }

  final sessions = _Sessions();
  late final storage = _Storage(sessions);
  final adapter = _Adapter();
  late final api = ApiClient(
    baseUrl: 'https://exom.test.invalid/api/v1',
    authTokenProvider: sessions,
  );
  late final datasource = MetricsRemoteDataSourceImpl(api, storage);
  late final repository = MetricsRepositoryImpl(datasource);

  /// Holds [path], waits until its request is in flight, switches the
  /// session to user B and lets user A's answer arrive.
  Future<void> switchWhileInFlight(String path) async {
    await adapter.reached[path]!.future;
    sessions.switchTo('user-b');
    adapter.gates[path]!.complete();
  }

  ProfileBloc profileBloc({MetricsRepository? metrics}) {
    final profiles = _ProfileRepository();
    final bloc = ProfileBloc(
      getProfileUseCase: GetProfileUseCase(profiles),
      updateProfileUseCase: UpdateProfileUseCase(profiles),
      uploadAvatarUseCase: UploadAvatarUseCase(profiles),
      metricsRepository: metrics ?? repository,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  MetricsBloc metricsBloc({MetricsRepository? metrics}) {
    final bloc = MetricsBloc(
      saveMetricUseCase: SaveMetricUseCase(metrics ?? repository),
      metricsRepository: metrics ?? repository,
    );
    addTearDown(bloc.close);
    return bloc;
  }
}

_Env _env() {
  final env = _Env();
  addTearDown(() => env.api.dio.close(force: true));
  return env;
}

/// A repository whose metric calls fail with [error] (no session change of
/// its own): a cancelled request must never be taken for a network error.
class _FailingRepository extends Fake implements MetricsRepository {
  _FailingRepository(this.error, {this.history = const []});

  final Object error;
  final List<BodyMetricEntity> history;

  @override
  Future<List<BodyMetricEntity>> getWeightHistory() async => history;

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async =>
      throw error;
}

class _FailingHistoryRepository extends Fake implements MetricsRepository {
  _FailingHistoryRepository(this.error);

  final Object error;

  @override
  Future<List<BodyMetricEntity>> getWeightHistory() async => throw error;

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async =>
      BodyMetricEntity(id: 'a', date: DateTime(2026, 11, 18), weightKg: 91);
}

DioException _cancelled(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.cancel,
  message: 'Authentication session changed',
);

void main() {
  group('datasource: session change with the request in flight', () {
    for (final path in [_latestPath, _historyPath]) {
      test('$path → LocalSessionChanged, nothing cached', () async {
        final env = _env()..adapter.hold(path);
        final Future<Object?> call = path == _latestPath
            ? env.datasource.getLatestMetric()
            : env.datasource.getWeightHistory();
        final outcome = call.then<Object?>((value) => value, onError: (e) => e);
        await env.switchWhileInFlight(path);

        expect(await outcome, isA<LocalSessionChanged>());
        expect(env.storage.cache, isEmpty);
      });
    }
  });

  group('ProfileBloc: session change with a metric in flight', () {
    for (final path in [_latestPath, _historyPath]) {
      test('$path → ProfileError, never ProfileLoaded', () async {
        final env = _env()..adapter.hold(path);
        final bloc = env.profileBloc();
        final result = bloc.stream.firstWhere(
          (s) => s is ProfileLoaded || s is ProfileError,
        );
        bloc.add(const ProfileLoadRequested());
        await env.switchWhileInFlight(path);

        expect(await result, isA<ProfileError>());
      });
    }

    for (final path in [_latestPath, _historyPath]) {
      test('a cancelled $path request is not a network error', () async {
        final env = _env();
        final error = _cancelled(path);
        final bloc = env.profileBloc(
          metrics: path == _latestPath
              ? _FailingRepository(error)
              : _FailingHistoryRepository(error),
        );
        final result = bloc.stream.firstWhere(
          (s) => s is ProfileLoaded || s is ProfileError,
        );
        bloc.add(const ProfileLoadRequested());

        expect(await result, isA<ProfileError>());
      });
    }
  });

  group('MetricsBloc «Progreso»: session change with a metric in flight', () {
    for (final path in [_latestPath, _historyPath]) {
      test('$path → MetricsHistoryFailure, no data shown', () async {
        final env = _env()..adapter.hold(path);
        final bloc = env.metricsBloc();
        final result = bloc.stream.firstWhere(
          (s) => s is MetricsHistoryLoaded || s is MetricsHistoryFailure,
        );
        bloc.add(const MetricsHistoryRequested());
        await env.switchWhileInFlight(path);

        expect(await result, isA<MetricsHistoryFailure>());
      });
    }

    test('a cancelled latest request with a loaded history shows no data', () {
      final env = _env();
      final bloc = env.metricsBloc(
        metrics: _FailingRepository(
          _cancelled(_latestPath),
          history: [
            BodyMetricEntity(
              id: 'a',
              date: DateTime(2026, 11, 18),
              weightKg: 91,
            ),
          ],
        ),
      );
      final result = bloc.stream.firstWhere(
        (s) => s is MetricsHistoryLoaded || s is MetricsHistoryFailure,
      );
      bloc.add(const MetricsHistoryRequested());

      return expectLater(result, completion(isA<MetricsHistoryFailure>()));
    });
  });

  // L6-UX7 (a): it used to arrive as Loaded(null), an empty day the form
  // offered to save (with the profile weight) under the new session.
  test('MetricsBloc day form: session change is a load failure, not A nor an '
      'empty day', () async {
    final env = _env()..adapter.hold(_latestPath);
    final bloc = env.metricsBloc();
    final result = bloc.stream.firstWhere(
      (s) => s is MetricsLoaded || s is MetricsLoadFailed,
    );
    bloc.add(const MetricsLoadRequested(date: '2026-11-18'));
    await env.switchWhileInFlight(_latestPath);

    expect(
      await result,
      isA<MetricsLoadFailed>()
          .having((s) => s.sessionChanged, 'sessionChanged', isTrue)
          .having((s) => s.date, 'date', '2026-11-18'),
    );
  });
}
