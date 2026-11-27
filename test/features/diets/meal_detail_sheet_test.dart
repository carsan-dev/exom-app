// Macro chips of the meal detail use the decimal separator of the locale.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_completed_meals_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_today_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/mark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/unmark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../golden/redesign_scenes.dart' show loadRedesignFonts;

const _date = '2026-11-18';

final _meal = MealEntity(
  id: 'm-1',
  type: 'LUNCH',
  name: 'Arroz con pollo',
  calories: 520,
  proteinG: 26.9,
  carbsG: 60.25,
  fatG: 12,
  nutritionalBadges: const [],
  ingredients: const [],
  variants: const [],
);

final _variant = MealEntity(
  id: 'm-1b',
  type: 'LUNCH',
  name: 'Pasta, atún y tomate',
  calories: 640,
  proteinG: 30,
  carbsG: 80,
  fatG: 15,
  nutritionalBadges: const [],
  ingredients: const [],
  variants: const [],
);

final _withOptions = MealEntity(
  id: 'm-1',
  type: 'LUNCH',
  name: 'Arroz con pollo',
  calories: 520,
  proteinG: 26.9,
  carbsG: 60.25,
  fatG: 12,
  nutritionalBadges: const ['Proteína', 'Fibra'],
  ingredients: const [
    MealIngredientEntity(
      id: 'i-1',
      name: 'Arroz basmati',
      quantity: 80,
      unit: 'g',
    ),
  ],
  variants: [_variant],
);

class _Repository extends Fake implements DietRepository {
  _Repository(this.meal);

  final MealEntity meal;
  final marked = <String>[];

  @override
  Future<DietEntity?> getTodayDiet({String? date}) async =>
      DietEntity(id: 'd', name: 'D', meals: [meal]);

  @override
  Future<Set<String>> getCompletedMealIds({String? date}) async => {};

  @override
  Future<void> markMealCompleted(String mealId, String date) async {
    marked.add('$mealId@$date');
  }
}

