// Macro chips of the meal detail use the decimal separator of the locale.
import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
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

/// Its alternative has a much longer name, so its header is taller.
final _withLongOption = MealEntity(
  id: 'm-1',
  type: 'LUNCH',
  name: 'Arroz con pollo',
  calories: 520,
  proteinG: 26.9,
  carbsG: 60.25,
  fatG: 12,
  nutritionalBadges: const [],
  ingredients: const [],
  variants: [
    MealEntity(
      id: 'm-1b',
      type: 'LUNCH',
      name: 'Pasta integral con atún, tomate seco y albahaca',
      calories: 640,
      proteinG: 30,
      carbsG: 80,
      fatG: 15,
      nutritionalBadges: const [],
      ingredients: const [],
      variants: const [],
    ),
  ],
);

/// A name of several lines at large text, which a skeleton without the
/// caller's meal cannot foresee.
final _longNamed = MealEntity(
  id: 'm-1',
  type: 'LUNCH',
  name: 'Pasta integral con atún, tomate seco y albahaca',
  calories: 640,
  proteinG: 30,
  carbsG: 80,
  fatG: 15,
  nutritionalBadges: const [],
  ingredients: const [],
  variants: const [],
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

/// Holds the meal load until [gate] completes, so the sheet stays on its
/// loading skeleton as long as a test needs.
class _GatedRepository extends _Repository {
  _GatedRepository(super.meal);

  final gate = Completer<void>();

  @override
  Future<DietEntity?> getTodayDiet({String? date}) async {
    await gate.future;
    return super.getTodayDiet(date: date);
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

  // OBS-1 (EMU-REVISION-1127): at 1,6 the sheet opened on its skeleton and
  // jumped when the meal arrived. It must open at its final size, or at most
  // grow animated to reveal the header, and never resize on an option pick.
  group('OBS-1 the sheet opens without a jump', () {
    const height = 844.0;

    Future<_GatedRepository> open(
      WidgetTester tester,
      TextScaler scaler, {
      required MealEntity meal,
      bool disableAnimations = false,
      Future<void> Function(BuildContext context)? show,
    }) async {
      await loadRedesignFonts();
      tester.view.physicalSize = const Size(390, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await sl.reset();
      final repository = _GatedRepository(meal);
      sl.registerFactory<DietBloc>(
        () => DietBloc(
          getTodayDietUseCase: GetTodayDietUseCase(repository),
          getMealUseCase: GetMealUseCase(repository),
          markMealCompletedUseCase: MarkMealCompletedUseCase(repository),
          unmarkMealCompletedUseCase: UnmarkMealCompletedUseCase(repository),
          getCompletedMealsUseCase: GetCompletedMealsUseCase(repository),
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => show != null
                      ? show(context)
                      : showMealDetailSheet(
                          context,
                          mealId: meal.id,
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
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: scaler,
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      return repository;
    }

    final draggable = find.byType(DraggableScrollableSheet);
    // Only the loaded sheet has the keyed foot; the skeleton's is a mask.
    final loadedFoot = find.byKey(const Key('meal-detail-foot'));

    /// Sheet height of every frame in which the sheet is on screen.
    Future<List<double>> record(WidgetTester tester, int frames) async {
      final heights = <double>[];
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (draggable.evaluate().isEmpty) continue;
        if (tester.getTopLeft(draggable).dy >= height - 0.5) continue;
        heights.add(tester.getSize(draggable).height);
      }
      return heights;
    }

    /// Loads after the entrance, then records until everything settles.
    Future<(List<double>, List<double>, double)> openAndLoad(
      WidgetTester tester,
      TextScaler scaler, {
      required MealEntity meal,
      bool disableAnimations = false,
      Future<void> Function(BuildContext context)? show,
    }) async {
      final repository = await open(
        tester,
        scaler,
        meal: meal,
        disableAnimations: disableAnimations,
        show: show,
      );
      final loading = await record(tester, 40);
      expect(loadedFoot, findsNothing, reason: 'still loading');
      repository.gate.complete();
      final loaded = await record(tester, 40);
      await tester.pumpAndSettle();
      expect(loadedFoot, findsOneWidget);
      return (loading, loaded, tester.getSize(draggable).height);
    }

    /// Never shrinks, and grows over several frames (animated), not at once.
    void expectNoJump(List<double> heights, double end) {
      expect(heights, isNotEmpty);
      for (var i = 1; i < heights.length; i++) {
        expect(
          heights[i],
          greaterThanOrEqualTo(heights[i - 1] - 0.01),
          reason: 'frame $i shrinks: $heights',
        );
      }
      final total = end - heights.first;
      if (total <= 1) return;
      final steps = <double>[
        for (var i = 1; i < heights.length; i++) heights[i] - heights[i - 1],
      ].where((d) => d > 0.01).toList();
      expect(
        steps.length,
        greaterThanOrEqualTo(3),
        reason:
            'a ${total.toStringAsFixed(1)} px change in '
            '${steps.length} frame(s) is a jump: $heights',
      );
    }

    testWidgets('1.6: on screen the sheet never jumps when the meal loads', (
      tester,
    ) async {
      final (loading, loaded, end) = await openAndLoad(
        tester,
        const AndroidNonlinearTextScaler(1.6),
        meal: _withOptions,
      );
      expectNoJump([...loading, ...loaded], end);
      // A known one-line name: the skeleton already had the final size.
      expect(loading.first, moreOrLessEquals(end, epsilon: 1));
      // The header ends above the pinned foot, or the sheet is at its max.
      final macros = find.byType(ExomFigureColumns);
      final foot = find.byKey(const Key('meal-detail-foot'));
      expect(
        tester.getBottomLeft(macros).dy <= tester.getTopLeft(foot).dy + 0.5 ||
            (end - height * 0.95).abs() < 1,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6 with the meal from the caller: the skeleton already has '
        'the final size', (tester) async {
      final (loading, loaded, end) = await openAndLoad(
        tester,
        const AndroidNonlinearTextScaler(1.6),
        meal: _withOptions,
        show: (context) => showMealDetailSheet(
          context,
          mealId: _withOptions.id,
          selectedDate: _date,
          preview: _withOptions,
        ),
      );
      expect(loading, isNotEmpty);
      for (final h in [...loading, ...loaded]) {
        expect(h, moreOrLessEquals(end, epsilon: 1));
      }
      expect(end, greaterThan(height * 0.7));
    });

    testWidgets('1.6 with only the name from the caller: final size at once', (
      tester,
    ) async {
      final (loading, loaded, end) = await openAndLoad(
        tester,
        const AndroidNonlinearTextScaler(1.6),
        meal: _meal,
        show: (context) => showMealDetailSheet(
          context,
          mealId: _meal.id,
          selectedDate: _date,
          previewName: _meal.name,
        ),
      );
      for (final h in [...loading, ...loaded]) {
        expect(h, moreOrLessEquals(end, epsilon: 1));
      }
    });

    testWidgets('1.6, a longer name than foreseen: grows animated, no jump', (
      tester,
    ) async {
      final (loading, loaded, end) = await openAndLoad(
        tester,
        const AndroidNonlinearTextScaler(1.6),
        meal: _longNamed,
      );
      expect(end, greaterThan(loading.last + 1), reason: 'it had to grow');
      expectNoJump([...loading, ...loaded], end);
      final macros = find.byType(ExomFigureColumns);
      final foot = find.byKey(const Key('meal-detail-foot'));
      expect(
        tester.getBottomLeft(macros).dy <= tester.getTopLeft(foot).dy + 0.5 ||
            (end - height * 0.95).abs() < 1,
        isTrue,
      );
    });

    testWidgets('1.6 with reduced motion: any growth is a single step', (
      tester,
    ) async {
      final (loading, loaded, end) = await openAndLoad(
        tester,
        const AndroidNonlinearTextScaler(1.6),
        meal: _longNamed,
        disableAnimations: true,
      );
      final all = [...loading, ...loaded];
      expect(end, greaterThan(loading.last + 1), reason: 'it had to grow');
      final grew = [
        for (var i = 1; i < all.length; i++) all[i] - all[i - 1],
      ].where((d) => d > 0.01);
      expect(grew, hasLength(1), reason: 'instant, in one frame: $all');
      for (var i = 1; i < all.length; i++) {
        expect(all[i], greaterThanOrEqualTo(all[i - 1] - 0.01));
      }
      expect(all.last, moreOrLessEquals(end, epsilon: 0.01));
    });

    testWidgets('1.6: picking an option does not resize the sheet', (
      tester,
    ) async {
      final (_, _, end) = await openAndLoad(
        tester,
        const AndroidNonlinearTextScaler(1.6),
        meal: _withLongOption,
      );
      tester
          .widget<ExomChoiceChips<String>>(
            find.byType(ExomChoiceChips<String>, skipOffstage: false),
          )
          .onSelected!('m-1b');
      final after = await record(tester, 30);
      await tester.pumpAndSettle();
      expect(tester.widget<ExomNumeral>(find.byType(ExomNumeral)).value, '640');
      for (final h in [...after, tester.getSize(draggable).height]) {
        expect(h, moreOrLessEquals(end, epsilon: 0.01));
      }
    });

    testWidgets('1.6: a user drag wins over the late growth', (tester) async {
      final repository = await open(
        tester,
        const AndroidNonlinearTextScaler(1.6),
        meal: _longNamed,
      );
      await record(tester, 40);
      await tester.drag(
        find.descendant(of: draggable, matching: find.byType(Scrollable)).first,
        const Offset(0, 120),
      );
      // The skeleton shimmers forever: pump frames instead of settling.
      await record(tester, 20);
      final dragged = tester.getSize(draggable).height;
      expect(loadedFoot, findsNothing, reason: 'still loading');
      repository.gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester.getSize(draggable).height,
        moreOrLessEquals(dragged, epsilon: 0.01),
      );
    });

    testWidgets('1.0: opens at 70 % and stays there through load and pick', (
      tester,
    ) async {
      final (loading, loaded, end) = await openAndLoad(
        tester,
        TextScaler.noScaling,
        meal: _withOptions,
      );
      for (final h in [...loading, ...loaded]) {
        expect(h, moreOrLessEquals(height * 0.7, epsilon: 0.01));
      }
      expect(end, moreOrLessEquals(height * 0.7, epsilon: 0.01));
      tester
          .widget<ExomChoiceChips<String>>(
            find.byType(ExomChoiceChips<String>, skipOffstage: false),
          )
          .onSelected!('m-1b');
      await tester.pumpAndSettle();
      expect(
        tester.getSize(draggable).height,
        moreOrLessEquals(height * 0.7, epsilon: 0.01),
      );
    });
  });

  // The size is settled when the sheet opens; with it open, turning the phone
  // or changing the text scale must settle it again for the new values.
  group('the open sheet follows screen and text scale changes', () {
    final scale = ValueNotifier<TextScaler>(TextScaler.noScaling);
    final draggable = find.byType(DraggableScrollableSheet);
    final loadedFoot = find.byKey(const Key('meal-detail-foot'));

    Future<void> open(
      WidgetTester tester,
      Size size,
      TextScaler scaler, {
      MealEntity? meal,
    }) async {
      meal ??= _withOptions;
      await loadRedesignFonts();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await sl.reset();
      final repository = _Repository(meal);
      sl.registerFactory<DietBloc>(
        () => DietBloc(
          getTodayDietUseCase: GetTodayDietUseCase(repository),
          getMealUseCase: GetMealUseCase(repository),
          markMealCompletedUseCase: MarkMealCompletedUseCase(repository),
          unmarkMealCompletedUseCase: UnmarkMealCompletedUseCase(repository),
          getCompletedMealsUseCase: GetCompletedMealsUseCase(repository),
        ),
      );
      final mealId = meal.id;
      scale.value = scaler;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showMealDetailSheet(
                    context,
                    mealId: mealId,
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
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => ValueListenableBuilder<TextScaler>(
            valueListenable: scale,
            builder: (context, scaler, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: child!,
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(loadedFoot, findsOneWidget);
    }

    Future<double> freshHeight(
      WidgetTester tester,
      Size size,
      TextScaler scaler,
    ) async {
      await open(tester, size, scaler);
      return tester.getSize(draggable).height;
    }

    const portrait = Size(390, 844);
    const landscape = Size(844, 390);
    const large = AndroidNonlinearTextScaler(1.6);

    testWidgets('text scale 1.0 to 1.6 with the sheet open', (tester) async {
      final expected = await freshHeight(tester, portrait, large);
      await open(tester, portrait, TextScaler.noScaling);
      expect(tester.getSize(draggable).height, lessThan(expected - 1));
      scale.value = large;
      await tester.pumpAndSettle();
      expect(
        tester.getSize(draggable).height,
        moreOrLessEquals(expected, epsilon: 1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 1.6 to 1.0 with the sheet open', (tester) async {
      final expected = await freshHeight(tester, portrait, TextScaler.noScaling);
      await open(tester, portrait, large);
      expect(tester.getSize(draggable).height, greaterThan(expected + 1));
      scale.value = TextScaler.noScaling;
      await tester.pumpAndSettle();
      expect(
        tester.getSize(draggable).height,
        moreOrLessEquals(expected, epsilon: 1),
      );
    });

    testWidgets('turning the phone with the sheet open at 1.6', (tester) async {
      final expected = await freshHeight(tester, landscape, large);
      await open(tester, portrait, large);
      tester.view.physicalSize = landscape;
      await tester.pumpAndSettle();
      expect(
        tester.getSize(draggable).height,
        moreOrLessEquals(expected, epsilon: 1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a sheet the user dragged keeps its size', (tester) async {
      await open(tester, portrait, TextScaler.noScaling);
      await tester.drag(
        find.descendant(of: draggable, matching: find.byType(Scrollable)).first,
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      final dragged = tester.getSize(draggable).height;
      scale.value = large;
      await tester.pumpAndSettle();
      expect(tester.getSize(draggable).height, moreOrLessEquals(dragged));
    });
  });

  // OBS-1 changed the loading skeleton only where it was needed: from text
  // scale 1.3. Below it, it is the plain skeleton of before.
  group('loading skeleton by text scale', () {
    Future<void> load(WidgetTester tester, TextScaler scaler) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await sl.reset();
      final repository = _GatedRepository(_meal);
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
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          ),
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
      addTearDown(() => repository.gate.complete());
    }

    List<double> shimmerHeights(WidgetTester tester) => [
      for (final card in tester.widgetList<ShimmerCard>(
        find.byType(ShimmerCard),
      ))
        card.height,
    ];

    testWidgets('1.0 and 1.29: the plain skeleton of before', (tester) async {
      for (final scaler in [
        TextScaler.noScaling,
        const TextScaler.linear(1.29),
      ]) {
        await load(tester, scaler);
        expect(shimmerHeights(tester), [168, 28, 72, 64, 120]);
      }
    });

    testWidgets('1.3: the skeleton that repeats the loaded header', (
      tester,
    ) async {
      await load(tester, const TextScaler.linear(1.3));
      // Header and foot are the loaded widgets under a mask, not placeholders
      // of their own sizes.
      expect(shimmerHeights(tester), isNot([168, 28, 72, 64, 120]));
      expect(shimmerHeights(tester), contains(120));
    });
  });
}
