// I7 + I20: the weekly «Lista de la compra» export reached from the Calendar.
// Presentation only: the bloc is the real one, repositories are fakes.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Tristate;

import 'package:exom_app/core/theme/app_theme.dart';
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

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(CalendarPage)));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await _settle(tester);
}

/// Export button, then the period. The period is read before the format
/// sheet appears, so loading / empty / failure end here.
Future<void> _pickPeriod(WidgetTester tester, {String? period}) async {
  final l10n = _l10n(tester);
  await _tapText(tester, l10n.exportDietButton);
  await _tapText(tester, period ?? l10n.exportThisWeek);
}

/// Export button, then period, then «Lista de la compra».
Future<void> _startShoppingList(WidgetTester tester, {String? period}) async {
  await _pickPeriod(tester, period: period);
  await _tapText(tester, _l10n(tester).weeklyExportShoppingList);
}

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
      expect(find.text(l10n.exportPeriodTitle), findsOneWidget);
      expect(find.text(l10n.exportThisWeek), findsOneWidget);
      expect(find.text(l10n.exportFullMonth), findsOneWidget);
      await _tapText(tester, l10n.exportThisWeek);
      expect(find.text(l10n.weeklyExportFormatTitle), findsOneWidget);
      expect(find.text(l10n.exportMenu), findsOneWidget);
      expect(find.text(l10n.weeklyExportShoppingList), findsOneWidget);
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
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsOneWidget);
      expect(find.text(l10n.weeklyGenerateShoppingList), findsOneWidget);
      expect(h.pdf.shoppingLists, isEmpty);
    });

    testWidgets('generate builds the PDF once and offers print / share', (
      tester,
    ) async {
      final h = await _mount(tester);
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      await _tapText(tester, l10n.weeklyGenerateShoppingList);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsNothing);
      expect(h.pdf.shoppingLists, hasLength(1));
      final call = h.pdf.shoppingLists.single;
      expect(call.title, l10n.weeklyShoppingListPdfTitle);
      expect(call.items.map((i) => i.name), ['Arroz']);
      expect(find.text(l10n.weeklyDietPrint), findsOneWidget);
      expect(find.text(l10n.weeklyDietShare), findsOneWidget);
    });

    testWidgets('closing the selector builds nothing and leaves no error', (
      tester,
    ) async {
      final h = await _mount(tester);
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      await tester.tap(find.byIcon(Icons.close));
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
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsOneWidget);
    });
  });

  group('I7: without alternatives the empty sheet is not offered', () {
    testWidgets('week: no selector, goes straight to generation', (
      tester,
    ) async {
      final h = await _mount(tester);
      h.repository.week = _withoutVariants;
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsNothing);
      expect(find.text(l10n.weeklyGenerateShoppingList), findsNothing);
      expect(h.pdf.shoppingLists, hasLength(1));
      expect(find.text(l10n.weeklyDietPrint), findsOneWidget);
    });

    testWidgets('month: no selector, goes straight to generation', (
      tester,
    ) async {
      final h = await _mount(tester);
      h.repository.month = _withoutVariants;
      final l10n = _l10n(tester);
      await _startShoppingList(tester, period: l10n.exportFullMonth);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsNothing);
      expect(find.text(l10n.weeklyGenerateShoppingList), findsNothing);
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
      expect(find.text(l10n.weeklyExportFormatTitle), findsOneWidget);
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
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsNothing);
      expect(find.text(l10n.exportDietButton), findsOneWidget);
      expect(find.text(l10n.weeklyDietPreparing), findsNothing);
    });

    testWidgets('read failure: export error, button restored', (tester) async {
      final h = await _mount(tester);
      h.repository.weekError = StateError('offline');
      final l10n = _l10n(tester);
      await _pickPeriod(tester);
      expect(find.text(l10n.weeklyDietExportError), findsOneWidget);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsNothing);
      expect(find.text(l10n.exportDietButton), findsOneWidget);
    });

    testWidgets('PDF failure: export error, button restored', (tester) async {
      final h = await _mount(tester);
      h.pdf.error = StateError('pdf');
      final l10n = _l10n(tester);
      await _startShoppingList(tester);
      await _tapText(tester, l10n.weeklyGenerateShoppingList);
      expect(find.text(l10n.weeklyDietExportError), findsOneWidget);
      expect(find.text(l10n.weeklyDietPrint), findsNothing);
      expect(find.text(l10n.exportDietButton), findsOneWidget);
    });
  });

  group('same result as from Dietas', () {
    testWidgets('same selector and same PDF input as the Dietas flow', (
      tester,
    ) async {
      final h = await _mount(tester);
      final l10n = _l10n(tester);

      await _startShoppingList(tester);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsOneWidget);
      await _tapText(tester, l10n.weeklyGenerateShoppingList);
      final fromCalendar = h.pdf.shoppingLists.single;

      await _runDietsFlow(tester);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsOneWidget);
      await _tapText(tester, l10n.weeklyGenerateShoppingList);
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
      final l10n = _l10n(tester);

      await _startShoppingList(tester);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsNothing);
      final fromCalendar = h.pdf.shoppingLists.single;

      await _runDietsFlow(tester);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsNothing);
      expect(h.pdf.shoppingLists, hasLength(2));
      expect(
        h.pdf.shoppingLists.last.items.map((i) => i.name),
        fromCalendar.items.map((i) => i.name),
      );
    });
  });
}
