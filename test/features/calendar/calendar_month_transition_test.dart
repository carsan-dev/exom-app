// L5-A4c «Calendario» month change (sketch a-diario.html#calendario, «Pulsa
// Reproducir»): while the next month loads the page keeps the month on
// screen (no page skeleton) and ignores taps on it, the arrows and the
// segmented control keep working, a slow load shows a discreet operation bar,
// and when the month arrives the grid and the protagonist figure leave and
// enter horizontally in 240 ms (towards the start when advancing). Reduced
// motion: no offset. A load error drops the kept month. The first load keeps
// the skeleton; the same month again (refresh, retry) does not animate.
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_month_grid.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_operation_bar.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:exom_app/features/calendar/presentation/pages/calendar_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/widgets/semantic_labels.dart';
import 'calendar_redesign_fixture.dart';

const _next = Key('calendar-month-next');
const _previous = Key('calendar-month-previous');
const _title = Key('calendar-month-title');

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(CalendarPage)));

Finder _cell(DateTime day) => find.byKey(ExomMonthGrid.visualKey(day));

double _x(WidgetTester tester, DateTime day) =>
    tester.getTopLeft(_cell(day)).dx;

/// A loaded month with nothing scheduled, the 1st selected.
CalendarLoaded _month(int year, int month) => sceneLoaded(
  days: const [],
  challenges: const [],
  selected: DateTime(year, month),
  year: year,
  month: month,
);

/// The protagonist numeral whose value is [value].
Finder _numeralOf(String value) => find.byWidgetPredicate(
  (widget) => widget is ExomNumeral && widget.value == value,
);

Future<SeededCalendarBloc> _mount(
  WidgetTester tester, {
  CalendarState? state,
  bool reduced = false,
}) async {
  final bloc = await pumpCalendarScene(
    tester,
    state: state ?? sceneLoaded(),
    disableAnimations: reduced,
  );
  await tester.pump(const Duration(seconds: 1));
  // Only the events this test causes (not the page's first load).
  bloc.events.clear();
  return bloc;
}

/// Moves the bloc to [state] and lets the page build it: the bloc delivers
/// its states asynchronously, so the first frame may still show the previous
/// one. Animations started by [state] begin at the returned time.
Future<void> _seed(
  WidgetTester tester,
  SeededCalendarBloc bloc,
  CalendarState state,
) async {
  bloc.seed(state);
  await tester.pump();
  await tester.pump();
}

/// Taps the next arrow and moves the bloc to loading, as a real load would.
Future<void> _requestNext(WidgetTester tester, SeededCalendarBloc bloc) =>
    _request(tester, bloc, advance: true);

