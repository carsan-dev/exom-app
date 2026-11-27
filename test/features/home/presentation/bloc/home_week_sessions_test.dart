// «Tu semana N de M sesiones hechas» (E1 O1) counts sessions, not days:
// `/calendar/month` already sends, per day, `trainings_assigned`,
// `trainings_done` and `training_completion_mode`. Without those fields
// (older API or older saved calendar) each day with a session counts as one,
// as before.
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

class _Adapter implements HttpClientAdapter {
  _Adapter(this.calendarDays);

  final Map<String, Map<String, Object?>> calendarDays;

  /// `/trainings/day` of the loaded day: its trainings (id → completed).
  Map<String, bool> dayTrainings = const {'t-1': false};

  /// `year-month` of each `/calendar/month` request.
  final calendarMonths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? data;
    if (options.path == '/calendar/month') {
      final year = options.queryParameters['year'] as int;
      final month = options.queryParameters['month'] as int;
      calendarMonths.add('$year-$month');
      final prefix = '$year-${month.toString().padLeft(2, '0')}-';
      data = [
        for (final entry in calendarDays.entries)
          if (entry.key.startsWith(prefix)) {'date': entry.key, ...entry.value},
      ];
    } else {
      data = switch (options.path) {
        '/trainings/day' => {
          'trainings': [
            for (final id in dayTrainings.keys)
              {
                'id': id,
                'name': 'Training $id',
                'exercises': [
                  {
                    'id': 'te-$id',
                    'sets': 3,
                    'exercise': {'id': 'e-$id'},
                  },
                ],
              },
          ],
        },
        '/progress' => {
          'trainings_completed': [
            for (final entry in dayTrainings.entries)
              if (entry.value) entry.key,
          ],
        },
        _ => null,
      };
    }
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

Map<String, Object?> _training({
  required int assigned,
  required int done,
  bool completed = false,
  String mode = 'ALL',
  bool withCounts = true,
}) => {
  'has_training': true,
  'has_diet': false,
  'is_rest_day': false,
  'training_completed': completed,
  if (withCounts) ...{
    'training_completion_mode': mode,
    'trainings_assigned': assigned,
    'trainings_done': done,
  },
};

/// Week of Monday 16 Nov 2026 as the O1 emulator case: Monday one session
/// done, Wednesday (the loaded day) one pending, Friday two with one done,
/// Saturday two pending and Sunday a rest day that still lists a training.
Map<String, Map<String, Object?>> _week({bool withCounts = true}) => {
  '2026-11-16': _training(
    assigned: 1,
    done: 1,
    completed: true,
    withCounts: withCounts,
  ),
  '2026-11-18': _training(assigned: 1, done: 0, withCounts: withCounts),
  '2026-11-20': _training(assigned: 2, done: 1, withCounts: withCounts),
  '2026-11-21': _training(assigned: 2, done: 0, withCounts: withCounts),
  '2026-11-22': {
    ..._training(assigned: 1, done: 0, withCounts: withCounts),
    'is_rest_day': true,
  },
};

Future<HomeWeekMarks> _marksAfterLoad(
  _Adapter adapter, {
  DateTime? date,
}) async {
  final client = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test')
    ..dio.httpClientAdapter = adapter;
  final storage = _MemoryStorage();
  final bloc = HomeBloc(
    getHomeSummaryUseCase: GetHomeSummaryUseCase(
      HomeRepositoryImpl(HomeRemoteDataSourceImpl(client, storage)),
    ),
    getMonthCalendarUseCase: GetMonthCalendarUseCase(
      CalendarRepositoryImpl(CalendarRemoteDataSourceImpl(client, storage)),
    ),
  );
  addTearDown(bloc.close);
  final withMarks = bloc.stream.firstWhere(
    (s) => s is HomeLoaded && s.weekMarks != null,
  );
  bloc.add(HomeLoadRequested(date: date ?? DateTime(2026, 11, 18)));
  return ((await withMarks) as HomeLoaded).weekMarks!;
}

void main() {
  test('counts the sessions of each day, not the days (O1)', () async {
    final marks = await _marksAfterLoad(_Adapter(_week()));
    // 1 (Mon) + 1 (Wed) + 2 (Fri) + 2 (Sat); the rest day does not count.
    expect(marks.sessionCount, 6);
    // Monday's one and one of Friday's two.
    expect(marks.doneCount, 2);
  });

  test(
    'a day that completes with any of its trainings is one session',
    () async {
      final days = _week()
        ..['2026-11-20'] = _training(
          assigned: 2,
          done: 1,
          completed: true,
          mode: 'ANY',
        );
      final marks = await _marksAfterLoad(_Adapter(days));
      expect(marks.sessionCount, 5);
      expect(marks.doneCount, 2);
    },
  );

  test('the loaded day counts its own sessions from the summary', () async {
    final adapter = _Adapter(_week())
      ..dayTrainings = const {'t-1': true, 't-2': false};
    final marks = await _marksAfterLoad(adapter);
    // Wednesday now has two sessions (one done) instead of the calendar's one.
    expect(marks.sessionCount, 7);
    expect(marks.doneCount, 3);
  });

  test(
    'without the counts (older API) each day with a session is one',
    () async {
      final marks = await _marksAfterLoad(_Adapter(_week(withCounts: false)));
      expect(marks.sessionCount, 4);
      expect(marks.doneCount, 1);
    },
  );

  test('a week across two months counts the days of both', () async {
    // Monday 30 Nov to Sunday 6 Dec 2026; the loaded day is Wednesday 2 Dec.
    final adapter = _Adapter({
      '2026-11-30': _training(assigned: 2, done: 1),
      '2026-12-02': _training(assigned: 1, done: 0),
      '2026-12-04': _training(assigned: 1, done: 1, completed: true),
      // Outside the week: ignored.
      '2026-11-29': _training(assigned: 3, done: 3, completed: true),
      '2026-12-07': _training(assigned: 3, done: 0),
    });
    final marks = await _marksAfterLoad(adapter, date: DateTime(2026, 12, 2));
    expect(HomeWeekMarks.dayKey(marks.weekStart), '2026-11-30');
    expect(marks.sessionCount, 4);
    expect(marks.doneCount, 2);
    expect(adapter.calendarMonths.toSet(), {'2026-11', '2026-12'});
  });
}
