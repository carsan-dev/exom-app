// Inicio offline (E1 D1): when a request of the Inicio summary fails and the
// data layer answers it from the saved copy, the summary says so, and the
// reason keeps a connectivity failure apart from a rejected or failed request
// (401/403/5xx), which must never read as «Sin conexión».
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:exom_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage extends LocalStorage {
  final cache = <String, dynamic>{};

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
    return value is List ? List<dynamic>.from(value) : null;
  }

  @override
  List<Map<String, dynamic>> getPendingSyncActions() => const [];
}

/// Answers the Inicio requests. [offline] fails every request without a
/// response; [status] answers every request with that HTTP status;
/// [statusFor] does it for one path only.
class _Adapter implements HttpClientAdapter {
  bool offline = false;
  final offlinePaths = <String>{};
  int? status;
  final statusFor = <String, int>{};
  String trainingName = 'Pierna';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline || offlinePaths.contains(options.path)) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final failure = statusFor[options.path] ?? status;
    if (failure != null) {
      return ResponseBody.fromString(
        '{}',
        failure,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final Object? data = switch (options.path) {
      '/trainings/day' => {
        'id': 'training-1',
        'name': trainingName,
        'exercises': const [
          {
            'id': 'te-1',
            'sets': 3,
            'exercise': {'id': 'e-1'},
          },
        ],
      },
      '/diets/today' => {'id': 'diet-1', 'name': 'Dieta'},
      '/streaks/me' => {'current_days': 4},
      '/profile/me' => {'first_name': 'Ana'},
      '/metrics/latest' => {'date': '2026-11-10', 'sleep_hours': 7.5},
      '/progress' => {'exercises_completed': const []},
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _day = DateTime(2026, 11, 18);

({HomeRemoteDataSourceImpl source, _Adapter adapter, _MemoryStorage storage})
_fixture() {
  final adapter = _Adapter();
  final client = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test')
    ..dio.httpClientAdapter = adapter;
  final storage = _MemoryStorage();
  return (
    source: HomeRemoteDataSourceImpl(client, storage),
    adapter: adapter,
    storage: storage,
  );
}

Future<HomeState> _settled(HomeBloc bloc, void Function() act) {
  final next = bloc.stream.firstWhere(
    (s) => s is HomeLoaded || s is HomeRestDay || s is HomeError,
  );
  act();
  return next;
}

String? _refreshErrorOf(HomeState state) => switch (state) {
  HomeLoaded(:final refreshError) => refreshError,
  HomeRestDay(:final refreshError) => refreshError,
  _ => null,
};

void main() {
  group('data layer', () {
    test('every request answered: the summary is not a saved copy', () async {
      final f = _fixture();
      final summary = await f.source.getHomeSummary(date: _day);
      expect(summary.trainingName, 'Pierna');
      expect(summary.staleReason, isNull);
    });

    test(
      'without network the saved copy is served and marked offline',
      () async {
        final f = _fixture();
        await f.source.getHomeSummary(date: _day);
        f.adapter.offline = true;
        final summary = await f.source.getHomeSummary(date: _day);
        expect(summary.trainingName, 'Pierna');
        expect(summary.streakDays, 4);
        expect(summary.staleReason, startsWith('ApiException(0)'));
      },
    );

    test(
      'without network and without a saved copy it is still marked',
      () async {
        final f = _fixture()..adapter.offline = true;
        final summary = await f.source.getHomeSummary(date: _day);
        expect(summary.trainingName, isNull);
        expect(summary.staleReason, startsWith('ApiException(0)'));
      },
    );

    for (final status in [401, 403, 500, 503]) {
      test('a $status serves the saved copy but is not «offline»', () async {
        final f = _fixture();
        await f.source.getHomeSummary(date: _day);
        f.adapter.status = status;
        final summary = await f.source.getHomeSummary(date: _day);
        expect(summary.trainingName, 'Pierna');
        expect(summary.staleReason, startsWith('ApiException($status)'));
      });
    }

    test('a rejected request wins over a connectivity failure', () async {
      final f = _fixture();
      await f.source.getHomeSummary(date: _day);
      f.adapter.offlinePaths.addAll(['/trainings/day', '/diets/today']);
      f.adapter.statusFor['/profile/me'] = 403;
      final summary = await f.source.getHomeSummary(date: _day);
      expect(summary.staleReason, startsWith('ApiException(403)'));
    });

    test('404 and 204 of the day are answers, not failures', () async {
      final f = _fixture();
      f.adapter.statusFor['/trainings/day'] = 404;
      f.adapter.statusFor['/diets/today'] = 404;
      final summary = await f.source.getHomeSummary(date: _day);
      expect(summary.trainingName, isNull);
      expect(summary.staleReason, isNull);
    });

    test('the persisted cache keeps its keys and format', () async {
      final f = _fixture();
      await f.source.getHomeSummary(date: _day);
      final before = jsonEncode(f.storage.cache);
      f.adapter.offline = true;
      await f.source.getHomeSummary(date: _day);
      expect(jsonEncode(f.storage.cache), before);
      expect(
        f.storage.cache.keys,
        containsAll(<String>[
          'home_training_2026-11-18',
          'home_diet_2026-11-18',
          'home_progress_2026-11-18',
          'home_streak',
          'home_profile',
          'home_latest_metric',
        ]),
      );
    });

    test('the repository hands the reason to the domain summary', () async {
      final f = _fixture();
      final repository = HomeRepositoryImpl(f.source);
      await repository.getHomeSummary(date: _day);
      f.adapter.offline = true;
      final summary = await repository.getHomeSummary(date: _day);
      expect(summary.staleReason, startsWith('ApiException(0)'));
    });
  });

  group('HomeBloc', () {
    HomeBloc blocOf(HomeRemoteDataSourceImpl source) {
      final bloc = HomeBloc(
        getHomeSummaryUseCase: GetHomeSummaryUseCase(
          HomeRepositoryImpl(source),
        ),
      );
      addTearDown(bloc.close);
      return bloc;
    }

    test('a reload served from the saved copy reports the offline failure '
        'over the content', () async {
      final f = _fixture();
      final bloc = blocOf(f.source);
      final first = await _settled(
        bloc,
        () => bloc.add(HomeLoadRequested(date: _day)),
      );
      expect(_refreshErrorOf(first), isNull);
      f.adapter.offline = true;
      final state = await _settled(
        bloc,
        () => bloc.add(HomeLoadRequested(date: _day)),
      );
      expect(state, isA<HomeLoaded>());
      expect((state as HomeLoaded).summary.trainingName, 'Pierna');
      expect(state.refreshError, startsWith('ApiException(0)'));
    });

    test('a first load without network is flagged too', () async {
      final f = _fixture()..adapter.offline = true;
      final bloc = blocOf(f.source);
      final state = await _settled(
        bloc,
        () => bloc.add(HomeLoadRequested(date: _day)),
      );
      expect(state, isNot(isA<HomeError>()));
      expect(_refreshErrorOf(state), startsWith('ApiException(0)'));
    });

    test('a date change served from the saved copy is flagged', () async {
      final f = _fixture();
      final bloc = blocOf(f.source);
      await _settled(bloc, () => bloc.add(HomeLoadRequested(date: _day)));
      f.adapter.offline = true;
      final state = await _settled(
        bloc,
        () => bloc.add(HomeDateSelected(DateTime(2026, 11, 19))),
      );
      expect(_refreshErrorOf(state), startsWith('ApiException(0)'));
    });

    test('a load that answers again clears the flag', () async {
      final f = _fixture()..adapter.offline = true;
      final bloc = blocOf(f.source);
      await _settled(bloc, () => bloc.add(HomeLoadRequested(date: _day)));
      f.adapter.offline = false;
      final state = await _settled(
        bloc,
        () => bloc.add(HomeLoadRequested(date: _day)),
      );
      expect(_refreshErrorOf(state), isNull);
    });
  });
}
