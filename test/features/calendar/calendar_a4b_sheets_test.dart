// L5-A4b «Calendario» (docs/plans/rediseno-app-l5-contrato-v2.md, L5-A4):
// D14-2, the month and year picker and the export period become straight
// sheets (`showExomSheet`); a month is chosen with one tap, without «Ir al
// mes». D14-3, the export messages that were `SnackBar`s are inline
// (`ExomInlineMessage`) under the export button and clear on the next export
// tap, on a tab change or on a month change. CC 11 (R22): both sheets close
// without acting when the router location changes.
// The calendar bloc is seeded (month changes are only recorded as events);
// the diet use cases and the PDF service are fakes.
import 'dart:typed_data';

import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:exom_app/features/calendar/presentation/pages/calendar_page.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_monthly_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_weekly_diet_usecase.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/widgets/android_nonlinear_text_scaler.dart';
import 'calendar_redesign_fixture.dart';

const _title = Key('calendar-month-title');
const _panel = Key('exom-sheet-panel');

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(CalendarPage)));

WeeklyDietEntity _week({required bool withDiet}) => WeeklyDietEntity(
  weekStart: DateTime(2026, 10, 12),
  weekEnd: DateTime(2026, 10, 18),
  days: [
    WeeklyDietDayEntity(
      date: DateTime(2026, 10, 15),
      diet: withDiet
          ? const DietEntity(
              id: 'd',
              name: 'D',
              meals: [
                MealEntity(
                  id: 'a',
                  type: 'LUNCH',
                  name: 'A',
                  nutritionalBadges: [],
                  ingredients: [],
                  variants: [],
                ),
              ],
            )
          : null,
    ),
  ],
);

class _DietRepository extends Fake implements DietRepository {
  WeeklyDietEntity week = _week(withDiet: true);
  Object? weekError;
  final weeklyReads = <String>[];
  final monthlyReads = <String>[];

  @override
  Future<WeeklyDietEntity> getWeeklyDiet(String weekStart) async {
    weeklyReads.add(weekStart);
    final error = weekError;
    if (error != null) throw error;
    return week;
  }

  @override
  Future<DietPeriodEntity> getMonthlyDiet(int year, int month) async {
    monthlyReads.add('$year-$month');
    return week;
  }
}

class _FailingPdfService extends Fake implements WeeklyDietPdfService {
  int builds = 0;

  @override
  Future<Uint8List> build({
    required DietPeriodEntity week,
    required String locale,
    required WeeklyDietPdfLabels labels,
  }) async {
    builds++;
    throw StateError('pdf');
  }
}

/// Mounts the seeded October 2026 scene and registers the diet fakes.
Future<(SeededCalendarBloc, _DietRepository)> _mount(
  WidgetTester tester,
) async {
  final bloc = await pumpCalendarScene(tester, state: sceneLoaded());
  final diets = _DietRepository();
  sl.registerSingleton<GetWeeklyDietUseCase>(GetWeeklyDietUseCase(diets));
  sl.registerSingleton<GetMonthlyDietUseCase>(GetMonthlyDietUseCase(diets));
  sl.registerSingleton<WeeklyDietPdfService>(_FailingPdfService());
  // The page asks for its month when it is created.
  bloc.events.clear();
  return (bloc, diets);
}

Future<void> _tapDiets(WidgetTester tester) async {
  await tester.tap(find.text(_l10n(tester).diets));
  await tester.pumpAndSettle();
}

Future<void> _tapExport(WidgetTester tester) async {
  final button = find.byType(OutlinedButton);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// The index entry of the open sheet whose title is [label].
Finder _periodEntry(String label) => find.descendant(
  of: find.byType(ExomIndexList),
  matching: find.text(label.toUpperCase()),
);

/// Fixed pumps: while the format sheet is open the export button shows its
/// spinner, which never settles.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pickWeek(WidgetTester tester) async {
  await _tapExport(tester);
  await tester.tap(_periodEntry(_l10n(tester).exportThisWeek));
  await _settle(tester);
}

