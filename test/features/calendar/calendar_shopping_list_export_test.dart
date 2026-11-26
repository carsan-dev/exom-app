// I7 + I20: the weekly «Lista de la compra» export reached from the Calendar.
// Presentation only: the bloc is the real one, repositories are fakes.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Tristate;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_week_summary_usecase.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:exom_app/features/calendar/presentation/pages/calendar_page.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_challenges_usecase.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_monthly_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_weekly_diet_usecase.dart';
import 'package:exom_app/features/diets/presentation/widgets/weekly_shopping_list_flow.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _initialDate = '2026-11-18';

MealEntity _meal(
  String id,
  String name, {
  List<MealEntity> variants = const [],
  List<MealIngredientEntity> ingredients = const [],
}) => MealEntity(
  id: id,
  type: 'LUNCH',
  name: name,
  nutritionalBadges: const [],
  ingredients: ingredients,
  variants: variants,
);

MealIngredientEntity _ingredient(String id, String name) =>
    MealIngredientEntity(id: id, name: name, quantity: 100, unit: 'g');

WeeklyDietEntity _week(List<MealEntity> meals) => WeeklyDietEntity(
  weekStart: DateTime(2026, 11, 16),
  weekEnd: DateTime(2026, 11, 22),
  days: [
    WeeklyDietDayEntity(
      date: DateTime(2026, 11, 18),
      diet: DietEntity(id: 'd', name: 'D', meals: meals),
    ),
  ],
);

/// Short names: the test font is wide and the dropdown would overflow.
final _withVariants = _week([
  _meal(
    'a',
    'A',
    ingredients: [_ingredient('i-a', 'Arroz')],
    variants: [
      _meal('b', 'B', ingredients: [_ingredient('i-b', 'Pasta')]),
    ],
  ),
]);

final _withoutVariants = _week([
  _meal('a', 'A', ingredients: [_ingredient('i-a', 'Arroz')]),
]);

class _CalendarRepository extends Fake implements CalendarRepository {
  @override
  Future<List<CalendarDayEntity>> getMonthCalendar(int year, int month) async =>
      [
        CalendarDayEntity(
          date: DateTime(2026, 11, 18),
          hasTraining: false,
          hasDiet: true,
          isRestDay: false,
          trainingCompleted: false,
          dietCompleted: false,
        ),
      ];

  @override
  Future<WeekSummaryEntity> getWeekSummary(String weekStart) async =>
      WeekSummaryEntity(
        weekStart: weekStart,
        trainingsAssigned: 0,
        trainingsCompleted: 0,
        totalMeals: 1,
        mealsCompleted: 0,
      );
}

class _ChallengesRepository extends Fake implements ChallengesRepository {
  @override
  Future<List<ChallengeEntity>> getMyChallenges() async => const [];
}

class _DietRepository extends Fake implements DietRepository {
  WeeklyDietEntity week = _withVariants;
  DietPeriodEntity month = _withVariants;
  Completer<WeeklyDietEntity>? weekGate;
  Object? weekError;
  final weeklyReads = <String>[];
  final monthlyReads = <String>[];

  @override
  Future<WeeklyDietEntity> getWeeklyDiet(String weekStart) async {
    weeklyReads.add(weekStart);
    final error = weekError;
    if (error != null) throw error;
    final gate = weekGate;
    return gate == null ? week : gate.future;
  }

  @override
  Future<DietPeriodEntity> getMonthlyDiet(int year, int month) async {
    monthlyReads.add('$year-$month');
    return this.month;
  }
}

class _PdfCall {
  _PdfCall(this.items, this.title, this.empty);
  final List<ShoppingListItem> items;
  final String title;
  final String empty;
}

class _FakePdfService extends Fake implements WeeklyDietPdfService {
  final shoppingLists = <_PdfCall>[];
  Object? error;

