import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/calendar/data/datasources/calendar_remote_datasource.dart';
import 'package:exom_app/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:exom_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
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
  List<dynamic>? getCachedList(String key) {
    final value = _cache[key];
    return value is List ? List<dynamic>.from(value) : null;
  }

  @override
  List<Map<String, dynamic>> getPendingSyncActions() => const [];
}

class _RecordingAdapter implements HttpClientAdapter {
  final paths = <String>[];
  int profileVersion = 1;
  bool failDate = false;

  /// L4b: `/calendar/month` answers 500.
  bool failCalendar = false;

  /// Every request fails as without network (no response).
  bool offline = false;

  /// `/calendar/month` days by ISO date, filtered by the requested month.
  Map<String, Map<String, Object?>> calendarDays = {};

  /// `exercises_completed` returned by `/progress`.
  List<Map<String, Object?>> completedExercises = const [];

  /// `trainings_completed` returned by `/progress`.
  List<String> completedTrainings = const [];

  final calendarMonths = <String>[];

  /// When true every `/calendar/month` request waits in [pendingCalendar]
  /// until the test completes it; it answers with the [calendarDays] of the
  /// moment it was asked.
  bool gateCalendar = false;
  final pendingCalendar = <Completer<void>>[];

  int count(String path) => paths.where((p) => p == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final date = options.queryParameters['date'];
    if (options.path == '/calendar/month') {
      final year = options.queryParameters['year'] as int;
      final month = options.queryParameters['month'] as int;
      calendarMonths.add('$year-$month');
      if (failCalendar) return ResponseBody.fromString('{}', 500);
      final prefix = '$year-${month.toString().padLeft(2, '0')}-';
      final answer = Map.of(calendarDays);
      if (gateCalendar) {
        final gate = Completer<void>();
        pendingCalendar.add(gate);
        await gate.future;
      }
      return ResponseBody.fromString(
        jsonEncode({
          'data': [
            for (final entry in answer.entries)
              if (entry.key.startsWith(prefix))
                {'date': entry.key, ...entry.value},
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
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
        'program_week': 3,
        'program_day': 2,
        'exercises': const [
          {
            'id': 'te-1',
            'sets': 3,
            'exercise': {'id': 'e-1'},
          },
        ],
      },
      '/diets/today' => {'id': 'd-$date', 'name': 'Diet $date'},
      '/streaks/me' => {'current_days': 7},
      '/profile/me' => {
        'first_name': 'Ana',
        'last_name': 'v$profileVersion',
        'current_weight': 61.5,
      },
      '/metrics/latest' => {'date': '2026-10-30', 'sleep_hours': 7.5},
      '/progress' => {
        'exercises_completed': completedExercises,
        'trainings_completed': completedTrainings,
      },
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

({HomeBloc bloc, _RecordingAdapter adapter, _MemoryStorage storage})
_fixture({bool withCalendar = false, _MemoryStorage? storage}) {
  final adapter = _RecordingAdapter();
  final client = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test')
    ..dio.httpClientAdapter = adapter;
  final store = storage ?? _MemoryStorage();
  final bloc = HomeBloc(
    getHomeSummaryUseCase: GetHomeSummaryUseCase(
      HomeRepositoryImpl(HomeRemoteDataSourceImpl(client, store)),
    ),
    getMonthCalendarUseCase: withCalendar
        ? GetMonthCalendarUseCase(
            CalendarRepositoryImpl(CalendarRemoteDataSourceImpl(client, store)),
          )
        : null,
  );
  addTearDown(bloc.close);
  return (bloc: bloc, adapter: adapter, storage: store);
}

/// Lets the week marks request that follows a settled load land.
Future<void> _idle() => Future<void>.delayed(const Duration(milliseconds: 30));

HomeWeekMarks? _marksOf(HomeState state) => switch (state) {
  HomeLoaded(:final weekMarks) => weekMarks,
  HomeRestDay(:final weekMarks) => weekMarks,
  _ => null,
};

Future<HomeState> _settled(HomeBloc bloc, void Function() act) async {
  final next = bloc.stream.firstWhere(
    (s) => s is HomeLoaded || s is HomeRestDay || s is HomeError,
  );
  act();
  return next;
}

void main() {
  test('MEASURE initial load plus five date changes', () async {
    // L4b: the initial load names its date (Monday 2 Nov 2026) instead of
    // the real today, so the visible week (2-8 Nov, one month) and therefore
    // the calendar count do not depend on when the suite runs.
    final f = _fixture(withCalendar: true);
    await _settled(
      f.bloc,
      () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 2))),
    );
    await _idle();
    for (var day = 2; day <= 6; day++) {
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeDateSelected(DateTime(2026, 11, day))),
      );
      await _idle();
    }
    // ignore: avoid_print
    print(
      'HOME_GETS total=${f.adapter.paths.length} '
      'profile=${f.adapter.count('/profile/me')} '
      'streak=${f.adapter.count('/streaks/me')} '
      'metrics=${f.adapter.count('/metrics/latest')} '
      'calendar=${f.adapter.count('/calendar/month')}',
    );
    // Before L4b: 21 = 6 on the full load (training, diet, streak, profile,
    // metrics, progress) + 3 per date change (training, diet, progress).
    // L4b-D4 adds one `/calendar/month` per visible week (two when the week
    // spans two months), shared by every day of that week: 21 + 1 = 22.
    expect(f.adapter.count('/calendar/month'), 1);
    expect(f.adapter.paths.length, 22);
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

  group('L4b week marks from /calendar/month', () {
    Map<String, Object?> pending() => {
      'has_training': true,
      'is_rest_day': false,
      'training_completed': false,
    };
    Map<String, Object?> done() => {
      'has_training': true,
      'is_rest_day': false,
      'training_completed': true,
    };

    test('one calendar request per visible week, shared by its days', () async {
      final f = _fixture(withCalendar: true);
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      await _idle();
      for (final day in [16, 17, 19, 22]) {
        await _settled(
          f.bloc,
          () => f.bloc.add(HomeDateSelected(DateTime(2026, 11, day))),
        );
        await _idle();
      }
      expect(f.adapter.calendarMonths, ['2026-11']);

      // A full refresh (pull to refresh, return from a session) reloads the
      // week like the rest of Inicio.
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      await _idle();
      expect(f.adapter.calendarMonths, ['2026-11', '2026-11']);
    });

    test('maps pending, done, rest and missing days', () async {
      final f = _fixture(withCalendar: true);
      f.adapter.calendarDays = {
        '2026-11-16': done(),
        '2026-11-17': {
          'has_training': false,
          'is_rest_day': true,
          'training_completed': false,
        },
        '2026-11-19': pending(),
        '2026-11-20': {
          'has_training': true,
          'is_rest_day': true,
          'training_completed': false,
        },
      };
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeDateSelected(DateTime(2026, 11, 17))),
      );
      await _idle();
      final marks = _marksOf(f.bloc.state)!;
      expect(marks.weekStart, DateTime(2026, 11, 16));
      expect(marks.markFor(DateTime(2026, 11, 16)), HomeDayMark.done);
      // The selected day uses its own loaded summary: it has a pending
      // training, whatever the calendar says.
      expect(marks.markFor(DateTime(2026, 11, 17)), HomeDayMark.pending);
      expect(marks.markFor(DateTime(2026, 11, 19)), HomeDayMark.pending);
      expect(marks.markFor(DateTime(2026, 11, 20)), HomeDayMark.none);
      expect(marks.markFor(DateTime(2026, 11, 21)), HomeDayMark.none);
      // Days outside the week carry no mark.
      expect(marks.markFor(DateTime(2026, 11, 23)), isNull);
    });

    test('today uses the local Inicio state when it differs', () async {
      final f = _fixture(withCalendar: true);
      // The server calendar still says pending, but the progress (with the
      // pending offline actions overlaid) already completes the session.
      // L5-D49 O5: completing means finishing it (`trainings_completed`);
      // marked exercises alone do not.
      f.adapter.calendarDays = {'2026-11-18': pending()};
      f.adapter.completedExercises = const [
        {'training_exercise_id': 'te-1', 'exercise_id': 'e-1'},
      ];
      f.adapter.completedTrainings = const ['t-2026-11-18'];
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      await _idle();
      expect(
        _marksOf(f.bloc.state)!.markFor(DateTime(2026, 11, 18)),
        HomeDayMark.done,
      );
    });

    test('a week across two months asks both months once', () async {
      final f = _fixture(withCalendar: true);
      f.adapter.calendarDays = {
        '2026-11-30': done(),
        '2026-12-03': pending(),
      };
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 12, 2))),
      );
      await _idle();
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeDateSelected(DateTime(2026, 12, 4))),
      );
      await _idle();
      expect(f.adapter.calendarMonths.toList()..sort(), [
        '2026-11',
        '2026-12',
      ]);
      final marks = _marksOf(f.bloc.state)!;
      expect(marks.weekStart, DateTime(2026, 11, 30));
      expect(marks.markFor(DateTime(2026, 11, 30)), HomeDayMark.done);
      expect(marks.markFor(DateTime(2026, 12, 3)), HomeDayMark.pending);
      expect(marks.markFor(DateTime(2026, 12, 6)), HomeDayMark.none);
    });

    test('a failing calendar leaves no marks and Inicio loads', () async {
      final f = _fixture(withCalendar: true);
      f.adapter.failCalendar = true;
      final state = await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      await _idle();
      expect(state, isA<HomeLoaded>());
      expect(f.bloc.state, isA<HomeLoaded>());
      expect(_marksOf(f.bloc.state), isNull);
      expect(
        (f.bloc.state as HomeLoaded).summary.trainingName,
        'Training 2026-11-18',
      );
    });

    test('a calendar without days leaves no marks', () async {
      final f = _fixture(withCalendar: true);
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      await _idle();
      expect(f.adapter.count('/calendar/month'), 1);
      expect(_marksOf(f.bloc.state), isNull);
    });

    test('offline without cache: no error state and no marks', () async {
      final f = _fixture(withCalendar: true);
      f.adapter.offline = true;
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      await _idle();
      expect(f.bloc.state, isNot(isA<HomeError>()));
      expect(_marksOf(f.bloc.state), isNull);
    });

    test('offline with cache: marks come from the existing calendar '
        'cache', () async {
      final online = _fixture(withCalendar: true);
      online.adapter.calendarDays = {'2026-11-16': done()};
      await _settled(
        online.bloc,
        () => online.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      await _idle();
      expect(
        online.storage.getCachedList('calendar_month_2026_11'),
        isNotNull,
      );

      final offline = _fixture(withCalendar: true, storage: online.storage);
      offline.adapter.offline = true;
      final state = await _settled(
        offline.bloc,
        () =>
            offline.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      await _idle();
      expect(state, isA<HomeLoaded>());
      expect(
        _marksOf(offline.bloc.state)!.markFor(DateTime(2026, 11, 16)),
        HomeDayMark.done,
      );
    });

    test('date changes keep the program week of their own day', () async {
      final f = _fixture(withCalendar: true);
      await _settled(f.bloc, () => f.bloc.add(const HomeLoadRequested()));
      await _idle();
      final state =
          await _settled(
                f.bloc,
                () => f.bloc.add(HomeDateSelected(DateTime(2026, 11, 3))),
              )
              as HomeLoaded;
      expect(state.summary.programWeek, 3);
      expect(state.summary.programDay, 2);
      expect(state.summary.totalSets, 3);
    });

    test('a late answer of a previous week does not overwrite the newer '
        'week', () async {
      final f = _fixture(withCalendar: true);
      f.adapter.gateCalendar = true;
      f.adapter.calendarDays = {'2026-11-16': done()};
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      expect(f.adapter.pendingCalendar, hasLength(1));
      f.adapter.calendarDays = {'2026-11-23': done()};
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeDateSelected(DateTime(2026, 11, 24))),
      );
      expect(f.adapter.pendingCalendar, hasLength(2));

      f.adapter.pendingCalendar[1].complete();
      await _idle();
      expect(_marksOf(f.bloc.state)!.weekStart, DateTime(2026, 11, 23));
      expect(
        _marksOf(f.bloc.state)!.markFor(DateTime(2026, 11, 23)),
        HomeDayMark.done,
      );

      // The first week answers last: nothing changes.
      f.adapter.pendingCalendar[0].complete();
      await _idle();
      final state = f.bloc.state as HomeLoaded;
      expect(state.selectedDate, DateTime(2026, 11, 24));
      final marks = _marksOf(state)!;
      expect(marks.weekStart, DateTime(2026, 11, 23));
      expect(marks.markFor(DateTime(2026, 11, 23)), HomeDayMark.done);
      expect(marks.markFor(DateTime(2026, 11, 16)), isNull);
    });

    test('a late answer from before a new full load is discarded', () async {
      final f = _fixture(withCalendar: true);
      f.adapter.gateCalendar = true;
      f.adapter.calendarDays = {'2026-11-16': done()};
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      expect(f.adapter.pendingCalendar, hasLength(1));
      // Full refresh of the same week (new epoch); the server now says
      // pending.
      f.adapter.calendarDays = {'2026-11-16': pending()};
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      expect(f.adapter.pendingCalendar, hasLength(2));

      f.adapter.pendingCalendar[1].complete();
      await _idle();
      expect(
        _marksOf(f.bloc.state)!.markFor(DateTime(2026, 11, 16)),
        HomeDayMark.pending,
      );

      // The answer of the previous epoch (stale "done") arrives last.
      f.adapter.pendingCalendar[0].complete();
      await _idle();
      expect(
        _marksOf(f.bloc.state)!.markFor(DateTime(2026, 11, 16)),
        HomeDayMark.pending,
      );
    });

    test('without the calendar use case nothing is requested', () async {
      final f = _fixture();
      await _settled(
        f.bloc,
        () => f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18))),
      );
      await _idle();
      expect(f.adapter.count('/calendar/month'), 0);
      expect(_marksOf(f.bloc.state), isNull);
    });
  });
}
