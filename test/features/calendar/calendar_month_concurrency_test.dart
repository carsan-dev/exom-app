// L5-A4c month change against the REAL CalendarBloc, whose events run
// concurrently (no transformer): the month loads are answered by Completers
// in the order each test decides. The page follows only the last month it
// asked for (its target): other months' responses are never adopted, a late
// one after the target was adopted makes the page ask for the target again
// (once, no loop), taps on the month stay blocked until the target arrives,
// and an error of the target shows the error state.
import 'dart:async';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_month_grid.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_week_summary_usecase.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_challenges_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'calendar_redesign_fixture.dart';

const _next = Key('calendar-month-next');
const _previous = Key('calendar-month-previous');
const _title = Key('calendar-month-title');
const _dayBlock = Key('calendar-day-block');

/// Month loads wait for the test; the week summary answers at once unless a
/// hold is queued.
class _ControlledCalendarRepository implements CalendarRepository {
  final loads = <(int, int), List<Completer<List<CalendarDayEntity>>>>{};
  final weekHolds = <Completer<WeekSummaryEntity>>[];

  @override
  Future<List<CalendarDayEntity>> getMonthCalendar(int year, int month) {
    final completer = Completer<List<CalendarDayEntity>>();
    loads.putIfAbsent((year, month), () => []).add(completer);
    return completer.future;
  }

  @override
  Future<WeekSummaryEntity> getWeekSummary(String weekStart) {
    if (weekHolds.isNotEmpty) return weekHolds.removeAt(0).future;
    return Future.value(kSceneWeek);
  }

  int requests(int year, int month) => loads[(year, month)]?.length ?? 0;

  /// Answers the [index]th request of [year]-[month]: days 1..month have a
  /// training, all done, so the protagonist figure reads the month number.
  void answer(int year, int month, {int index = 0}) =>
      loads[(year, month)]![index].complete([
        for (var d = 1; d <= month; d++)
          CalendarDayEntity(
            date: DateTime(year, month, d),
            hasTraining: true,
            hasDiet: false,
            isRestDay: false,
            trainingCompleted: true,
            dietCompleted: false,
          ),
      ]);

  void fail(int year, int month, {int index = 0}) =>
      loads[(year, month)]![index].completeError(
        const ApiException(statusCode: 500, message: 'boom'),
      );
}

class _NoChallenges extends Fake implements ChallengesRepository {
  @override
  Future<List<ChallengeEntity>> getMyChallenges() => Future.value(const []);
}

Future<(CalendarBloc, _ControlledCalendarRepository)> _mount(
  WidgetTester tester,
) async {
  final repository = _ControlledCalendarRepository();
  final bloc = CalendarBloc(
    getMonthCalendarUseCase: GetMonthCalendarUseCase(repository),
    getWeekSummaryUseCase: GetWeekSummaryUseCase(repository),
    getMyChallengesUseCase: GetMyChallengesUseCase(_NoChallenges()),
  );
  // Not closed in the tear-down: a failed test may leave a load pending, and
  // closing the bloc would wait for it (as the seeded bloc of the fixture,
  // it is dropped with the test).
  // Reduced motion: transitions are short fades and the busy bar does not
  // loop, so the tests can settle.
  await pumpCalendarWithBloc(tester, bloc);
  repository.answer(2026, 10);
  await tester.pumpAndSettle();
  return (bloc, repository);
}

String _titleText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(_title).last, matching: find.byType(Text)),
    )
    .data!;

ExomMonthGrid _grid(WidgetTester tester) =>
    tester.widget<ExomMonthGrid>(find.byType(ExomMonthGrid));

/// True while the grid takes no taps.
bool _frozen(WidgetTester tester) => tester
    .widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byType(ExomMonthGrid),
        matching: find.byType(IgnorePointer),
      ),
    )
    .any((w) => w.ignoring);

/// The page shows [year]-[month] whole: title, grid, figure and day block,
/// and takes taps on it.
void _expectShows(WidgetTester tester, int year, int month, String name) {
  expect(_titleText(tester), name.toUpperCase());
  final grid = _grid(tester);
  expect((grid.month.year, grid.month.month), (year, month));
  expect(tester.widget<ExomNumeral>(find.byType(ExomNumeral)).value, '$month');
  expect(
    find.descendant(
      of: find.byKey(_dayBlock),
      matching: find.textContaining(RegExp(' de $name', caseSensitive: false)),
    ),
    findsWidgets,
  );
  expect(_frozen(tester), isFalse);
}

