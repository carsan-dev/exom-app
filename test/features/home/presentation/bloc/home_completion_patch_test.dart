// E6a, owner decision 2026-11-26: back from «Sesión hecha», HomeBloc patches
// its current content in memory with what the server confirmed (that
// training of that date done, and its day in «Tu semana») until the reload
// replaces it. Nothing is written and nothing is requested for the patch.
import 'dart:async';

import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _stamp = 'owner:1:test';

class _Repository implements HomeRepository {
  _Repository(this.summary);

  HomeSummaryEntity summary;
  int loads = 0;

  /// Holds the loads while set.
  Completer<void>? gate;

  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) async {
    loads++;
    final held = summary;
    final pending = gate;
    if (pending != null) await pending.future;
    return held;
  }
}

class _Calendar implements CalendarRepository {
  _Calendar({this.mode = 'ALL'});

  final String mode;
  int requests = 0;

  @override
  Future<List<CalendarDayEntity>> getMonthCalendar(int year, int month) async {
    requests++;
    final now = DateTime.now();
    if (now.year != year || now.month != month) return const [];
    return [
      CalendarDayEntity(
        date: DateTime(now.year, now.month, now.day),
        hasTraining: true,
        hasDiet: false,
        isRestDay: false,
        trainingCompleted: false,
        dietCompleted: false,
        trainingsAssigned: 2,
        trainingsDone: 0,
        trainingCompletionMode: mode,
      ),
    ];
  }

  @override
  Future<WeekSummaryEntity> getWeekSummary(String weekStart) =>
      throw UnimplementedError();
}

const _twoSessions = HomeSummaryEntity(
  trainingId: 't-1',
  trainingName: 'One',
  trainings: [
    HomeTrainingItemEntity(id: 't-1', name: 'One', completed: false),
    HomeTrainingItemEntity(id: 't-2', name: 'Two', completed: false),
  ],
  totalExercises: 4,
  streakDays: 3,
);

String _today() => HomeWeekMarks.dayKey(DateTime.now());

HomeDaySessions _todaySessions(HomeWeekMarks marks) {
  final dates = HomeWeekMarks.datesOf(marks.weekStart);
  final index = dates.indexWhere((d) => HomeWeekMarks.dayKey(d) == _today());
  return marks.sessions[index];
}

Future<({HomeBloc bloc, _Repository repository, _Calendar calendar})> _loaded({
  HomeSummaryEntity summary = _twoSessions,
  String mode = 'ALL',
  String? Function()? sessionStamp,
}) async {
  final repository = _Repository(summary);
  final calendar = _Calendar(mode: mode);
  final bloc = HomeBloc(
    getHomeSummaryUseCase: GetHomeSummaryUseCase(repository),
    getMonthCalendarUseCase: GetMonthCalendarUseCase(calendar),
    sessionStamp: sessionStamp ?? () => _stamp,
  );
  addTearDown(bloc.close);
  final withMarks = bloc.stream.firstWhere(
    (s) => switch (s) {
      HomeLoaded(:final weekMarks) => weekMarks != null,
      HomeRestDay(:final weekMarks) => weekMarks != null,
      _ => false,
    },
  );
  bloc.add(const HomeLoadRequested());
  await withMarks;
  return (bloc: bloc, repository: repository, calendar: calendar);
}