  @override
  Future<Uint8List> buildShoppingList({
    required DietPeriodEntity week,
    required List<ShoppingListItem> items,
    required String locale,
    required WeeklyShoppingListPdfLabels labels,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    shoppingLists.add(_PdfCall(items, labels.title, labels.empty));
    return Uint8List(0);
  }
}

class _Harness {
  _Harness(this.repository, this.pdf);
  final _DietRepository repository;
  final _FakePdfService pdf;
}

Future<_Harness> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  await tester.pumpWidget(const SizedBox());
  final calendar = _CalendarRepository();
  final diets = _DietRepository();
  final pdf = _FakePdfService();
  sl.registerFactory<CalendarBloc>(
    () => CalendarBloc(
      getMonthCalendarUseCase: GetMonthCalendarUseCase(calendar),
      getWeekSummaryUseCase: GetWeekSummaryUseCase(calendar),
      getMyChallengesUseCase: GetMyChallengesUseCase(_ChallengesRepository()),
    ),
  );
  sl.registerSingleton<GetWeeklyDietUseCase>(GetWeeklyDietUseCase(diets));
  sl.registerSingleton<GetMonthlyDietUseCase>(GetMonthlyDietUseCase(diets));
  sl.registerSingleton<WeeklyDietPdfService>(pdf);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: CalendarPage(initialDate: _initialDate)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  // Dietas tab, where the export button lives.
  await tester.tap(find.text(_l10n(tester).diets));
  await tester.pump();
  return _Harness(diets, pdf);
}

// The root Navigator (under the app's Localizations): the calendar is
// offstage while a pushed shopping-list screen covers it (L5-E8).
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Navigator).first));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await _settle(tester);
}

/// L5-A4b: the export sheets' two-line headline, read as [label].
Finder _headline(String label) => find.byWidgetPredicate(
  (widget) => widget is ExomTwoLineHeadline && widget.semanticsLabel == label,
);

/// Export button, then the period. The period is read before the format
/// sheet appears, so loading / empty / failure end here. L5-A4b: the period
/// entries are a numbered index, painted upper case.
Future<void> _pickPeriod(WidgetTester tester, {String? period}) async {
  final l10n = _l10n(tester);
  await _tapText(tester, l10n.exportDietButton);
  await _tapText(tester, (period ?? l10n.exportThisWeek).toUpperCase());
}

/// Export button, then period, then «Lista de la compra».
Future<void> _startShoppingList(WidgetTester tester, {String? period}) async {
  await _pickPeriod(tester, period: period);
  await _tapText(tester, _l10n(tester).weeklyExportShoppingList.toUpperCase());
}

/// L5-E8: «Elige tus alternativas» and the list are pushed screens.
final _setup = find.byKey(const Key('shopping-list-setup'));
final _result = find.byKey(const Key('shopping-list-result'));

/// «Generar lista» of the choice screen (painted upper case).
Future<void> _generate(WidgetTester tester) =>
    _tapText(tester, _l10n(tester).weeklyGenerateShoppingList.toUpperCase());

/// «Compartir lista» of the list screen: builds the PDF and offers
/// print / share, as «Generar lista» did before L5-E8.
Future<void> _share(WidgetTester tester) =>
    _tapText(tester, _l10n(tester).shoppingListShare.toUpperCase());

