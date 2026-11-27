// L5-D49 O5: on Inicio a session is «Hecha» only once it is finished, that
// is, once «Terminar sesión» was pressed: the server lists it in
// `trainings_completed` (or flags the legacy single-training day) or the
// offline queue holds its `complete_training` action for that date. Having
// every exercise marked (on the server or only on this phone, e.g. held by a
// video) is not enough: that session shows «Sin terminar». The same rule
// feeds the week strip (ANY mode included) and «N de M sesiones hechas».
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/pending_progress_overlay.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/calendar/data/datasources/calendar_remote_datasource.dart';
import 'package:exom_app/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:exom_app/features/home/data/models/home_summary_model.dart';
import 'package:exom_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _date = '2026-11-18';

Map<String, dynamic> _training(String id, {int exercises = 2}) => {
  'id': id,
  'name': 'Sesión $id',
  'exercises': [
    for (var i = 1; i <= exercises; i++)
      {
        'id': 'te-$id-$i',
        'sets': 3,
        'exercise': {'id': 'e-$id-$i'},
      },
  ],
};

Map<String, dynamic> _marked(String id) => {
  'training_exercise_id': 'te-$id-1',
  'exercise_id': 'e-$id-1',
};

List<Map<String, dynamic>> _allMarked(String id) => [
  for (var i = 1; i <= 2; i++)
    {'training_exercise_id': 'te-$id-$i', 'exercise_id': 'e-$id-$i'},
];

HomeSummaryModel _summary(
  List<String> ids, {
  required Map<String, dynamic> progress,
  List<Map<String, dynamic>> queue = const [],
}) => HomeSummaryModel.fromParts(
  training: {
    'trainings': [for (final id in ids) _training(id)],
  },
  diet: null,
  streak: null,
  profile: null,
  latestMetric: null,
  progress: overlayPendingProgressActions(
    progress: progress,
    actions: queue,
    date: _date,
  ),
);

Map<String, dynamic> _markAction(String id, int i) => {
  'type': 'mark_exercise_completed',
  'date': _date,
  'training_exercise_id': 'te-$id-$i',
  'exercise_id': 'e-$id-$i',
  'status': 'pending',
};

Map<String, dynamic> _completeAction(String id, {String? status}) => {
  'type': 'complete_training',
  'date': _date,
  'training_id': id,
  'status': ?status,
};

class _MemoryStorage extends LocalStorage {
  _MemoryStorage(this.queue);

  final List<Map<String, dynamic>> queue;
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
  List<Map<String, dynamic>> getPendingSyncActions() => queue;
}

/// `/trainings/day` holds [ids]; `/progress` answers [progress]; the
/// calendar describes Wednesday 18 Nov 2026 with [assigned] trainings in
/// [mode] and nothing done.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.ids, this.progress, {this.mode = 'ALL'});

  final List<String> ids;
  final Map<String, dynamic> progress;
  final String mode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object? data = switch (options.path) {
      '/calendar/month' => [
        {
          'date': _date,
          'has_training': true,
          'has_diet': false,
          'is_rest_day': false,
          'training_completed': false,
          'training_completion_mode': mode,
          'trainings_assigned': ids.length,
          'trainings_done': 0,
        },
      ],
      '/trainings/day' => {
        'trainings': [for (final id in ids) _training(id)],
      },
      '/progress' => progress,
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

/// A store bound to account `owner-a` whose [getPendingSyncActions] is the
/// real one: it filters the queue with `ownsEntry` (owner, environment,
/// format). Only the Hive reads and writes are kept in memory.
class _ScopedStorage extends LocalStorage {
  _ScopedStorage(List<Map<String, dynamic>> queue)
    : super(currentSession: () => const LocalAuthSession(uid: 'owner-a')) {
    _values['offline_sync_actions'] = queue;
  }

  final _values = <String, dynamic>{};

  @override
  Future<void> cacheData(String key, dynamic value) async {
    _values[key] = value;
  }

  @override
  dynamic getCachedValue(String key) => _values[key];
}

Map<String, dynamic> _ownedBy(String owner, Map<String, dynamic> action) => {
  ...action,
  'format_version': 2,
  'owner_id': owner,
  'environment': 'test',
};

Future<HomeLoaded> _load(
  _Adapter adapter, {
  List<Map<String, dynamic>> queue = const [],
  LocalStorage? store,
}) async {
  final client = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test')
    ..dio.httpClientAdapter = adapter;
  final storage = store ?? _MemoryStorage(queue);
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
  bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18)));
  return (await withMarks) as HomeLoaded;
}