Future<_Repository> _mount(
  WidgetTester tester,
  Locale locale, {
  MealEntity? meal,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final repository = _Repository(meal ?? _meal);
  sl.registerFactory<DietBloc>(
    () => DietBloc(
      getTodayDietUseCase: GetTodayDietUseCase(repository),
      getMealUseCase: GetMealUseCase(repository),
      markMealCompletedUseCase: MarkMealCompletedUseCase(repository),
      unmarkMealCompletedUseCase: UnmarkMealCompletedUseCase(repository),
      getCompletedMealsUseCase: GetCompletedMealsUseCase(repository),
    ),
  );
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MealDetailSheet(
          mealId: 'm-1',
          selectedDate: _date,
          scrollController: scroll,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return repository;
}

void main() {
  tearDown(sl.reset);

  testWidgets('Spanish macros use the decimal comma', (tester) async {
    await _mount(tester, const Locale('es'));
    final columns = tester.widget<ExomFigureColumns>(
      find.byType(ExomFigureColumns),
    );
    expect(
      columns.items.map((i) => '${i.label} ${i.value}${i.unit}').toList(),
      ['Proteína 26,9g', 'Carbos 60,25g', 'Grasas 12g'],
    );
    expect(find.textContaining('26.9'), findsNothing);
  });

  testWidgets('English macros keep the decimal point', (tester) async {
    await _mount(tester, const Locale('en'));
    final columns = tester.widget<ExomFigureColumns>(
      find.byType(ExomFigureColumns),
    );
    expect(columns.items.map((i) => i.value).toList(), ['26.9', '60.25', '12']);
  });

  group('E7 · Detalle de comida (L5)', () {
    testWidgets('calories are the hero figure, macros sit in columns', (
      tester,
    ) async {
      await _mount(tester, const Locale('es'), meal: _withOptions);
      final numeral = tester.widget<ExomNumeral>(find.byType(ExomNumeral));
      expect(numeral.value, '520');
      expect(numeral.unit, 'kcal');
      expect(numeral.size, ExomNumeralSize.hero96);
      expect(find.text('2 opciones'), findsOneWidget);
      expect(find.byType(ExomFigureColumns), findsOneWidget);
      // The pills of the old sheet are gone.
      expect(find.text('P 26,9 g'), findsNothing);
    });

    testWidgets('options are choice chips, not a dropdown', (tester) async {
      await _mount(tester, const Locale('es'), meal: _withOptions);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      final chips = tester.widget<ExomChoiceChips<String>>(
        find.byType(ExomChoiceChips<String>),
      );
      expect(chips.options, ['m-1', 'm-1b']);
      expect(chips.selected, 'm-1');
      expect(chips.options.map(chips.labelOf).toList(), [
        'Principal',
        'Pasta, atún y tomate',
      ]);
    });

    testWidgets('choosing an option shows it and completes that option', (
      tester,
    ) async {
      final repository = await _mount(
        tester,
        const Locale('es'),
        meal: _withOptions,
      );
      await tester.tap(find.text('Pasta, atún y tomate').last);
      await tester.pump();
      expect(
        tester
            .widget<ExomChoiceChips<String>>(
              find.byType(ExomChoiceChips<String>),
            )
            .selected,
        'm-1b',
      );
      expect(tester.widget<ExomNumeral>(find.byType(ExomNumeral)).value, '640');
      await tester.tap(find.widgetWithText(ExomPrimaryButton, 'COMPLETAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.marked, ['m-1b@$_date']);
    });

    testWidgets('no options: no selector; «Rico en» reads as one line', (
      tester,
    ) async {
      await _mount(tester, const Locale('es'), meal: _meal);
      expect(find.byType(ExomChoiceChips<String>), findsNothing);
      expect(find.text('Rico en'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _mount(tester, const Locale('es'), meal: _withOptions);
      expect(find.text('Proteína · Fibra'), findsOneWidget);
    });

    testWidgets('ingredients are numbered rows with their amount', (
      tester,
    ) async {
      await _mount(tester, const Locale('es'), meal: _withOptions);
      expect(find.text('INGREDIENTES'), findsOneWidget);
      expect(find.text('Arroz basmati'), findsOneWidget);
      expect(find.text('80 g'), findsOneWidget);
    });

    testWidgets('actions: Completar (primary) and Receta (quiet)', (
      tester,
    ) async {
      await _mount(tester, const Locale('es'), meal: _withOptions);
      expect(
        find.widgetWithText(ExomPrimaryButton, 'COMPLETAR'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ExomQuietButton, 'Receta'), findsOneWidget);
    });
  });

  // L5-D63 (OBS-4): with large text the sheet opens tall enough to show the
  // name, calories and macros above its pinned foot; at 1,0 it opens at 70 %.
  group('L5-D63 initial height', () {
    Future<void> open(WidgetTester tester, TextScaler scaler) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await sl.reset();
      final repository = _Repository(_withOptions);
      sl.registerFactory<DietBloc>(
        () => DietBloc(
          getTodayDietUseCase: GetTodayDietUseCase(repository),
          getMealUseCase: GetMealUseCase(repository),
          markMealCompletedUseCase: MarkMealCompletedUseCase(repository),
          unmarkMealCompletedUseCase: UnmarkMealCompletedUseCase(repository),
          getCompletedMealsUseCase: GetCompletedMealsUseCase(repository),
        ),
      );
      // The sheet is page-aware: it needs the app router.
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showMealDetailSheet(
                    context,
                    mealId: 'm-1',
                    selectedDate: _date,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.dark,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final foot = find.byKey(const Key('meal-detail-foot'));
    final draggable = find.byType(DraggableScrollableSheet);

    for (final (label, scaler) in [
      ('1.3', const AndroidNonlinearTextScaler(1.3)),
      ('1.6', const AndroidNonlinearTextScaler(1.6)),
    ]) {
      testWidgets('$label: the macros show above the foot, or it opens at '
          'its maximum', (tester) async {
        await open(tester, scaler);
        final initial = tester.widget<DraggableScrollableSheet>(draggable)
            .initialChildSize;
        expect(initial, greaterThan(0.7));
        final macros = find.byType(ExomFigureColumns);
        final shown = macros.evaluate().isNotEmpty &&
            tester.getBottomLeft(macros).dy <= tester.getTopLeft(foot).dy;
        expect(shown || initial == 0.95, isTrue);
        expect(tester.takeException(), isNull);

        // Still draggable from the list.
        final top = tester.getTopLeft(draggable).dy;
        await tester.drag(
          find.descendant(of: draggable, matching: find.byType(Scrollable))
              .first,
          const Offset(0, 80),
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(draggable).dy, greaterThan(top + 20));
      });
    }

    testWidgets('1.6 with the app fonts: the macros show above the foot', (
      tester,
    ) async {
      // The test font is wider and taller than the app's; with the bundled
      // fonts the block fits under the sheet maximum on a 390x844 phone.
      await loadRedesignFonts();
      await open(tester, const AndroidNonlinearTextScaler(1.6));
      final macros = find.byType(ExomFigureColumns);
      expect(macros, findsOneWidget);
      expect(
        tester.getBottomLeft(macros).dy,
        lessThanOrEqualTo(tester.getTopLeft(foot).dy),
      );
    });

    testWidgets('1.0: opens at 70 % as before', (tester) async {
      await open(tester, TextScaler.noScaling);
      expect(
        tester.widget<DraggableScrollableSheet>(draggable).initialChildSize,
        0.7,
      );
      expect(tester.getTopLeft(draggable).dy, moreOrLessEquals(844 * 0.3));
    });
  });
}
