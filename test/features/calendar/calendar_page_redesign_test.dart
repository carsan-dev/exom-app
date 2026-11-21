// L5-A4a «Calendario» (docs/plans/rediseno-app-l5-contrato-v2.md, L5-A4 and
// §3.0): month header, Entrenamiento / Dietas segmented control, ExomMonthGrid
// with marks and challenge flags, the protagonist numeral, the selected-day
// block (rest day, empty day, challenges), empty month, loading and offline,
// the D19 colours and the common criteria CC 3 and CC 4; L4-I22 (toggle and
// month title at 360 dp with text 1.3x / 1.6x and at 320 dp with 1.3x).
// The bloc is seeded: loading, selection and month changes are only recorded
// as events; the export flow is covered by calendar_shopping_list_export_test.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_arrival.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_month_grid.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:exom_app/features/calendar/presentation/pages/calendar_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../core/widgets/exom_component_harness.dart';
import '../../core/widgets/exom_text_component_matrix.dart';
import '../../core/widgets/expect_no_lime_ink.dart';
import 'calendar_redesign_fixture.dart';

const _title = Key('calendar-month-title');
const _previous = Key('calendar-month-previous');
const _next = Key('calendar-month-next');
const _dayBlock = Key('calendar-day-block');
const _trainingRow = Key('calendar-row-training');
const _dietRow = Key('calendar-row-diet');
const _restRow = Key('calendar-row-rest');
const _emptyRow = Key('calendar-row-empty');
const _challengesRow = Key('calendar-row-challenges');
const _challengesShortcut = Key('calendar-challenges-shortcut');

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(CalendarPage)));

ExomMonthGrid _grid(WidgetTester tester) =>
    tester.widget<ExomMonthGrid>(find.byType(ExomMonthGrid));

ExomNumeral _numeral(WidgetTester tester) =>
    tester.widget<ExomNumeral>(find.byType(ExomNumeral));

Future<void> _tapDiets(WidgetTester tester) async {
  await tester.tap(find.text(_l10n(tester).diets));
  await tester.pumpAndSettle();
}

/// Paragraphs painted under [root].
Iterable<RenderParagraph> _paragraphs(Finder root) => find
    .descendant(of: root, matching: find.byType(RichText))
    .evaluate()
    .map((e) => e.renderObject! as RenderParagraph);

/// The text under [root] is painted whole and inside the [width] surface.
void _expectWholeInside(WidgetTester tester, Finder root, double width) {
  expect(root, findsWidgets);
  for (final paragraph in _paragraphs(root)) {
    final text = paragraph.text.toPlainText();
    expect(textHidingReason(paragraph), isNull, reason: 'cut: "$text"');
    final topLeft = paragraph.localToGlobal(Offset.zero);
    final bottomRight = paragraph.localToGlobal(
      paragraph.size.bottomRight(Offset.zero),
    );
    expect(topLeft.dx, greaterThanOrEqualTo(-0.01), reason: text);
    expect(bottomRight.dx, lessThanOrEqualTo(width + 0.01), reason: text);
  }
}

/// No word of the text under [root] is broken across lines: each paragraph is
/// at least as wide as its widest unbreakable word (its min intrinsic width).
void _expectNoBrokenWord(Finder root) {
  expect(root, findsWidgets);
  for (final paragraph in _paragraphs(root)) {
    final text = paragraph.text.toPlainText();
    final widestWord = paragraph.getMinIntrinsicWidth(double.infinity);
    expect(
      widestWord,
      lessThanOrEqualTo(paragraph.size.width + 0.01),
      reason: 'word broken in "$text"',
    );
  }
}

