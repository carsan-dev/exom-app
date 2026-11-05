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
  final _cache = <String, dynamic>{};

  @override
  Future<void> cacheData(String key, dynamic value) async {
    _cache[key] = value;
  }

  @override
  Map<String, dynamic>? getCachedMap(String key) {
    final value = _cache[key];
    return value is Map<String, dynamic> ? value : null;
  }

  @override
  List<Map<String, dynamic>> getPendingSyncActions() => const [];
}

class _RecordingAdapter implements HttpClientAdapter {
  final paths = <String>[];
  int profileVersion = 1;
  bool failDate = false;

  int count(String path) => paths.where((p) => p == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final date = options.queryParameters['date'];
    if (failDate && date != null && date != '2026-11-01') {
      if (options.path == '/trainings/day' ||
          options.path == '/diets/today' ||
          options.path == '/progress') {
        return ResponseBody.fromString('{}', 500);
      }
    }
    final Object? data = switch (options.path) {
      '/trainings/day' => {
        'id': 't-$date',
        'name': 'Training $date',
        'exercises': const [],
      },
      '/diets/today' => {'id': 'd-$date', 'name': 'Diet $date'},
      '/streaks/me' => {'current_days': 7},
      '/profile/me' => {
        'first_name': 'Ana',
        'last_name': 'v$profileVersion',
        'current_weight': 61.5,
      },
      '/metrics/latest' => {'date': '2026-10-30', 'sleep_hours': 7.5},
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

({HomeBloc bloc, _RecordingAdapter adapter}) _fixture() {
  final adapter = _RecordingAdapter();
  final client = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test')
    ..dio.httpClientAdapter = adapter;
  final storage = _MemoryStorage();
  final bloc = HomeBloc(
    getHomeSummaryUseCase: GetHomeSummaryUseCase(
      HomeRepositoryImpl(HomeRemoteDataSourceImpl(client, storage)),
    ),
  );
  addTearDown(bloc.close);
  return (bloc: bloc, adapter: adapter);
}

Future<HomeState> _settled(HomeBloc bloc, void Function() act) async {
  final next = bloc.stream.firstWhere(
    (s) => s is HomeLoaded || s is HomeRestDay || s is HomeError,
  );
  act();
  return next;
}

void main() {
  test('MEASURE initial load plus five date changes', () async {
    final f = _fixture();
    await _settled(f.bloc, () => f.bloc.add(const HomeLoadRequested()));
    for (var day = 2; day <= 6; day++) {
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeDateSelected(DateTime(2026, 11, day))),
      );
    }
    // ignore: avoid_print
    print(
      'HOME_GETS total=${f.adapter.paths.length} '
      'profile=${f.adapter.count('/profile/me')} '
      'streak=${f.adapter.count('/streaks/me')} '
      'metrics=${f.adapter.count('/metrics/latest')}',
    );
    expect(f.adapter.paths.length, 21);
  });

  test('date changes keep the shared profile fields from the full load', () async {
    final f = _fixture();
    await _settled(f.bloc, () => f.bloc.add(const HomeLoadRequested()));
    f.adapter.profileVersion = 2; // would be visible if profile were refetched
    final state =
        await _settled(
              f.bloc,
              () => f.bloc.add(HomeDateSelected(DateTime(2026, 11, 3))),
            )
            as HomeLoaded;
    expect(state.summary.trainingName, 'Training 2026-11-03');
    expect(state.summary.clientName, 'Ana v1');
    expect(state.summary.streakDays, 7);
    expect(state.summary.lastWeightKg, 61.5);
    expect(state.summary.lastSleepHours, 7.5);
  });

  test('explicit refresh refetches the shared fields', () async {
    final f = _fixture();
    await _settled(f.bloc, () => f.bloc.add(const HomeLoadRequested()));
    await _settled(
      f.bloc,
      () => f.bloc.add(HomeDateSelected(DateTime(2026, 11, 3))),
    );
    f.adapter.profileVersion = 2;
    final state =
        await _settled(
              f.bloc,
              () => f.bloc.add(
                HomeLoadRequested(date: DateTime(2026, 11, 3)),
              ),
            )
            as HomeLoaded;
    expect(f.adapter.count('/profile/me'), 2);
    expect(f.adapter.count('/streaks/me'), 2);
    expect(f.adapter.count('/metrics/latest'), 2);
    expect(state.summary.clientName, 'Ana v2');
  });

  test('a new bloc (another session) never reuses shared fields', () async {
    final first = _fixture();
    await _settled(first.bloc, () => first.bloc.add(const HomeLoadRequested()));
    final second = _fixture();
    second.adapter.profileVersion = 9;
    final state =
        await _settled(
              second.bloc,
              () => second.bloc.add(HomeDateSelected(DateTime(2026, 11, 3))),
            )
            as HomeLoaded;
    expect(second.adapter.count('/profile/me'), 1);
    expect(state.summary.clientName, 'Ana v9');
  });

  test('date change failure keeps the loaded content', () async {
    final f = _fixture();
    await _settled(f.bloc, () => f.bloc.add(const HomeLoadRequested()));
    f.adapter.failDate = true;
    final state = await _settled(
      f.bloc,
      () => f.bloc.add(HomeDateSelected(DateTime(2026, 11, 3))),
    );
    expect(state, isNot(isA<HomeError>()));
    expect(f.bloc.state, isA<HomeState>());
  });
}