/// The flow that the Dietas shopping-list row starts, for the same date.
Future<void> _runDietsFlow(WidgetTester tester) async {
  // Fresh tree: drops the routes the calendar flow left open.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                startWeeklyShoppingList(context, DateTime(2026, 11, 18)),
            child: const Text('dietas'),
          ),
        ),
      ),
    ),
  );
  await _tapText(tester, 'dietas');
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('export entry point', () {
    testWidgets('only in the Dietas tab', (tester) async {
      await _mount(tester);
      final l10n = _l10n(tester);
      expect(find.text(l10n.exportDietButton), findsOneWidget);
      await tester.tap(find.text(l10n.training));
      await tester.pump();
      expect(find.text(l10n.exportDietButton), findsNothing);
    });

    testWidgets('week and month periods, then menu or shopping list', (
      tester,
    ) async {
      await _mount(tester);
      final l10n = _l10n(tester);
      await _tapText(tester, l10n.exportDietButton);
      // L5-A4b: two-line headline read as the title; entries in upper case.
      expect(_headline(l10n.exportPeriodTitle), findsOneWidget);
      expect(find.text(l10n.exportThisWeek.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.exportFullMonth.toUpperCase()), findsOneWidget);
      await _tapText(tester, l10n.exportThisWeek.toUpperCase());
      expect(_headline(l10n.weeklyExportFormatTitle), findsOneWidget);
      expect(find.text(l10n.exportMenu.toUpperCase()), findsOneWidget);
      expect(
        find.text(l10n.weeklyExportShoppingList.toUpperCase()),
        findsOneWidget,
      );
    });
  });

  group('with alternatives', () {
    testWidgets('week: reads the Monday of the selected day, opens selector', (
      tester,
    ) async {
      final h = await _mount(tester);
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      expect(h.repository.weeklyReads, ['2026-11-16']);
      expect(_setup, findsOneWidget);
      expect(
        find.text(l10n.weeklyGenerateShoppingList.toUpperCase()),
        findsOneWidget,
      );
      expect(h.pdf.shoppingLists, isEmpty);
    });

    // L5-E8: «Generar lista» opens the list; «Compartir lista» builds the
    // PDF once and offers print / share.
    testWidgets('generate opens the list; share builds the PDF once', (
      tester,
    ) async {
      final h = await _mount(tester);
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      await _generate(tester);
      expect(_result, findsOneWidget);
      expect(h.pdf.shoppingLists, isEmpty);
      await _share(tester);
      expect(h.pdf.shoppingLists, hasLength(1));
      final call = h.pdf.shoppingLists.single;
      expect(call.title, l10n.weeklyShoppingListPdfTitle);
      expect(call.items.map((i) => i.name), ['Arroz']);
      expect(find.text(l10n.weeklyDietPrint), findsOneWidget);
      expect(find.text(l10n.weeklyDietShare), findsOneWidget);
    });

    testWidgets('leaving the choice builds nothing and leaves no error', (
      tester,
    ) async {
      final h = await _mount(tester);
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      await tester.tap(find.byIcon(ExomIcons.back));
      await _settle(tester);
      expect(h.pdf.shoppingLists, isEmpty);
      expect(find.text(l10n.weeklyDietExportError), findsNothing);
      expect(find.text(l10n.weeklyDietPrint), findsNothing);
      expect(find.text(l10n.exportDietButton), findsOneWidget);
    });

    testWidgets('month: reads the month and opens the selector', (
      tester,
    ) async {
      final h = await _mount(tester);
      final l10n = _l10n(tester);
      await _startShoppingList(tester, period: l10n.exportFullMonth);
      expect(h.repository.monthlyReads, ['2026-11']);
      expect(h.repository.weeklyReads, isEmpty);
      expect(_setup, findsOneWidget);
    });
  });

  // L5-E8 (D16, L4-I25b): the configuration is a pushed screen, back returns
  // to the Calendar, and the month questions carry weekday and date.
  group('L5-E8: configuration as a screen', () {
    testWidgets('opens a pushed screen; back returns to the Calendar', (
      tester,
    ) async {
      await _mount(tester);
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      final setup = find.byKey(const Key('shopping-list-setup'));
      expect(setup, findsOneWidget);
      expect(ModalRoute.of(tester.element(setup)), isA<PageRoute<dynamic>>());
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(setup, findsNothing);
      expect(find.text(l10n.exportDietButton), findsOneWidget);
    });

    testWidgets('month: two Wednesdays, each with its date', (tester) async {
      final h = await _mount(tester);
      MealEntity lunch(String id) => _meal(
        id,
        'A',
        ingredients: [_ingredient('i-a', 'Arroz')],
        variants: [
          _meal('$id-b', 'B', ingredients: [_ingredient('i-b', 'Pasta')]),
        ],
      );
      h.repository.month = DietPeriodEntity(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 30),
        days: [
          for (final day in [18, 25])
            DietPeriodDayEntity(
              date: DateTime(2026, 11, day),
              diet: DietEntity(id: 'd$day', name: 'D', meals: [lunch('m$day')]),
            ),
        ],
      );
      final l10n = _l10n(tester);
      await _startShoppingList(tester, period: l10n.exportFullMonth);
      expect(find.text('Miércoles 18 · ${l10n.mealTypeLunch}'), findsOneWidget);
      expect(find.text('Miércoles 25 · ${l10n.mealTypeLunch}'), findsOneWidget);
    });
  });

  group('I7: without alternatives the empty sheet is not offered', () {
    testWidgets('week: no choice screen, goes straight to the list', (
      tester,
    ) async {
      final h = await _mount(tester);
      h.repository.week = _withoutVariants;
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      expect(_setup, findsNothing);
      expect(_result, findsOneWidget);
      await _share(tester);
      expect(h.pdf.shoppingLists, hasLength(1));
      expect(find.text(l10n.weeklyDietPrint), findsOneWidget);
    });

    testWidgets('month: no choice screen, goes straight to the list', (
      tester,
    ) async {
      final h = await _mount(tester);
      h.repository.month = _withoutVariants;
      final l10n = _l10n(tester);
      await _startShoppingList(tester, period: l10n.exportFullMonth);
      expect(_setup, findsNothing);
      expect(_result, findsOneWidget);
      await _share(tester);
      expect(h.pdf.shoppingLists, hasLength(1));
      expect(
        h.pdf.shoppingLists.single.title,
        l10n.monthlyShoppingListPdfTitle,
      );
      expect(find.text(l10n.weeklyDietPrint), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('loading: button disabled and «Preparando PDF…» until read', (
      tester,
    ) async {
      final h = await _mount(tester);
      final gate = Completer<WeeklyDietEntity>();
      h.repository.weekGate = gate;
      final l10n = _l10n(tester);
      await _pickPeriod(tester);
      expect(find.text(l10n.weeklyDietPreparing), findsOneWidget);
      expect(find.text(l10n.exportDietButton), findsNothing);
      final handle = tester.ensureSemantics();
      final button = tester.getSemantics(
        find.bySemanticsLabel(l10n.weeklyDietPreparing),
      );
      expect(button.flagsCollection.isButton, isTrue);
      expect(button.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
      gate.complete(_withVariants);
      await _settle(tester);
      expect(_headline(l10n.weeklyExportFormatTitle), findsOneWidget);
    });

    testWidgets('empty period: message, no selector, button restored', (
      tester,
    ) async {
      final h = await _mount(tester);
      h.repository.week = WeeklyDietEntity(
        weekStart: DateTime(2026, 11, 16),
        weekEnd: DateTime(2026, 11, 22),
        days: [WeeklyDietDayEntity(date: DateTime(2026, 11, 18), diet: null)],
      );
      final l10n = _l10n(tester);
      await _pickPeriod(tester);
      expect(find.text(l10n.dietPeriodEmpty), findsOneWidget);
      expect(_setup, findsNothing);
      expect(find.text(l10n.exportDietButton), findsOneWidget);
      expect(find.text(l10n.weeklyDietPreparing), findsNothing);
    });

    testWidgets('read failure: export error, button restored', (tester) async {
      final h = await _mount(tester);
      h.repository.weekError = StateError('offline');
      final l10n = _l10n(tester);
      await _pickPeriod(tester);
      expect(find.text(l10n.weeklyDietExportError), findsOneWidget);
      expect(_setup, findsNothing);
      expect(find.text(l10n.exportDietButton), findsOneWidget);
    });

    // L5-E8: the PDF is built on the list screen; its failure is shown there
    // in line (the list stays, «Compartir lista» can be retried) and the
    // calendar's button is restored once the screens close.
    testWidgets('PDF failure: error on the list, button restored', (
      tester,
    ) async {
      final h = await _mount(tester);
      h.pdf.error = StateError('pdf');
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      await _generate(tester);
      await _share(tester);
      expect(_result, findsOneWidget);
      expect(find.text(l10n.weeklyDietExportError), findsOneWidget);
      expect(find.text(l10n.weeklyDietPrint), findsNothing);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text(l10n.exportDietButton), findsOneWidget);
      expect(find.text(l10n.weeklyDietPreparing), findsNothing);
    });
  });

  group('same result as from Dietas', () {
    testWidgets('same selector and same PDF input as the Dietas flow', (
      tester,
    ) async {
      final h = await _mount(tester);

      await _startShoppingList(tester);
      expect(_setup, findsOneWidget);
      await _generate(tester);
      await _share(tester);
      final fromCalendar = h.pdf.shoppingLists.single;

      await _runDietsFlow(tester);
      expect(_setup, findsOneWidget);
      await _generate(tester);
      await _share(tester);
      final fromDiets = h.pdf.shoppingLists.last;

      expect(h.pdf.shoppingLists, hasLength(2));
      expect(h.repository.weeklyReads, ['2026-11-16', '2026-11-16']);
      expect(fromDiets.title, fromCalendar.title);
      expect(fromDiets.empty, fromCalendar.empty);
      expect(
        fromDiets.items.map((i) => (i.ingredientKey, i.name, i.quantity)),
        fromCalendar.items.map((i) => (i.ingredientKey, i.name, i.quantity)),
      );
    });

    testWidgets('no alternatives: same outcome as the Dietas flow', (
      tester,
    ) async {
      final h = await _mount(tester);
      h.repository.week = _withoutVariants;

      await _startShoppingList(tester);
      expect(_setup, findsNothing);
      await _share(tester);
      final fromCalendar = h.pdf.shoppingLists.single;

      await _runDietsFlow(tester);
      expect(_setup, findsNothing);
      await _share(tester);
      expect(h.pdf.shoppingLists, hasLength(2));
      expect(
        h.pdf.shoppingLists.last.items.map((i) => i.name),
        fromCalendar.items.map((i) => i.name),
      );
    });
  });
}