Finder _message(ExomMessageKind kind, String title) => find.byWidgetPredicate(
  (widget) =>
      widget is ExomInlineMessage &&
      widget.kind == kind &&
      widget.title == title,
);

List<CalendarMonthLoadRequested> _monthLoads(SeededCalendarBloc bloc) =>
    bloc.events.whereType<CalendarMonthLoadRequested>().toList();

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  group('D14-2 month and year sheet', () {
    testWidgets(
      'opens as a straight sheet, not a dialog, without «Ir al mes»',
      (tester) async {
        await _mount(tester);
        final l10n = _l10n(tester);
        await tester.tap(find.byKey(_title));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(find.byKey(_panel), findsOneWidget);
        expect(find.text(l10n.goToMonthButton), findsNothing);
        final kicker = find.descendant(
          of: find.byKey(_panel),
          matching: find.byType(ExomKicker),
        );
        expect(
          tester.widget<ExomKicker>(kicker).text,
          l10n.calendarMonthPickerKicker,
        );
        expect(find.text('2026'), findsOneWidget);
      },
    );

    testWidgets('the shown month is the filled choice; twelve months', (
      tester,
    ) async {
      await _mount(tester);
      await tester.tap(find.byKey(_title));
      await tester.pumpAndSettle();
      final chips = tester.widget<ExomChoiceChips<int>>(
        find.byType(ExomChoiceChips<int>),
      );
      expect(chips.options, [for (var m = 1; m <= 12; m++) m]);
      expect(chips.selected, kSceneMonth);
    });

    testWidgets('one tap on a month loads it and closes the sheet', (
      tester,
    ) async {
      final (bloc, _) = await _mount(tester);
      await tester.tap(find.byKey(_title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();
      expect(find.byKey(_panel), findsNothing);
      final loads = _monthLoads(bloc);
      expect(loads, hasLength(1));
      expect((loads.single.year, loads.single.month), (2026, 3));
    });

    testWidgets('the year arrows change the year without navigating', (
      tester,
    ) async {
      final (bloc, _) = await _mount(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(_title));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.calendarNextYear));
      await tester.pumpAndSettle();
      expect(find.text('2027'), findsOneWidget);
      expect(find.byKey(_panel), findsOneWidget);
      expect(_monthLoads(bloc), isEmpty);
      // Another year: the shown month is not marked.
      expect(
        tester
            .widget<ExomChoiceChips<int>>(find.byType(ExomChoiceChips<int>))
            .selected,
        isNull,
      );

      await tester.tap(find.byTooltip(l10n.calendarPreviousYear));
      await tester.tap(find.byTooltip(l10n.calendarPreviousYear));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);
      expect(_monthLoads(bloc), isEmpty);

      await tester.tap(find.text('Ene'));
      await tester.pumpAndSettle();
      final loads = _monthLoads(bloc);
      expect(loads, hasLength(1));
      expect((loads.single.year, loads.single.month), (2025, 1));
      expect(find.byKey(_panel), findsNothing);
    });

    testWidgets('a router location change closes it without loading (R22)', (
      tester,
    ) async {
      final (bloc, _) = await _mount(tester);
      await tester.tap(find.byKey(_title));
      await tester.pumpAndSettle();
      expect(find.byKey(_panel), findsOneWidget);
      GoRouter.of(tester.element(find.byType(CalendarPage))).go('/challenges');
      await tester.pumpAndSettle();
      expect(find.byKey(_panel), findsNothing);
      expect(_monthLoads(bloc), isEmpty);
    });
  });

  // L5-A4 D2 (emulator, 320 dp 1.6x): intl abbreviates September «sept», which
  // broke into «Sep / t». The sketch labels the months with three letters.
  group('D2 month labels: three letters, never broken', () {
    const labels = {
      'es': [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', //
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
      ],
      'en': [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ],
    };
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
              await tester.tap(find.byKey(_title));
              await tester.pumpAndSettle();
              final chips = find.byType(ExomChoiceChips<int>);
              final widget = tester.widget<ExomChoiceChips<int>>(chips);
              expect([
                for (var m = 1; m <= 12; m++) widget.labelOf(m),
              ], labels[locale.languageCode]);
              final paragraphs = find
                  .descendant(of: chips, matching: find.byType(RichText))
                  .evaluate()
                  .map((e) => e.renderObject! as RenderParagraph);
              expect(paragraphs, hasLength(12));
              for (final paragraph in paragraphs) {
                expect(
                  paragraph.getMinIntrinsicWidth(double.infinity),
                  lessThanOrEqualTo(paragraph.size.width + 0.01),
                  reason: 'broken: "${paragraph.text.toPlainText()}"',
                );
              }
            });
          }
        }
      }
    }
  });

  group('D14-2 export period sheet', () {
    testWidgets('a straight sheet with the numbered week and month entries', (
      tester,
    ) async {
      await _mount(tester);
      final l10n = _l10n(tester);
      await _tapDiets(tester);
      await _tapExport(tester);
      expect(find.byKey(_panel), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.descendant(
          of: find.byKey(_panel),
          matching: find.byType(ExomTwoLineHeadline),
        ),
      );
      expect(headline.first, l10n.calendarExportPeriodFirst);
      expect(headline.second, l10n.calendarExportPeriodSecond);
      expect(headline.semanticsLabel, l10n.exportPeriodTitle);
      final index = tester.widget<ExomIndexList>(find.byType(ExomIndexList));
      expect(index.items.map((item) => item.title), [
        l10n.exportThisWeek,
        l10n.exportFullMonth,
      ]);
    });

    testWidgets('week and month keep their reads', (tester) async {
      final (_, diets) = await _mount(tester);
      final l10n = _l10n(tester);
      await _tapDiets(tester);
      await _pickWeek(tester);
      expect(diets.weeklyReads, ['2026-10-12']);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ExomTwoLineHeadline &&
              widget.semanticsLabel == l10n.weeklyExportFormatTitle,
        ),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);

      await _tapExport(tester);
      await tester.tap(_periodEntry(l10n.exportFullMonth));
      await _settle(tester);
      expect(diets.monthlyReads, ['2026-10']);
    });

    testWidgets('a router location change closes it without reading (R22)', (
      tester,
    ) async {
      final (_, diets) = await _mount(tester);
      await _tapDiets(tester);
      await _tapExport(tester);
      expect(find.byKey(_panel), findsOneWidget);
      GoRouter.of(tester.element(find.byType(CalendarPage))).go('/challenges');
      await tester.pumpAndSettle();
      expect(find.byKey(_panel), findsNothing);
      expect(diets.weeklyReads, isEmpty);
      expect(diets.monthlyReads, isEmpty);
    });
  });

  group('D14-2 export format sheet', () {
    testWidgets('a straight sheet with the numbered menu and shopping list', (
      tester,
    ) async {
      await _mount(tester);
      final l10n = _l10n(tester);
      await _tapDiets(tester);
      await _pickWeek(tester);
      expect(find.byKey(_panel), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.descendant(
          of: find.byKey(_panel),
          matching: find.byType(ExomTwoLineHeadline),
        ),
      );
      expect(headline.first, l10n.calendarExportFormatFirst);
      expect(headline.second, l10n.calendarExportFormatSecond);
      expect(headline.semanticsLabel, l10n.weeklyExportFormatTitle);
      final kicker = find.descendant(
        of: find.byKey(_panel),
        matching: find.byType(ExomKicker),
      );
      expect(
        tester.widget<ExomKicker>(kicker).text,
        l10n.calendarExportPeriodKicker,
      );
      final index = tester.widget<ExomIndexList>(
        find.descendant(
          of: find.byKey(_panel),
          matching: find.byType(ExomIndexList),
        ),
      );
      expect(index.items.map((item) => item.title), [
        l10n.exportMenu,
        l10n.weeklyExportShoppingList,
      ]);
    });

    testWidgets('a router location change closes it without building (R22)', (
      tester,
    ) async {
      await _mount(tester);
      await _tapDiets(tester);
      await _pickWeek(tester);
      expect(find.byKey(_panel), findsOneWidget);
      GoRouter.of(tester.element(find.byType(CalendarPage))).go('/challenges');
      await _settle(tester);
      await _settle(tester);
      expect(find.byKey(_panel), findsNothing);
      expect(
        sl<WeeklyDietPdfService>(),
        isA<_FailingPdfService>().having((pdf) => pdf.builds, 'builds', 0),
      );
    });
  });

  group('D14-3 inline export messages', () {
    testWidgets('read failure: inline error under the button, no SnackBar', (
      tester,
    ) async {
      final (_, diets) = await _mount(tester);
      diets.weekError = StateError('offline');
      final l10n = _l10n(tester);
      await _tapDiets(tester);
      await _pickWeek(tester);
      final message = _message(
        ExomMessageKind.error,
        l10n.weeklyDietExportError,
      );
      expect(message, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.getTopLeft(message).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byType(OutlinedButton)).dy,
        ),
      );
    });

    testWidgets('PDF failure: inline error, no SnackBar', (tester) async {
      await _mount(tester);
      final l10n = _l10n(tester);
      await _tapDiets(tester);
      await _pickWeek(tester);
      await tester.tap(_periodEntry(l10n.exportMenu));
      await _settle(tester);
      expect(
        _message(ExomMessageKind.error, l10n.weeklyDietExportError),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('empty period: inline info under the button, no SnackBar', (
      tester,
    ) async {
      final (_, diets) = await _mount(tester);
      diets.week = _week(withDiet: false);
      final l10n = _l10n(tester);
      await _tapDiets(tester);
      await _pickWeek(tester);
      final message = _message(ExomMessageKind.info, l10n.dietPeriodEmpty);
      expect(message, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.getTopLeft(message).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byType(OutlinedButton)).dy,
        ),
      );
    });

    testWidgets('cleared by the next export tap', (tester) async {
      final (_, diets) = await _mount(tester);
      diets.weekError = StateError('offline');
      await _tapDiets(tester);
      await _pickWeek(tester);
      expect(find.byType(ExomInlineMessage), findsOneWidget);
      await _tapExport(tester);
      expect(find.byType(ExomInlineMessage), findsNothing);
    });

    testWidgets('cleared by a tab change', (tester) async {
      final (_, diets) = await _mount(tester);
      diets.weekError = StateError('offline');
      final l10n = _l10n(tester);
      await _tapDiets(tester);
      await _pickWeek(tester);
      expect(find.byType(ExomInlineMessage), findsOneWidget);
      await tester.tap(find.text(l10n.training));
      await tester.pumpAndSettle();
      await _tapDiets(tester);
      expect(find.byType(ExomInlineMessage), findsNothing);
    });

    testWidgets('cleared by a month change, also when coming back', (
      tester,
    ) async {
      final (bloc, diets) = await _mount(tester);
      diets.weekError = StateError('offline');
      await _tapDiets(tester);
      await _pickWeek(tester);
      expect(find.byType(ExomInlineMessage), findsOneWidget);
      bloc.seed(const CalendarLoading());
      await tester.pumpAndSettle();
      bloc.seed(sceneLoaded(month: 11, selected: DateTime(2026, 11, 2)));
      await tester.pumpAndSettle();
      expect(find.byType(ExomInlineMessage), findsNothing);
      bloc.seed(sceneLoaded());
      await tester.pumpAndSettle();
      expect(find.byType(ExomInlineMessage), findsNothing);
    });
  });
}