/// Colour of the first painted span of the Text that shows exactly [text]
/// under [root].
Color? _inkOf(WidgetTester tester, Finder root, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find
        .descendant(
          of: find.descendant(of: root, matching: find.text(text)).first,
          matching: find.byType(RichText),
        )
        .first,
  );
  Color? colour;
  paragraph.text.visitChildren((span) {
    colour ??= span.style?.color;
    return colour == null;
  });
  return colour ?? paragraph.text.style?.color;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  group('L4-I22: toggle and month title neither overflow nor get cut', () {
    for (final (width, scale) in const [
      (360.0, 1.3),
      (360.0, 1.6),
      (320.0, 1.3),
    ]) {
      testWidgets('$width dp at ${scale}x', (tester) async {
        await pumpCalendarScene(
          tester,
          state: sceneLoaded(),
          width: width,
          textScale: scale,
        );
        expectNoOverflow(tester);
        final l10n = _l10n(tester);
        _expectWholeInside(tester, find.byKey(_title), width);
        final toggle = find.byType(ExomSegmentedControl<bool>);
        _expectWholeInside(tester, toggle, width);
        for (final label in [l10n.training, l10n.diets]) {
          final text = find.descendant(of: toggle, matching: find.text(label));
          expect(text, findsOneWidget);
          // One word: one line (a word broken in two is a cut label).
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.lines, 1, reason: label);
        }
      });
    }
  });

  // L5-A4 D1 (emulator, Android 15): with the nonlinear font scale of Android
  // 14+ «Entrenamiento» broke into «Entrenamient / o» at 360 dp 1.6x and at
  // 320 dp 1.3x, while the linear TextScaler of the tests fitted it.
  group('L4-I22 D1: no word of the toggle or the title breaks', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final width in const [320.0, 360.0]) {
        for (final scale in const [1.0, 1.3, 1.6]) {
          for (final android in [false, true]) {
            testWidgets('${locale.languageCode} $width dp ${scale}x '
                '${android ? 'Android nonlinear' : 'linear'}', (tester) async {
              await pumpCalendarScene(
                tester,
                state: sceneLoaded(),
                width: width,
                textScale: scale,
                textScaler: android ? AndroidNonlinearTextScaler(scale) : null,
                locale: locale,
              );
              expectNoOverflow(tester);
              _expectNoBrokenWord(find.byType(ExomSegmentedControl<bool>));
              _expectNoBrokenWord(find.byKey(_title));
            });
          }
        }
      }
    }
  });

  group('month header', () {
    testWidgets('title is the month, a button that opens the month picker', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCalendarScene(tester, state: sceneLoaded());
      final l10n = _l10n(tester);
      final month = toBeginningOfSentenceCase(
        DateFormat.yMMMM('es').format(DateTime(2026, 10)),
      );
      expect(
        find.descendant(of: find.byKey(_title), matching: find.text('OCTUBRE')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(_title)),
        matchesSemantics(
          label: l10n.calendarMonthTitleLabel(month),
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
      await tester.tap(find.byKey(_title));
      await tester.pumpAndSettle();
      // L5-A4b (D14-2): the picker is a straight sheet, no longer a dialog.
      expect(find.byKey(const Key('exom-sheet-panel')), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('arrows load the previous and the next month', (tester) async {
      final bloc = await pumpCalendarScene(tester, state: sceneLoaded());
      bloc.events.clear();
      await tester.tap(find.byKey(_previous));
      await tester.tap(find.byKey(_next));
      final loads = bloc.events.whereType<CalendarMonthLoadRequested>();
      expect(loads.map((e) => (e.year, e.month, e.selectedDate)), [
        (2026, 9, null),
        (2026, 11, null),
      ]);
    });

    testWidgets('a horizontal swipe on the grid changes month, as before', (
      tester,
    ) async {
      final bloc = await pumpCalendarScene(tester, state: sceneLoaded());
      bloc.events.clear();
      await tester.fling(
        find.byType(ExomMonthGrid),
        const Offset(-300, 0),
        1200,
      );
      await tester.pumpAndSettle();
      // L5-A4c: the grid takes no gestures until the month asked for
      // arrives, so the second swipe starts from November once loaded.
      bloc.seed(sceneLoaded(month: 11));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(ExomMonthGrid),
        const Offset(300, 0),
        1200,
      );
      await tester.pumpAndSettle();
      final loads = bloc.events.whereType<CalendarMonthLoadRequested>();
      expect(loads.map((e) => (e.year, e.month, e.selectedDate)), [
        (2026, 11, kSceneSelected),
        (2026, 10, kSceneSelected),
      ]);
    });
  });

  group('segmented control', () {
    testWidgets('Entrenamiento / Dietas with ExomSegmentedControl', (
      tester,
    ) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      final l10n = _l10n(tester);
      final control = tester.widget<ExomSegmentedControl<bool>>(
        find.byType(ExomSegmentedControl<bool>),
      );
      expect(control.options.map(control.labelOf), [l10n.training, l10n.diets]);
      expect(control.selected, isTrue);
      await _tapDiets(tester);
      expect(
        tester
            .widget<ExomSegmentedControl<bool>>(
              find.byType(ExomSegmentedControl<bool>),
            )
            .selected,
        isFalse,
      );
    });
  });

  group('month grid', () {
    testWidgets('ExomMonthGrid of the loaded month with the selected day, '
        'done days as lime fill (no lime button on the screen)', (
      tester,
    ) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      final grid = _grid(tester);
      expect((grid.month.year, grid.month.month), (2026, 10));
      expect(grid.selected, kSceneSelected);
      expect(grid.doneAsFill, isTrue);
      expect(find.byType(ExomPrimaryButton), findsNothing);
      await _tapDiets(tester);
      expect(_grid(tester).doneAsFill, isTrue);
      expect(find.byType(ExomPrimaryButton), findsNothing);
    });

    testWidgets('training marks: done, not done before today, none', (
      tester,
    ) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      final grid = _grid(tester);
      expect(grid.markOf(DateTime(2026, 10, 1)), ExomDayMark.done);
      expect(grid.markOf(DateTime(2026, 10, 15)), ExomDayMark.missed);
      expect(grid.markOf(DateTime(2026, 10, 3)), ExomDayMark.none);
      expect(grid.markOf(DateTime(2026, 10, 25)), ExomDayMark.none);
    });

    testWidgets('diet marks follow the Dietas tab', (tester) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      await _tapDiets(tester);
      final grid = _grid(tester);
      expect(grid.markOf(DateTime(2026, 10, 14)), ExomDayMark.done);
      expect(grid.markOf(DateTime(2026, 10, 25)), ExomDayMark.missed);
      expect(grid.markOf(DateTime(2026, 10, 3)), ExomDayMark.none);
    });

    testWidgets('a future scheduled day is pending', (tester) async {
      final day = DateTime(2100, 1, 5);
      await pumpCalendarScene(
        tester,
        state: sceneLoaded(
          days: [
            CalendarDayEntity(
              date: day,
              hasTraining: true,
              hasDiet: true,
              isRestDay: false,
              trainingCompleted: false,
              dietCompleted: false,
            ),
          ],
          challenges: const [],
          selected: day,
          year: 2100,
          month: 1,
        ),
      );
      expect(_grid(tester).markOf(day), ExomDayMark.pending);
      await _tapDiets(tester);
      expect(_grid(tester).markOf(day), ExomDayMark.pending);
    });

    testWidgets('tapping a day selects it', (tester) async {
      final bloc = await pumpCalendarScene(tester, state: sceneLoaded());
      bloc.events.clear();
      final day = DateTime(2026, 10, 20);
      await tester.tap(find.byKey(ExomMonthGrid.cellKey(day)));
      expect(bloc.events.whereType<CalendarDaySelected>().map((e) => e.date), [
        day,
      ]);
    });

    // L5-A4 O4 (emulator): in Dietas the days were announced with the
    // training marks («sesión hecha / no hecha»).
    testWidgets('Dietas: the days announce the diet marks, not sessions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCalendarScene(tester, state: sceneLoaded());
      String label(int day) => tester
          .getSemantics(
            find.byKey(ExomMonthGrid.cellKey(DateTime(2026, 10, day))),
          )
          .label;
      String date(int day) =>
          DateFormat.MMMMEEEEd('es').format(DateTime(2026, 10, day));
      // Entrenamiento: the training marks stay.
      expect(label(2), '${date(2)}, sesión hecha');
      expect(label(19), '${date(19)}, sesión no hecha');
      await _tapDiets(tester);
      // Day 2: diet completed; 20: diet not completed; 3: rest, no diet mark.
      expect(label(2), '${date(2)}, dieta completada');
      expect(label(20), '${date(20)}, dieta sin completar');
      expect(label(3), date(3));
      handle.dispose();
    });

    testWidgets('a day with a challenge carries the flag and says so', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCalendarScene(tester, state: sceneLoaded());
      final l10n = _l10n(tester);
      final grid = _grid(tester);
      // The page tells the grid which days carry a challenge (the painted
      // flag itself is covered by exom_month_grid_test.dart).
      expect(grid.flagOf!(kSceneChallengeDay), isTrue);
      expect(grid.flagOf!(DateTime(2026, 10, 20)), isFalse);
      final date = DateFormat.MMMMEEEEd('es').format(kSceneChallengeDay);
      expect(
        tester
            .getSemantics(find.byKey(ExomMonthGrid.cellKey(kSceneChallengeDay)))
            .label,
        l10n.calendarDayWithChallenge(date),
      );
      handle.dispose();
    });
  });

  group('protagonist numeral', () {
    testWidgets('training: sessions done of the month', (tester) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      final l10n = _l10n(tester);
      final numeral = _numeral(tester);
      expect((numeral.value, numeral.unit, numeral.isData), ('9', '/12', true));
      expect(find.text(l10n.calendarHeroTrainingFoot), findsOneWidget);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(
        (headline.first, headline.second),
        (l10n.calendarHeroTrainingFirst, l10n.calendarHeroTrainingSecond),
      );
    });

    testWidgets('diets: meals done this week', (tester) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      await _tapDiets(tester);
      final l10n = _l10n(tester);
      final numeral = _numeral(tester);
      expect((numeral.value, numeral.unit, numeral.isData), ('9', '/28', true));
      expect(find.text(l10n.calendarHeroDietFoot), findsOneWidget);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(
        (headline.first, headline.second),
        (l10n.calendarHeroDietFirst, l10n.calendarHeroDietSecond),
      );
    });

    // The bloc swallows a failed week summary (weekSummary null): Dietas must
    // not invent «0 comidas esta semana».
    testWidgets('diets without week summary: no meals figure, no invented 0', (
      tester,
    ) async {
      await pumpCalendarScene(tester, state: sceneLoaded(week: null));
      // Entrenamiento does not depend on the week summary.
      expect(_numeral(tester).value, '9');
      await _tapDiets(tester);
      final l10n = _l10n(tester);
      expect(find.byType(ExomNumeral), findsNothing);
      expect(find.text(l10n.calendarHeroDietFoot), findsNothing);
      expect(find.byType(ExomMonthGrid), findsOneWidget);
      expect(find.byKey(_dietRow), findsOneWidget);
    });

    testWidgets('figures follow the locale without thousands separator', (
      tester,
    ) async {
      await pumpCalendarScene(
        tester,
        state: sceneLoaded(
          week: const WeekSummaryEntity(
            weekStart: '2026-10-12',
            trainingsAssigned: 4,
            trainingsCompleted: 3,
            totalMeals: 1200,
            mealsCompleted: 1000,
          ),
        ),
        locale: const Locale('en'),
      );
      await _tapDiets(tester);
      final numeral = _numeral(tester);
      expect((numeral.value, numeral.unit), ('1000', '/1200'));
    });
  });

  group('selected day block', () {
    testWidgets('kicker with the date, week line, training and diet rows', (
      tester,
    ) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      final l10n = _l10n(tester);
      final block = find.byKey(_dayBlock);
      expect(
        find.ancestor(of: block, matching: find.byType(ExomFeatureBlock)),
        findsOneWidget,
      );
      final date = toBeginningOfSentenceCase(
        DateFormat.MMMMEEEEd('es').format(kSceneSelected),
      );
      expect(
        tester
            .widget<ExomKicker>(
              find.descendant(of: block, matching: find.byType(ExomKicker)),
            )
            .text,
        date,
      );
      expect(
        find.descendant(
          of: block,
          matching: find.text(l10n.calendarWeekTrainings('3', '4')),
        ),
        findsOneWidget,
      );
      final training = tester.widget<ExomRichRow>(find.byKey(_trainingRow));
      expect(training.title, l10n.training);
      final diet = tester.widget<ExomRichRow>(find.byKey(_dietRow));
      expect(diet.title, l10n.nutritionPlanDefault);
      expect(
        find.descendant(
          of: find.byKey(_trainingRow),
          matching: find.text(l10n.pending),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the whole row opens the training or the diet of that day', (
      tester,
    ) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      await tester.ensureVisible(find.byKey(_trainingRow));
      await tester.tap(find.byKey(_trainingRow));
      await tester.pumpAndSettle();
      expect(openedRoutes, ['/trainings?date=2026-10-15']);

      await pumpCalendarScene(tester, state: sceneLoaded());
      await tester.ensureVisible(find.byKey(_dietRow));
      await tester.tap(find.byKey(_dietRow));
      await tester.pumpAndSettle();
      expect(openedRoutes, ['/diets?date=2026-10-15']);
    });

    testWidgets('Dietas shows only the diet row, without the week line', (
      tester,
    ) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      await _tapDiets(tester);
      final l10n = _l10n(tester);
      expect(find.byKey(_dietRow), findsOneWidget);
      expect(find.byKey(_trainingRow), findsNothing);
      expect(find.text(l10n.calendarWeekTrainings('3', '4')), findsNothing);
    });

    for (final brightness in Brightness.values) {
      testWidgets('D19: «done» in the data colour (${brightness.name})', (
        tester,
      ) async {
        await pumpCalendarScene(
          tester,
          state: sceneLoaded(selected: DateTime(2026, 10, 16)),
          brightness: brightness,
        );
        final l10n = _l10n(tester);
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        expect(
          _inkOf(tester, find.byKey(_trainingRow), l10n.completed),
          palette.data,
        );
        final check = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(_trainingRow),
            matching: find.byIcon(ExomIcons.check),
          ),
        );
        expect(check.color, palette.data);
      });
    }

    testWidgets('rest day: one «Día de descanso» row', (tester) async {
      await pumpCalendarScene(
        tester,
        state: sceneLoaded(selected: DateTime(2026, 10, 4)),
      );
      final l10n = _l10n(tester);
      final rest = tester.widget<ExomRichRow>(find.byKey(_restRow));
      expect(
        (rest.title, rest.facts),
        (l10n.restDayTitle, l10n.calendarRestDayFacts),
      );
      expect(rest.onTap, isNull);
      expect(find.byKey(_trainingRow), findsNothing);
    });

    // `has_diet` comes from the API independently of `is_rest_day`: a rest day
    // can carry a diet, so the rest row only speaks about training and the
    // diet row is shown as on any other day, in both tabs.
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final training in [true, false]) {
        testWidgets('rest day with a diet: the diet row is shown and the rest '
            'row does not deny the diet '
            '(${locale.languageCode}, ${training ? 'training' : 'diets'})', (
          tester,
        ) async {
          final restDay = DateTime(2026, 10, 4);
          await pumpCalendarScene(
            tester,
            state: sceneLoaded(
              days: [
                for (final d in sceneDays())
                  if (d.date == restDay)
                    CalendarDayEntity(
                      date: restDay,
                      hasTraining: false,
                      hasDiet: true,
                      isRestDay: true,
                      trainingCompleted: false,
                      dietCompleted: false,
                    )
                  else
                    d,
              ],
              selected: restDay,
            ),
            locale: locale,
          );
          if (!training) await _tapDiets(tester);
          final l10n = _l10n(tester);
          final rest = tester.widget<ExomRichRow>(find.byKey(_restRow));
          expect(rest.facts, l10n.calendarRestDayFacts);
          final denial = locale.languageCode == 'es' ? 'dieta' : 'diet';
          expect(rest.facts!.toLowerCase(), isNot(contains(denial)));
          expect(find.byKey(_dietRow), findsOneWidget);
          expect(
            tester.widget<ExomRichRow>(find.byKey(_dietRow)).title,
            l10n.nutritionPlanDefault,
          );
          expect(find.byKey(_trainingRow), findsNothing);
          await tester.ensureVisible(find.byKey(_dietRow));
          await tester.tap(find.byKey(_dietRow));
          await tester.pumpAndSettle();
          expect(openedRoutes, ['/diets?date=2026-10-04']);
        });
      }
    }

    testWidgets('day without anything: «Sin actividad asignada»', (
      tester,
    ) async {
      await pumpCalendarScene(
        tester,
        state: sceneLoaded(
          days: sceneDays()
              .where((d) => d.date.day != 25)
              .toList(growable: false),
          selected: DateTime(2026, 10, 25),
        ),
      );
      final l10n = _l10n(tester);
      expect(
        tester.widget<ExomRichRow>(find.byKey(_emptyRow)).title,
        l10n.noActivityAssigned,
      );
    });

    testWidgets('day with a challenge: «Retos» row that opens challenges', (
      tester,
    ) async {
      await pumpCalendarScene(
        tester,
        state: sceneLoaded(selected: kSceneChallengeDay),
      );
      final l10n = _l10n(tester);
      final row = tester.widget<ExomRichRow>(find.byKey(_challengesRow));
      expect((row.title, row.facts), (l10n.challenges, '1 reto activo hoy'));
      await tester.ensureVisible(find.byKey(_challengesRow));
      await tester.tap(find.byKey(_challengesRow));
      await tester.pumpAndSettle();
      expect(openedRoutes, ['/challenges']);
    });

    // L5-D36: the sketch's «1 reto activo hoy» comes from the challenges of
    // the day (ICU plural, figures with formatFigure, L5-D33).
    for (final (locale, count, expected) in const [
      (Locale('es'), 1, '1 reto activo hoy'),
      (Locale('es'), 3, '3 retos activos hoy'),
      (Locale('en'), 1, '1 active challenge today'),
      (Locale('en'), 3, '3 active challenges today'),
    ]) {
      testWidgets('challenges of the day: «$expected»', (tester) async {
        await pumpCalendarScene(
          tester,
          state: sceneLoaded(
            selected: kSceneChallengeDay,
            challenges: [
              for (var i = 0; i < count; i++) sceneChallenge(title: 'Reto $i'),
            ],
          ),
          locale: locale,
        );
        expect(
          tester.widget<ExomRichRow>(find.byKey(_challengesRow)).facts,
          expected,
        );
      });
    }

    testWidgets('a day without challenges has no «Retos» row', (tester) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      expect(find.byKey(_challengesRow), findsNothing);
    });

    testWidgets('the challenges count is not lime ink (light)', (tester) async {
      await pumpCalendarScene(
        tester,
        state: sceneLoaded(selected: kSceneChallengeDay),
        brightness: Brightness.light,
      );
      final palette = themeFor(Brightness.light).extension<ExomThemePalette>()!;
      expect(
        _inkOf(tester, find.byKey(_challengesRow), '1 reto activo hoy'),
        palette.textSecondary,
      );
      expectNoLimeInk(tester);
    });

    testWidgets('the challenges shortcut stays below the day', (tester) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      final l10n = _l10n(tester);
      await tester.ensureVisible(find.byKey(_challengesShortcut));
      expect(
        find.descendant(
          of: find.byKey(_challengesShortcut),
          matching: find.text(l10n.challengesMenuItem),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_challengesShortcut));
      await tester.pumpAndSettle();
      expect(openedRoutes, ['/challenges']);
    });

    testWidgets('export is an outlined button, only in Dietas', (tester) async {
      await pumpCalendarScene(tester, state: sceneLoaded());
      final l10n = _l10n(tester);
      expect(find.text(l10n.exportDietButton), findsNothing);
      await _tapDiets(tester);
      expect(
        find.widgetWithText(OutlinedButton, l10n.exportDietButton),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('states', () {
    testWidgets('month without activity: plain 0 and the flat empty state', (
      tester,
    ) async {
      await pumpCalendarScene(tester, state: sceneEmpty());
      final l10n = _l10n(tester);
      final numeral = _numeral(tester);
      expect((numeral.value, numeral.unit, numeral.isData), ('0', null, false));
      expect(
        find.text(l10n.calendarHeroNoSessions.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(l10n.calendarHeroNoSessionsFoot('2026')),
        findsOneWidget,
      );
      final empty = tester.widget<ExomEmptyState>(find.byType(ExomEmptyState));
      expect(
        (empty.first, empty.second, empty.lead, empty.body),
        (
          l10n.calendarEmptyMonthFirst,
          l10n.calendarEmptyMonthSecond,
          l10n.noActivitiesThisMonth,
          l10n.noActivitiesThisMonthSubtitle,
        ),
      );
      expect(find.byKey(_dayBlock), findsNothing);
      expect(find.byType(ExomMonthGrid), findsOneWidget);
      expect(find.byType(GlassCard), findsNothing);
    });

    testWidgets('loading: flat skeletons, no shimmer cards', (tester) async {
      await pumpCalendarScene(tester, state: const CalendarLoading());
      expect(find.byType(ExomSkeleton), findsWidgets);
      expect(find.byType(ExomFeatureBlock), findsOneWidget);
      expect(find.byType(ShimmerCard), findsNothing);
      expect(find.byType(GlassCard), findsNothing);
    });

    testWidgets(
      'offline: title, toggle, headline and inline error with retry',
      (tester) async {
        final bloc = await pumpCalendarScene(tester, state: sceneOffline());
        final l10n = _l10n(tester);
        final now = DateTime.now();
        final month = DateFormat.MMMM('es').format(now).toUpperCase();
        expect(
          find.descendant(of: find.byKey(_title), matching: find.text(month)),
          findsOneWidget,
        );
        expect(find.byType(ExomSegmentedControl<bool>), findsOneWidget);
        final headline = tester.widget<ExomTwoLineHeadline>(
          find.byType(ExomTwoLineHeadline),
        );
        expect(
          (headline.first, headline.second),
          (l10n.calendarOfflineFirst, l10n.calendarOfflineSecond),
        );
        final message = tester.widget<ExomInlineMessage>(
          find.byType(ExomInlineMessage),
        );
        expect(
          (message.kind, message.title, message.body, message.actionLabel),
          (
            ExomMessageKind.error,
            l10n.calendarOfflineMessage,
            l10n.noConnectionMessage,
            l10n.retryButton,
          ),
        );
        expect(find.byType(NoConnectionWidget), findsNothing);
        bloc.events.clear();
        await tester.tap(find.text(l10n.retryButton));
        final loads = bloc.events.whereType<CalendarMonthLoadRequested>();
        expect(loads.map((e) => (e.year, e.month)), [(now.year, now.month)]);
      },
    );

    testWidgets(
      'server error: inline error with retry, no full-screen widget',
      (tester) async {
        final bloc = await pumpCalendarScene(tester, state: sceneServerError());
        final l10n = _l10n(tester);
        final message = tester.widget<ExomInlineMessage>(
          find.byType(ExomInlineMessage),
        );
        expect(message.kind, ExomMessageKind.error);
        expect(find.byType(ServerErrorWidget), findsNothing);
        bloc.events.clear();
        await tester.tap(find.text(l10n.retryButton));
        expect(
          bloc.events.whereType<CalendarMonthLoadRequested>(),
          hasLength(1),
        );
      },
    );
  });

  group('M3 arrival', () {
    for (final reduced in [false, true]) {
      testWidgets('first load fades in (reduced: $reduced)', (tester) async {
        final bloc = await pumpCalendarScene(
          tester,
          state: const CalendarLoading(),
          disableAnimations: reduced,
        );
        bloc.seed(sceneLoaded());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        double opacity() => tester
            .widget<FadeTransition>(
              find
                  .descendant(
                    of: find.byType(ExomArrival),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value;
        expect(opacity(), lessThan(1));
        await tester.pump(const Duration(milliseconds: 700));
        expect(opacity(), 1);
      });
    }
  });

  group('CC 3: large text', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final (width, scale) in const [
        (320.0, 1.3),
        (320.0, 1.6),
        (360.0, 1.6),
      ]) {
        for (final training in [true, false]) {
          testWidgets('${locale.languageCode} $width dp ${scale}x '
              '${training ? 'training' : 'diets'}', (tester) async {
            await pumpCalendarScene(
              tester,
              state: sceneLoaded(),
              width: width,
              textScale: scale,
              locale: locale,
            );
            if (!training) await _tapDiets(tester);
            expectNoOverflow(tester);
            expectNoEllipsis(tester);
          });
        }
      }
    }

    testWidgets('2.0x: everything reachable by scrolling', (tester) async {
      await pumpCalendarScene(
        tester,
        state: sceneLoaded(),
        width: 360,
        textScale: 2.0,
      );
      expectNoOverflow(tester);
      await tester.scrollUntilVisible(
        find.byKey(_challengesShortcut),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(_challengesShortcut).hitTestable(), findsOneWidget);
      expectNoOverflow(tester);
    });
  });

  group('CC 4: themes, contrast, tap targets', () {
    for (final brightness in Brightness.values) {
      testWidgets('main scene (${brightness.name})', (tester) async {
        await pumpCalendarScene(
          tester,
          state: sceneLoaded(),
          brightness: brightness,
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectTapTargetGuidelines(tester);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
      });
    }
  });
}

extension on RenderParagraph {
  /// Lines the painted text takes (distinct line tops of its glyph boxes).
  int get lines => getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.toPlainText().length),
  ).map((box) => box.top.round()).toSet().length;
}