/// Taps the next (or previous) arrow and moves the bloc to loading.
Future<void> _request(
  WidgetTester tester,
  SeededCalendarBloc bloc, {
  required bool advance,
}) async {
  await tester.tap(find.byKey(advance ? _next : _previous));
  await _seed(tester, bloc, const CalendarLoading());
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  testWidgets('(g) the first load shows the page skeleton', (tester) async {
    await pumpCalendarScene(tester, state: const CalendarLoading());
    expect(find.byType(ExomSkeleton), findsWidgets);
    expect(find.byType(ExomMonthGrid), findsNothing);
  });

  group('(a) month change keeps the month while loading', () {
    testWidgets('no skeleton; the previous month stays; the title shows the '
        'requested month', (tester) async {
      final bloc = await _mount(tester);
      await _requestNext(tester, bloc);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExomSkeleton), findsNothing);
      expect(_cell(DateTime(2026, 10, 15)), findsOneWidget);
      expect(
        bloc.events.whereType<CalendarMonthLoadRequested>().single.month,
        11,
      );
      final titleLabel = tester
          .getSemantics(find.byKey(_title).last)
          .label
          .toLowerCase();
      expect(titleLabel, contains('noviembre'));
    });

    testWidgets('the arrows keep working from the requested month', (
      tester,
    ) async {
      final bloc = await _mount(tester);
      await _requestNext(tester, bloc);
      await tester.tap(find.byKey(_next));
      await tester.pump();
      final requests = bloc.events.whereType<CalendarMonthLoadRequested>();
      expect(requests.map((e) => (e.year, e.month)).toList(), [
        (2026, 11),
        (2026, 12),
      ]);
      await tester.tap(find.byKey(_previous));
      await tester.pump();
      expect(
        bloc.events.whereType<CalendarMonthLoadRequested>().last.month,
        11,
      );
    });

    testWidgets('a slow load shows the operation bar over the kept month', (
      tester,
    ) async {
      final bloc = await _mount(tester);
      await _requestNext(tester, bloc);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExomOperationBar), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(ExomOperationBar), findsOneWidget);
      expect(_cell(DateTime(2026, 10, 15)), findsOneWidget);
      await _seed(tester, bloc, _month(2026, 11));
      expect(find.byType(ExomOperationBar), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  testWidgets('(b) taps on the leaving month do nothing while loading; the '
      'segmented control still works', (tester) async {
    final bloc = await _mount(tester);
    await _requestNext(tester, bloc);
    bloc.events.clear();
    await tester.tap(
      find.byKey(ExomMonthGrid.cellKey(DateTime(2026, 10, 20))),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(bloc.events.whereType<CalendarDaySelected>(), isEmpty);
    await tester.tap(find.text(_l10n(tester).diets));
    await tester.pump(const Duration(milliseconds: 300));
    final grid = tester.widget<ExomMonthGrid>(find.byType(ExomMonthGrid));
    expect(grid.markLabelOf, isNotNull, reason: 'Dietas is shown');
  });

  group('(c) the new month enters horizontally in 240 ms', () {
    for (final (name, from, to, advances) in [
      ('advance Oct -> Nov', (2026, 10), (2026, 11), true),
      ('back Oct -> Sep', (2026, 10), (2026, 9), false),
      ('advance Dec -> Jan', (2026, 12), (2027, 1), true),
      ('back Jan -> Dec', (2027, 1), (2026, 12), false),
    ]) {
      testWidgets(name, (tester) async {
        final bloc = await _mount(tester, state: _month(from.$1, from.$2));
        final oldDay = DateTime(from.$1, from.$2, 15);
        final newDay = DateTime(to.$1, to.$2, 15);
        final oldRest = _x(tester, oldDay);
        await _request(tester, bloc, advance: advances);
        // Let the title's own transition (at the tap) end first.
        await tester.pump(const Duration(milliseconds: 300));
        await _seed(tester, bloc, _month(to.$1, to.$2));
        await tester.pump(const Duration(milliseconds: 100));
        // Both months are on screen, each on its side.
        expect(_cell(oldDay), findsOneWidget);
        final oldMid = _x(tester, oldDay);
        final newMid = _x(tester, newDay);
        final numerals = find.byType(ExomNumeral);
        expect(numerals, findsNWidgets(2));
        await tester.pump(const Duration(milliseconds: 140));
        // 240 ms: the switch ends; the old month is removed on the next
        // frame and the new one is at rest.
        await tester.pump(const Duration(milliseconds: 20));
        expect(_cell(oldDay), findsNothing);
        expect(find.byType(ExomNumeral), findsOneWidget);
        final newRest = _x(tester, newDay);
        if (advances) {
          expect(oldMid, lessThan(oldRest), reason: 'leaves to the left');
          expect(newMid, greaterThan(newRest), reason: 'enters from the right');
        } else {
          expect(oldMid, greaterThan(oldRest), reason: 'leaves to the right');
          expect(newMid, lessThan(newRest), reason: 'enters from the left');
        }
        // The switchers that move the grid and the figure last 240 ms.
        final switchers = tester
            .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
            .where((s) => s.duration == ExomMotion.step);
        expect(switchers.length, greaterThanOrEqualTo(2));
        expect(ExomMotion.step, const Duration(milliseconds: 240));
      });
    }

    testWidgets('the protagonist figure moves too', (tester) async {
      final bloc = await _mount(tester);
      await _requestNext(tester, bloc);
      await _seed(tester, bloc, _month(2026, 11));
      await tester.pump(const Duration(milliseconds: 100));
      final oldX = tester.getTopLeft(_numeralOf('9')).dx;
      final newX = tester.getTopLeft(_numeralOf('0')).dx;
      expect(newX, greaterThan(oldX));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_numeralOf('9'), findsNothing);
    });

    testWidgets('the same month again (refresh) does not animate', (
      tester,
    ) async {
      final bloc = await _mount(tester);
      final rest = _x(tester, DateTime(2026, 10, 15));
      await _seed(tester, bloc, const CalendarLoading());
      await _seed(tester, bloc, sceneLoaded());
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(ExomNumeral), findsOneWidget);
      expect(_x(tester, DateTime(2026, 10, 15)), rest);
    });
  });

  testWidgets('(d) reduced motion: the month changes without offset', (
    tester,
  ) async {
    final bloc = await _mount(tester, reduced: true);
    final oldDay = DateTime(2026, 10, 15);
    final oldRest = _x(tester, oldDay);
    await _requestNext(tester, bloc);
    await _seed(tester, bloc, _month(2026, 11));
    await tester.pump(const Duration(milliseconds: 40));
    if (_cell(oldDay).evaluate().isNotEmpty) {
      expect(_x(tester, oldDay), oldRest);
    }
    final newDay = DateTime(2026, 11, 15);
    final newMid = _x(tester, newDay);
    await tester.pumpAndSettle();
    expect(_x(tester, newDay), newMid);
  });

  testWidgets('(e) an error during the change shows the error state and '
      'drops the kept month', (tester) async {
    final bloc = await _mount(tester);
    await _requestNext(tester, bloc);
    await _seed(tester, bloc, sceneServerError());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ExomMonthGrid), findsNothing);
    expect(find.byType(ExomInlineMessage), findsOneWidget);
    expect(find.byType(ExomOperationBar), findsNothing);
    // The retry is a fresh load: skeleton, not the dropped month.
    await _seed(tester, bloc, const CalendarLoading());
    expect(find.byType(ExomSkeleton), findsWidgets);
  });

  testWidgets('(f) the page slides the selected day fill in 200 ms', (
    tester,
  ) async {
    final bloc = await _mount(tester);
    final from = DateTime(2026, 10, 15);
    final to = DateTime(2026, 10, 16);
    final fill = find.byKey(ExomMonthGrid.selectionFillKey);
    final fromRect = tester.getRect(_cell(from));
    final toRect = tester.getRect(_cell(to));
    expect(tester.getRect(fill), fromRect);
    await tester.tap(find.byKey(ExomMonthGrid.cellKey(to)));
    expect(bloc.events.whereType<CalendarDaySelected>().single.date, to);
    await _seed(tester, bloc, sceneLoaded(selected: to));
    await tester.pump(const Duration(milliseconds: 100));
    final mid = tester.getRect(fill).left;
    expect(mid, greaterThan(fromRect.left));
    expect(mid, lessThan(toRect.left));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.getRect(fill), toRect);
  });

  testWidgets('mid-way only the new month is read by a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final bloc = await _mount(tester);
    expect(semanticCount(tester, 'de octubre'), greaterThan(20));
    await _requestNext(tester, bloc);
    await _seed(tester, bloc, _month(2026, 11));
    await tester.pump(const Duration(milliseconds: 100));
    // Both months are painted, one is read: one title, one set of days.
    expect(_cell(DateTime(2026, 10, 15)), findsOneWidget);
    expect(semanticCount(tester, 'de octubre'), 0);
    expect(semanticCount(tester, 'Octubre de 2026'), 0);
    expect(semanticCount(tester, 'Noviembre de 2026'), 1);
    expect(semanticCount(tester, '15 de noviembre'), 1);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('choosing the shown month in the sheet does not reload', (
    tester,
  ) async {
    final bloc = await _mount(tester, reduced: true);
    await tester.tap(find.byKey(_title));
    await tester.pumpAndSettle();
    // The sheet lists the months of the shown year; October is the shown one.
    await tester.tap(find.text('Oct').last);
    await tester.pumpAndSettle();
    expect(bloc.events.whereType<CalendarMonthLoadRequested>(), isEmpty);
    final grid = tester.widget<ExomMonthGrid>(find.byType(ExomMonthGrid));
    expect(grid.selected, kSceneSelected);
    expect(find.byType(ExomOperationBar), findsNothing);
  });
}
