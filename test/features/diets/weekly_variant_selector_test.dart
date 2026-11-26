// Presentation only: «Elige tus alternativas» of the shopping list. L5-E8
// (L5-D16) turned the former bottom sheet (`WeeklyVariantSelector`) into the
// pushed screen ShoppingListSetupPage; this file keeps the sheet's coverage on
// the screen: default and picked choice, few and many meals, long names never
// cut, 320 dp at 1.3x, and the action reachable above the system inset.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/presentation/pages/shopping_list_pages.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

MealEntity _meal(
  String id,
  String name, {
  List<MealEntity> variants = const [],
}) => MealEntity(
  id: id,
  type: 'LUNCH',
  name: name,
  nutritionalBadges: const [],
  ingredients: const [],
  variants: variants,
);

DietPeriodEntity _period(int meals) => DietPeriodEntity(
  start: DateTime(2026, 11, 1),
  end: DateTime(2026, 11, 30),
  days: [
    for (var i = 0; i < meals; i++)
      DietPeriodDayEntity(
        date: DateTime(2026, 11, 1 + i),
        diet: DietEntity(
          id: 'd$i',
          name: 'Dieta $i',
          meals: [
            _meal(
              'm$i',
              'Principal $i',
              variants: [_meal('v$i', 'Alternativa $i')],
            ),
          ],
        ),
      ),
  ],
);

const _longA = 'Cena de verduras asadas con salsa de yogur griego y limón';
const _longB = 'Cena de verduras asadas con salsa de yogur griego y menta';

DietPeriodEntity _periodWith(List<MealEntity> variants) => DietPeriodEntity(
  start: DateTime(2026, 11, 1),
  end: DateTime(2026, 11, 1),
  days: [
    DietPeriodDayEntity(
      date: DateTime(2026, 11, 1),
      diet: DietEntity(
        id: 'd',
        name: 'Dieta',
        meals: [_meal('m', 'Pollo al horno', variants: variants)],
      ),
    ),
  ],
);

Future<void> _open(
  WidgetTester tester,
  DietPeriodEntity period, {
  Size size = const Size(390, 800),
  double textScale = 1.0,
  double bottomInset = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: EdgeInsets.only(bottom: bottomInset),
          viewPadding: EdgeInsets.only(bottom: bottomInset),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => pushShoppingListRoute<void>(
              context,
              (_) => ShoppingListSetupPage(
                period: period,
                calendarMonth: true,
                mealTypes: const {'LUNCH': 'Comida'},
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

final _generate = find.byKey(const Key('shopping-list-generate'));

Future<ShoppingListPage> _tapGenerate(WidgetTester tester) async {
  await tester.tap(_generate);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return tester.widget<ShoppingListPage>(find.byType(ShoppingListPage));
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('result: defaults to the main meal, picks the alternative', (
    tester,
  ) async {
    await _open(tester, _period(2));
    await tester.ensureVisible(find.text('Alternativa 0'));
    await tester.pump();
    await tester.tap(find.text('Alternativa 0'));
    await tester.pump();
    final result = (await _tapGenerate(tester)).selections;
    expect(result.map((s) => s.parentMealId), ['m0', 'm1']);
    expect(result.map((s) => s.selectedMealId), ['v0', 'm1']);
    expect(result.first.date, DateTime(2026, 11, 1));
  });

  testWidgets('20 meals: the list scrolls, «Generar lista» stays in view', (
    tester,
  ) async {
    await _open(tester, _period(20));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.getRect(_generate).bottom, lessThanOrEqualTo(800));
    expect((await _tapGenerate(tester)).selections, hasLength(20));
  });

  testWidgets('320 dp at 1.3x does not overflow, few and many', (tester) async {
    for (final meals in [1, 20]) {
      await _open(
        tester,
        _period(meals),
        size: const Size(320, 640),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull, reason: '$meals meals');
      expect(_generate, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('320 dp: long alternative names are shown whole, never cut', (
    tester,
  ) async {
    await _open(
      tester,
      _periodWith([_meal('va', _longA), _meal('vb', _longB)]),
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ExomSegmentedControl<String>), findsOneWidget);
    for (final name in [_longA, _longB]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      expect(paragraph.didExceedMaxLines, isFalse, reason: name);
      expect(paragraph.text.toPlainText(), name);
    }
    await tester.ensureVisible(find.text(_longB));
    await tester.pump();
    await tester.tap(find.text(_longB));
    await tester.pump();
    expect(
      (await _tapGenerate(tester)).selections.map((s) => s.selectedMealId),
      ['vb'],
    );
  });

  testWidgets('more than three options: chips instead of the segmented', (
    tester,
  ) async {
    await _open(
      tester,
      _periodWith([
        for (final id in ['a', 'b', 'c']) _meal('v$id', 'Opción $id'),
      ]),
    );
    expect(find.byType(ExomSegmentedControl<String>), findsNothing);
    expect(find.byType(ExomChoiceChips<String>), findsOneWidget);
    await tester.ensureVisible(find.text('Opción c'));
    await tester.pump();
    await tester.tap(find.text('Opción c'));
    await tester.pump();
    expect(
      (await _tapGenerate(tester)).selections.map((s) => s.selectedMealId),
      ['vc'],
    );
  });

  for (final inset in [0.0, 24.0]) {
    testWidgets('«Generar lista» sits 12 dp above the system inset ($inset)', (
      tester,
    ) async {
      await _open(
        tester,
        _period(1),
        size: const Size(411, 914),
        bottomInset: inset,
      );
      expect(tester.takeException(), isNull);
      final gap = 914 - tester.getRect(_generate).bottom;
      expect(gap, moreOrLessEquals(12 + inset, epsilon: 1));
      expect(tester.getSize(_generate).height, greaterThanOrEqualTo(48));
    });
  }

  testWidgets('opened from a ShellRoute with inflated padding: the footer '
      'does not inherit the shell gap (root navigator)', (tester) async {
    const inset = 24.0;
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    double? shellPadding;
    final router = GoRouter(
      routes: [
        ShellRoute(
          // Like MainShell: extendBody + a bottom bar inflates the body's
          // MediaQuery padding (system inset + bar).
          builder: (context, state, child) => Scaffold(
            extendBody: true,
            bottomNavigationBar: const SizedBox(height: 65),
            body: child,
          ),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) {
                shellPadding = MediaQuery.paddingOf(context).bottom;
                return Center(
                  child: TextButton(
                    onPressed: () => pushShoppingListRoute<void>(
                      context,
                      (_) => ShoppingListSetupPage(
                        period: _period(1),
                        calendarMonth: true,
                        mealTypes: const {'LUNCH': 'Comida'},
                      ),
                    ),
                    child: const Text('abrir'),
                  ),
                );
              },
            ),
          ],
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
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(bottom: inset),
            viewPadding: const EdgeInsets.only(bottom: inset),
          ),
          child: child!,
        ),
      ),
    );
    await tester.pump();
    // Precondition: the shell really inflates the padding (the 89 dp case).
    expect(shellPadding, greaterThan(inset + 40));
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    final gap = 914 - tester.getRect(_generate).bottom;
    expect(gap, moreOrLessEquals(12 + inset, epsilon: 1));
  });
}