void main() {
  test('patches the confirmed training of a two-session day at once', () async {
    final loaded = await _loaded();
    final bloc = loaded.bloc;
    expect(_todaySessions((bloc.state as HomeLoaded).weekMarks!),
        const HomeDaySessions(2, 0));

    final patched = bloc.applyConfirmedCompletion(
      trainingId: 't-1',
      date: _today(),
      sessionStamp: _stamp,
    );

    // Synchronous: the state read by the first frame is already patched.
    expect(patched, isTrue);
    final state = bloc.state as HomeLoaded;
    expect(state.summary.trainings.map((t) => t.completed), [true, false]);
    // The day still has a session to do.
    expect(state.summary.trainingCompleted, isFalse);
    expect(_todaySessions(state.weekMarks!), const HomeDaySessions(2, 1));
    // Not deducible, so untouched.
    expect(state.summary.streakDays, 3);
    expect(state.summary.exercisesCompleted, 0);
    expect(state.refreshError, isNull);
    // Listeners get the same patched state; no request for it.
    final emitted = await bloc.stream.first;
    expect(identical(emitted, state), isTrue);
    expect(loaded.repository.loads, 1);
    expect(loaded.calendar.requests, 1);
  });

  test('the last session of the day completes the day', () async {
    final loaded = await _loaded(
      summary: const HomeSummaryEntity(
        trainingId: 't-1',
        trainings: [
          HomeTrainingItemEntity(id: 't-1', name: 'One', completed: true),
          HomeTrainingItemEntity(id: 't-2', name: 'Two', completed: false),
        ],
      ),
    );
    expect(
      loaded.bloc.applyConfirmedCompletion(
        trainingId: 't-2',
        date: _today(),
        sessionStamp: _stamp,
      ),
      isTrue,
    );
    final state = loaded.bloc.state as HomeLoaded;
    expect(state.summary.trainingCompleted, isTrue);
    expect(_todaySessions(state.weekMarks!), const HomeDaySessions(2, 2));
    expect(state.weekMarks!.markFor(DateTime.now()), HomeDayMark.done);
  });

  test('a day completed by any of its trainings counts one session', () async {
    final loaded = await _loaded(mode: 'ANY');
    loaded.bloc.applyConfirmedCompletion(
      trainingId: 't-2',
      date: _today(),
      sessionStamp: _stamp,
    );
    final state = loaded.bloc.state as HomeLoaded;
    expect(_todaySessions(state.weekMarks!), const HomeDaySessions(1, 1));
  });

  test('a day completed by any of its trainings is marked done with the '
      'count, not pending', () async {
    final loaded = await _loaded(mode: 'ANY');
    loaded.bloc.applyConfirmedCompletion(
      trainingId: 't-2',
      date: _today(),
      sessionStamp: _stamp,
    );
    final state = loaded.bloc.state as HomeLoaded;
    expect(_todaySessions(state.weekMarks!), const HomeDaySessions(1, 1));
    expect(state.weekMarks!.markFor(DateTime.now()), HomeDayMark.done);
  });

  test('a day in ALL mode with one of two done stays pending', () async {
    final loaded = await _loaded();
    loaded.bloc.applyConfirmedCompletion(
      trainingId: 't-2',
      date: _today(),
      sessionStamp: _stamp,
    );
    final state = loaded.bloc.state as HomeLoaded;
    expect(_todaySessions(state.weekMarks!), const HomeDaySessions(2, 1));
    expect(state.weekMarks!.markFor(DateTime.now()), HomeDayMark.pending);
  });

  test('a load in flight before the patch does not overwrite it', () async {
    final loaded = await _loaded();
    final bloc = loaded.bloc;
    final gate = loaded.repository.gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    bloc.add(const HomeLoadRequested());
    await pumpEventQueue();
    expect(loaded.repository.loads, 2);

    expect(
      bloc.applyConfirmedCompletion(
        trainingId: 't-1',
        date: _today(),
        sessionStamp: _stamp,
      ),
      isTrue,
    );
    // The held load answers (pending, as it was asked before the patch).
    gate.complete();
    await pumpEventQueue();

    final state = bloc.state as HomeLoaded;
    expect(state.summary.trainings.first.completed, isTrue);
    expect(_todaySessions(state.weekMarks!).done, 1);
  });

  test('a summary without the trainings list patches its single training', () async {
    final loaded = await _loaded(
      summary: const HomeSummaryEntity(trainingId: 't-1', totalExercises: 2),
    );
    expect(
      loaded.bloc.applyConfirmedCompletion(
        trainingId: 't-1',
        date: _today(),
        sessionStamp: _stamp,
      ),
      isTrue,
    );
    expect((loaded.bloc.state as HomeLoaded).summary.trainingCompleted, isTrue);
  });

  group('no patch', () {
    for (final (label, trainingId, date, stamp) in [
      ('another training', 't-9', null, _stamp),
      ('another date', 't-1', '2000-01-03', _stamp),
      ('another session', 't-1', null, 'other:1:test'),
      ('no session', 't-1', null, null),
    ]) {
      test(label, () async {
        final loaded = await _loaded();
        final before = loaded.bloc.state;
        expect(
          loaded.bloc.applyConfirmedCompletion(
            trainingId: trainingId,
            date: date ?? _today(),
            sessionStamp: stamp,
          ),
          isFalse,
        );
        expect(identical(loaded.bloc.state, before), isTrue);
      });
    }

    test('the account changed since the bloc was created', () async {
      var current = _stamp;
      final loaded = await _loaded(sessionStamp: () => current);
      current = 'other:1:test';
      expect(
        loaded.bloc.applyConfirmedCompletion(
          trainingId: 't-1',
          date: _today(),
          sessionStamp: 'other:1:test',
        ),
        isFalse,
      );
    });

    test('a bloc without the session clock never patches', () async {
      final repository = _Repository(_twoSessions);
      final bloc = HomeBloc(
        getHomeSummaryUseCase: GetHomeSummaryUseCase(repository),
      );
      addTearDown(bloc.close);
      final loaded = bloc.stream.firstWhere((s) => s is HomeLoaded);
      bloc.add(const HomeLoadRequested());
      await loaded;
      expect(
        bloc.applyConfirmedCompletion(
          trainingId: 't-1',
          date: _today(),
          sessionStamp: _stamp,
        ),
        isFalse,
      );
    });

    test('a rest day or no content yet', () async {
      final loaded = await _loaded(
        summary: const HomeSummaryEntity(isRestDay: true),
      );
      expect(
        loaded.bloc.applyConfirmedCompletion(
          trainingId: 't-1',
          date: _today(),
          sessionStamp: _stamp,
        ),
        isFalse,
      );
      final fresh = HomeBloc(
        getHomeSummaryUseCase: GetHomeSummaryUseCase(_Repository(_twoSessions)),
        sessionStamp: () => _stamp,
      );
      addTearDown(fresh.close);
      expect(
        fresh.applyConfirmedCompletion(
          trainingId: 't-1',
          date: _today(),
          sessionStamp: _stamp,
        ),
        isFalse,
      );
    });
  });
}