HomeDayMark _wednesday(HomeWeekMarks marks) =>
    marks.markFor(DateTime(2026, 11, 18))!;

void main() {
  group('summary model', () {
    test('every exercise marked without finishing is «Sin terminar»', () {
      final summary = _summary(
        ['t-1'],
        progress: {'exercises_completed': _allMarked('t-1')},
      );
      final item = summary.trainings.single;
      expect(item.completed, isFalse);
      expect(item.unfinished, isTrue);
      expect(summary.trainingCompleted, isFalse);
      // Progress per exercise does not change.
      expect(summary.exercisesCompleted, 2);
    });

    test('exercises marked only on this phone (held by a video) are '
        '«Sin terminar»', () {
      final summary = _summary(
        ['t-1'],
        progress: const {},
        queue: [_markAction('t-1', 1), _markAction('t-1', 2)],
      );
      expect(summary.exercisesCompleted, 2);
      expect(summary.trainings.single.completed, isFalse);
      expect(summary.trainings.single.unfinished, isTrue);
      expect(summary.trainingCompleted, isFalse);
    });

    test('finished and confirmed by the server is «Hecha»', () {
      final summary = _summary(
        ['t-1'],
        progress: {
          'trainings_completed': ['t-1'],
          'exercises_completed': _allMarked('t-1'),
        },
      );
      expect(summary.trainings.single.completed, isTrue);
      expect(summary.trainings.single.unfinished, isFalse);
      expect(summary.trainingCompleted, isTrue);
    });

    test('finished offline (completion queued) is «Hecha»', () {
      final summary = _summary(
        ['t-1'],
        progress: const {},
        queue: [
          _markAction('t-1', 1),
          _markAction('t-1', 2),
          _completeAction('t-1', status: 'pending'),
        ],
      );
      expect(summary.trainings.single.completed, isTrue);
      expect(summary.trainings.single.unfinished, isFalse);
      expect(summary.trainingCompleted, isTrue);
    });

    test('a failed queued completion is not «Hecha»', () {
      final summary = _summary(
        ['t-1'],
        progress: {'exercises_completed': _allMarked('t-1')},
        queue: [_completeAction('t-1', status: 'failed')],
      );
      expect(summary.trainings.single.completed, isFalse);
      expect(summary.trainings.single.unfinished, isTrue);
    });

    test('some exercises marked keeps the in-progress state', () {
      final summary = _summary(
        ['t-1'],
        progress: {
          'exercises_completed': [_marked('t-1')],
        },
      );
      expect(summary.trainings.single.completed, isFalse);
      expect(summary.trainings.single.unfinished, isFalse);
      expect(summary.exercisesCompleted, 1);
    });

    test('r2: the legacy flag counts even with exercise entries, as the API '
        '(legacySingleCompletion)', () {
      final summary = _summary(
        ['t-1'],
        progress: {
          'training_completed': true,
          'trainings_completed': const <String>[],
          'exercises_completed': [_marked('t-1')],
        },
      );
      expect(summary.trainings.single.completed, isTrue);
      expect(summary.trainings.single.unfinished, isFalse);
      expect(summary.trainingCompleted, isTrue);
    });

    test('r2: the legacy flag does not finish a day of two trainings', () {
      final summary = _summary(
        ['t-1', 't-2'],
        progress: {'training_completed': true},
      );
      expect(summary.trainings.map((t) => t.completed), [false, false]);
    });

    test('r2: a completion failed by a conflict does not count', () {
      final summary = _summary(
        ['t-1'],
        progress: {'exercises_completed': _allMarked('t-1')},
        queue: [
          {
            ..._completeAction('t-1', status: 'failed'),
            'last_error': 'progress_conflict_review_required',
          },
        ],
      );
      expect(summary.trainings.single.completed, isFalse);
      expect(summary.trainings.single.unfinished, isTrue);
      expect(summary.trainingCompleted, isFalse);
    });

    test('r2: «Sin terminar» adds no minutes to what is left', () {
      final summary = HomeSummaryModel.fromParts(
        training: {
          'trainings': [
            {..._training('t-1'), 'estimated_duration_min': 30},
            {..._training('t-2'), 'estimated_duration_min': 45},
          ],
        },
        diet: null,
        streak: null,
        profile: null,
        latestMetric: null,
        progress: {'exercises_completed': _allMarked('t-1')},
      );
      expect(summary.trainings.map((t) => t.unfinished), [true, false]);
      expect(summary.remainingTrainingDurationMin, 45);
    });

    test('the legacy single-training day flag still counts as finished', () {
      final summary = _summary(['t-1'], progress: {'training_completed': true});
      expect(summary.trainings.single.completed, isTrue);
      expect(summary.trainingCompleted, isTrue);
    });
  });

  group('week strip and counts', () {
    test('a day with every exercise marked but not finished is pending and '
        'counts no session', () async {
      final loaded = await _load(
        _Adapter(['t-1'], {'exercises_completed': _allMarked('t-1')}),
      );
      expect(_wednesday(loaded.weekMarks!), HomeDayMark.pending);
      expect(loaded.weekMarks!.sessionCount, 1);
      expect(loaded.weekMarks!.doneCount, 0);
    });

    test('a day finished offline is done and counts its session', () async {
      final loaded = await _load(
        _Adapter(['t-1'], const {}),
        queue: [
          _markAction('t-1', 1),
          _markAction('t-1', 2),
          _completeAction('t-1', status: 'pending'),
        ],
      );
      expect(_wednesday(loaded.weekMarks!), HomeDayMark.done);
      expect(loaded.weekMarks!.doneCount, 1);
    });

    test(
      'ALL mode: one finished and one only marked is pending, 1 of 2',
      () async {
        final loaded = await _load(
          _Adapter(
            ['t-1', 't-2'],
            {
              'trainings_completed': ['t-1'],
              'exercises_completed': [
                ..._allMarked('t-1'),
                ..._allMarked('t-2'),
              ],
            },
          ),
        );
        expect(_wednesday(loaded.weekMarks!), HomeDayMark.pending);
        expect(loaded.weekMarks!.sessionCount, 2);
        expect(loaded.weekMarks!.doneCount, 1);
      },
    );

    test(
      'ANY mode: one finished and one only marked makes the day done',
      () async {
        final loaded = await _load(
          _Adapter(
            ['t-1', 't-2'],
            {
              'trainings_completed': ['t-1'],
              'exercises_completed': [
                ..._allMarked('t-1'),
                ..._allMarked('t-2'),
              ],
            },
            mode: 'ANY',
          ),
        );
        expect(_wednesday(loaded.weekMarks!), HomeDayMark.done);
        expect(loaded.weekMarks!.sessionCount, 1);
        expect(loaded.weekMarks!.doneCount, 1);
        final items = loaded.summary.trainings;
        expect(items.map((t) => t.completed), [true, false]);
        expect(items.map((t) => t.unfinished), [false, true]);
      },
    );

    test(
      'ANY mode: every session only marked leaves the day pending',
      () async {
        final loaded = await _load(
          _Adapter(
            ['t-1', 't-2'],
            {
              'exercises_completed': [
                ..._allMarked('t-1'),
                ..._allMarked('t-2'),
              ],
            },
            mode: 'ANY',
          ),
        );
        expect(_wednesday(loaded.weekMarks!), HomeDayMark.pending);
        expect(loaded.weekMarks!.doneCount, 0);
      },
    );
  });

  group('r2 queue', () {
    test('ANY mode: a queued completion makes the day done', () async {
      final loaded = await _load(
        _Adapter(
          ['t-1', 't-2'],
          {
            'exercises_completed': [..._allMarked('t-1'), ..._allMarked('t-2')],
          },
          mode: 'ANY',
        ),
        queue: [_completeAction('t-2', status: 'pending')],
      );
      expect(_wednesday(loaded.weekMarks!), HomeDayMark.done);
      expect(loaded.weekMarks!.doneCount, 1);
      expect(loaded.summary.trainings.map((t) => t.completed), [false, true]);
    });

    test(
      'a completion queued by this account counts (real ownsEntry)',
      () async {
        final loaded = await _load(
          _Adapter(['t-1'], {'exercises_completed': _allMarked('t-1')}),
          store: _ScopedStorage([
            _ownedBy('owner-a', _completeAction('t-1', status: 'pending')),
          ]),
        );
        expect(loaded.summary.trainings.single.completed, isTrue);
        expect(_wednesday(loaded.weekMarks!), HomeDayMark.done);
      },
    );

    test('a completion queued by another account does not count', () async {
      final loaded = await _load(
        _Adapter(['t-1'], {'exercises_completed': _allMarked('t-1')}),
        store: _ScopedStorage([
          _ownedBy('owner-b', _completeAction('t-1', status: 'pending')),
        ]),
      );
      expect(loaded.summary.trainings.single.completed, isFalse);
      expect(loaded.summary.trainings.single.unfinished, isTrue);
      expect(_wednesday(loaded.weekMarks!), HomeDayMark.pending);
      expect(loaded.weekMarks!.doneCount, 0);
    });
  });

  group('optimistic mark after the milestone', () {
    test('an unfinished session becomes «Hecha» once its completion is '
        'confirmed', () {
      const summary = HomeSummaryEntity(
        trainingId: 't-1',
        totalExercises: 2,
        exercisesCompleted: 2,
        trainings: [
          HomeTrainingItemEntity(
            id: 't-1',
            name: 'Sesión t-1',
            completed: false,
            unfinished: true,
          ),
        ],
      );
      final patched = summary.withTrainingCompleted('t-1')!;
      expect(patched.trainings.single.completed, isTrue);
      expect(patched.trainings.single.unfinished, isFalse);
      expect(patched.trainingCompleted, isTrue);
      expect(HomeDayMark.ofSummary(patched), HomeDayMark.done);
    });
  });

  group('session block', () {
    Future<void> pump(WidgetTester tester, HomeSummaryEntity summary) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeClock(
                  now: () => DateTime(2026, 11, 18, 9),
                  child: TodayTrainingCard(
                    summary: summary,
                    selectedDate: DateTime(2026, 11, 18),
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('a session with every exercise marked shows «Sin terminar», '
        'not «Hecha»', (tester) async {
      await pump(
        tester,
        const HomeSummaryEntity(
          trainingId: 't-1',
          totalExercises: 2,
          exercisesCompleted: 2,
          trainings: [
            HomeTrainingItemEntity(
              id: 't-1',
              name: 'Sesión t-1',
              completed: false,
              unfinished: true,
            ),
          ],
        ),
      );
      expect(find.text('Sin terminar'), findsOneWidget);
      expect(find.text('Hecha'), findsNothing);
    });

    testWidgets('rows: the finished one «Hecha», the only marked one '
        '«Sin terminar»', (tester) async {
      await pump(
        tester,
        const HomeSummaryEntity(
          trainingId: 't-1',
          totalExercises: 6,
          exercisesCompleted: 4,
          trainings: [
            HomeTrainingItemEntity(
              id: 't-1',
              name: 'Sesión t-1',
              completed: false,
            ),
            HomeTrainingItemEntity(
              id: 't-2',
              name: 'Sesión t-2',
              completed: true,
            ),
            HomeTrainingItemEntity(
              id: 't-3',
              name: 'Sesión t-3',
              completed: false,
              unfinished: true,
            ),
          ],
        ),
      );
      expect(find.text('Hecha'), findsOneWidget);
      expect(find.text('Sin terminar'), findsOneWidget);
    });

    testWidgets('r2: «Sin terminar» shows no «≈0» minutes left', (
      tester,
    ) async {
      await pump(
        tester,
        const HomeSummaryEntity(
          trainingId: 't-1',
          totalExercises: 2,
          exercisesCompleted: 2,
          totalSets: 6,
          trainingDurationMin: 45,
          remainingTrainingDurationMin: 0,
          trainings: [
            HomeTrainingItemEntity(
              id: 't-1',
              name: 'Sesión t-1',
              completed: false,
              unfinished: true,
            ),
          ],
        ),
      );
      expect(find.text('Sin terminar'), findsOneWidget);
      expect(find.text('≈0'), findsNothing);
      expect(find.text('45'), findsNothing);
      // The exercise and set figures stay.
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('r2: «Sin terminar» with another session to do keeps its '
        'minutes left', (tester) async {
      await pump(
        tester,
        const HomeSummaryEntity(
          trainingId: 't-1',
          totalExercises: 4,
          exercisesCompleted: 2,
          trainingDurationMin: 75,
          remainingTrainingDurationMin: 45,
          trainings: [
            HomeTrainingItemEntity(
              id: 't-1',
              name: 'Sesión t-1',
              completed: false,
              unfinished: true,
            ),
            HomeTrainingItemEntity(
              id: 't-2',
              name: 'Sesión t-2',
              completed: false,
            ),
          ],
        ),
      );
      expect(find.text('Sin terminar'), findsOneWidget);
      expect(find.text('≈45'), findsOneWidget);
    });

    testWidgets('a finished session shows «Hecha»', (tester) async {
      await pump(
        tester,
        const HomeSummaryEntity(
          trainingId: 't-1',
          trainingCompleted: true,
          totalExercises: 2,
          exercisesCompleted: 2,
          trainings: [
            HomeTrainingItemEntity(
              id: 't-1',
              name: 'Sesión t-1',
              completed: true,
            ),
          ],
        ),
      );
      expect(find.text('Hecha'), findsOneWidget);
      expect(find.text('Sin terminar'), findsNothing);
    });
  });
}