/// Still busy: the title shows the target, the kept month ignores taps.
void _expectWaiting(WidgetTester tester, String targetName, int keptMonth) {
  expect(_titleText(tester), targetName.toUpperCase());
  expect(_grid(tester).month.month, keptMonth);
  expect(_frozen(tester), isTrue);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  testWidgets('next x3, answers in order: only January is adopted', (
    tester,
  ) async {
    final (_, repo) = await _mount(tester);
    _expectShows(tester, 2026, 10, 'octubre');
    await _tap(tester, _next);
    await _tap(tester, _next);
    await _tap(tester, _next);
    _expectWaiting(tester, 'enero', 10);
    repo.answer(2026, 11);
    await tester.pumpAndSettle();
    _expectWaiting(tester, 'enero', 10);
    repo.answer(2026, 12);
    await tester.pumpAndSettle();
    _expectWaiting(tester, 'enero', 10);
    repo.answer(2027, 1);
    await tester.pumpAndSettle();
    _expectShows(tester, 2027, 1, 'enero');
    expect(repo.requests(2027, 1), 1);
  });

  testWidgets('next x3, answers out of order: a late month after January '
      're-asks January once', (tester) async {
    final (bloc, repo) = await _mount(tester);
    await _tap(tester, _next);
    await _tap(tester, _next);
    await _tap(tester, _next);
    repo.answer(2027, 1);
    await tester.pumpAndSettle();
    _expectShows(tester, 2027, 1, 'enero');
    // November arrives late: not adopted; the bloc settled on November, so
    // the page asks for January again and waits on it.
    repo.answer(2026, 11);
    await tester.pumpAndSettle();
    expect(repo.requests(2027, 1), 2);
    _expectWaiting(tester, 'enero', 1);
    // December too, while the re-request is pending: no further request.
    repo.answer(2026, 12);
    await tester.pumpAndSettle();
    expect(repo.requests(2027, 1), 2);
    _expectWaiting(tester, 'enero', 1);
    repo.answer(2027, 1, index: 1);
    await tester.pumpAndSettle();
    _expectShows(tester, 2027, 1, 'enero');
    final state = bloc.state as CalendarLoaded;
    expect((state.year, state.month), (2027, 1));
    expect(repo.requests(2027, 1), 2);
  });

  testWidgets('next then back, the answer of next arriving last', (
    tester,
  ) async {
    final (bloc, repo) = await _mount(tester);
    await _tap(tester, _next);
    await _tap(tester, _previous);
    _expectWaiting(tester, 'octubre', 10);
    repo.answer(2026, 10, index: 1);
    await tester.pumpAndSettle();
    _expectShows(tester, 2026, 10, 'octubre');
    repo.answer(2026, 11);
    await tester.pumpAndSettle();
    expect(repo.requests(2026, 10), 3);
    _expectWaiting(tester, 'octubre', 10);
    repo.answer(2026, 10, index: 2);
    await tester.pumpAndSettle();
    _expectShows(tester, 2026, 10, 'octubre');
    final state = bloc.state as CalendarLoaded;
    expect((state.year, state.month), (2026, 10));
  });

  testWidgets('a day selected in the old month answered during the load', (
    tester,
  ) async {
    final (bloc, repo) = await _mount(tester);
    final hold = Completer<WeekSummaryEntity>();
    repo.weekHolds.add(hold);
    final day = DateTime(2026, 10, 16);
    await tester.tap(find.byKey(ExomMonthGrid.cellKey(day)));
    await tester.pump();
    await _tap(tester, _next);
    _expectWaiting(tester, 'noviembre', 10);
    // Taps on the kept month do nothing.
    await tester.tap(
      find.byKey(ExomMonthGrid.cellKey(DateTime(2026, 10, 20))),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    repo.answer(2026, 11);
    await tester.pumpAndSettle();
    _expectShows(tester, 2026, 11, 'noviembre');
    // The selection of October answers now: not adopted, November re-asked.
    hold.complete(kSceneWeek);
    await tester.pumpAndSettle();
    expect(repo.requests(2026, 11), 2);
    _expectWaiting(tester, 'noviembre', 11);
    repo.answer(2026, 11, index: 1);
    await tester.pumpAndSettle();
    _expectShows(tester, 2026, 11, 'noviembre');
    expect(_grid(tester).selected, DateTime(2026, 11));
    final state = bloc.state as CalendarLoaded;
    expect((state.year, state.month), (2026, 11));
  });

  testWidgets('an error of the target shows the error state', (tester) async {
    final (_, repo) = await _mount(tester);
    await _tap(tester, _next);
    _expectWaiting(tester, 'noviembre', 10);
    repo.fail(2026, 11);
    await tester.pumpAndSettle();
    expect(find.byType(ExomMonthGrid), findsNothing);
    expect(find.byType(ExomInlineMessage), findsOneWidget);
  });
}
