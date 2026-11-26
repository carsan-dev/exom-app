// L5-E1 (L5-D27, exception EX-Q6): for a day with neither training nor diet
// in the summary, HomeBloc tells a rest day from a day without assignment
// using the `/calendar/month` fields it already loads for the week strip.
// Without the calendar (no use case, failure, not answered yet) the day keeps
// the single state of today (Q11 default); an answer for another week or an
// older request never changes the visible day.
import 'dart:async';

import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pages/home_e1_harness.dart';

HomeBloc _bloc(InicioE1Calendar? calendar) => HomeBloc(
  getHomeSummaryUseCase: GetHomeSummaryUseCase(
    InicioE1Repository((_) => inicioE1Empty),
  ),
  getMonthCalendarUseCase: calendar == null
      ? null
      : GetMonthCalendarUseCase(calendar),
);

Future<HomeRestDay> _settled(HomeBloc bloc, DateTime date) async {
  bloc.add(HomeLoadRequested(date: date));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return bloc.state as HomeRestDay;
}

void main() {
  test('HomeDayPlan.ofCalendarDay follows is_rest_day and the assignment', () {
    expect(
      HomeDayPlan.ofCalendarDay(
        InicioE1Calendar.day('2026-11-18', rest: true),
      ),
      HomeDayPlan.rest,
    );
    expect(
      HomeDayPlan.ofCalendarDay(InicioE1Calendar.day('2026-11-18')),
      HomeDayPlan.unassigned,
    );
    // Q11: an assignment without rest whose trainings are inactive.
    expect(
      HomeDayPlan.ofCalendarDay(
        InicioE1Calendar.day('2026-11-18', training: true),
      ),
      HomeDayPlan.assigned,
    );
    expect(
      HomeDayPlan.ofCalendarDay(InicioE1Calendar.day('2026-11-18', diet: true)),
      HomeDayPlan.assigned,
    );
  });

  test('a calendar rest day is «rest», a day without assignment is '
      '«unassigned»', () async {
    final calendar = InicioE1Calendar(
      InicioE1Calendar.week({
        '2026-11-19': InicioE1Calendar.day('2026-11-19', rest: true),
      }),
    );
    final bloc = _bloc(calendar);
    addTearDown(bloc.close);

    expect(
      (await _settled(bloc, DateTime(2026, 11, 18))).dayPlan,
      HomeDayPlan.unassigned,
    );
    expect(
      (await _settled(bloc, DateTime(2026, 11, 19))).dayPlan,
      HomeDayPlan.rest,
    );
  });

  test('without the calendar the day keeps the single state', () async {
    final none = _bloc(null);
    addTearDown(none.close);
    expect(
      (await _settled(none, DateTime(2026, 11, 18))).dayPlan,
      HomeDayPlan.unknown,
    );

    final failing = _bloc(
      InicioE1Calendar(const {}, error: Exception('offline')),
    );
    addTearDown(failing.close);
    expect(
      (await _settled(failing, DateTime(2026, 11, 18))).dayPlan,
      HomeDayPlan.unknown,
    );
  });

  test('a calendar that answers later updates the day', () async {
    final calendar = InicioE1Calendar(InicioE1Calendar.week(const {}));
    final gate = calendar.gates[0] = Completer<void>();
    final bloc = _bloc(calendar);
    addTearDown(bloc.close);

    bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((bloc.state as HomeRestDay).dayPlan, HomeDayPlan.unknown);

    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((bloc.state as HomeRestDay).dayPlan, HomeDayPlan.unassigned);
  });

  test('a late answer for another week does not change the visible day', () async {
    // Request 0: week of 16-22 Nov, held; it would call 25 Nov unassigned.
    // Request 1: week of 23-29 Nov, where 25 Nov is a rest day.
    final calendar = InicioE1Calendar(const {});
    final gate = calendar.gates[0] = Completer<void>();
    calendar.daysFor[0] = {
      '2026-11-18': InicioE1Calendar.day('2026-11-18'),
      '2026-11-25': InicioE1Calendar.day('2026-11-25'),
    };
    calendar.daysFor[1] = {
      '2026-11-25': InicioE1Calendar.day('2026-11-25', rest: true),
    };
    final bloc = _bloc(calendar);
    addTearDown(bloc.close);

    bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bloc.add(HomeDateSelected(DateTime(2026, 11, 25)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((bloc.state as HomeRestDay).dayPlan, HomeDayPlan.rest);

    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final state = bloc.state as HomeRestDay;
    expect(state.selectedDate, DateTime(2026, 11, 25));
    expect(state.dayPlan, HomeDayPlan.rest);
  });

  test('a newer full reload drops the answer of the previous one', () async {
    // Request 0 (held) says 18 Nov is unassigned; the reload's request 1
    // says it is a rest day. The old answer must not win.
    final calendar = InicioE1Calendar(const {});
    final gate = calendar.gates[0] = Completer<void>();
    calendar.daysFor[0] = {'2026-11-18': InicioE1Calendar.day('2026-11-18')};
    calendar.daysFor[1] = {
      '2026-11-18': InicioE1Calendar.day('2026-11-18', rest: true),
    };
    final bloc = _bloc(calendar);
    addTearDown(bloc.close);

    bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 18)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((bloc.state as HomeRestDay).dayPlan, HomeDayPlan.rest);

    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((bloc.state as HomeRestDay).dayPlan, HomeDayPlan.rest);
  });
}
