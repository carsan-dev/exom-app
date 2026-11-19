// Presentation only: the "Elegir alternativas" sheet of the shopping list.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/presentation/widgets/weekly_shopping_list_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
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

DietPeriodEntity _periodWithLongVariants() => DietPeriodEntity(
  start: DateTime(2026, 11, 1),
  end: DateTime(2026, 11, 1),
  days: [
    DietPeriodDayEntity(
      date: DateTime(2026, 11, 1),
      diet: DietEntity(
        id: 'd',
        name: 'Dieta',
        meals: [
          _meal(
            'm',
            'Pollo al horno',
            variants: [_meal('va', _longA), _meal('vb', _longB)],
          ),
        ],
      ),
    ),
  ],
);

class _Opened {
  List<WeeklyMealSelection>? result;
  bool closed = false;
}

Future<_Opened> _open(
  WidgetTester tester,
  DietPeriodEntity period, {
  Size size = const Size(390, 800),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final opened = _Opened();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              opened.result =
                  await showModalBottomSheet<List<WeeklyMealSelection>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => WeeklyVariantSelector(
                      week: period,
                      locale: 'es',
                      title: 'Elegir alternativas',
                      mainLabel: 'Principal',
                      generateLabel: 'Generar lista',
                      mealTypes: const {'LUNCH': 'Comida'},
                    ),
                  );
              opened.closed = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return opened;
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  final generate = find.text('Generar lista');
  final sheet = find.byType(WeeklyVariantSelector);

  for (final meals in [1, 2]) {
    testWidgets('$meals meal(s): sheet hugs its content, button under list', (
      tester,
    ) async {
      await _open(tester, _period(meals));
      expect(tester.takeException(), isNull);
      final screen = tester.view.physicalSize.height;
      expect(tester.getSize(sheet).height, lessThan(screen * 0.85 * 0.6));
      final listBottom = tester.getRect(find.byType(ListView)).bottom;
      final buttonTop = tester.getRect(find.byType(FilledButton)).top;
      expect(buttonTop - listBottom, lessThanOrEqualTo(24));
      expect(buttonTop - listBottom, greaterThanOrEqualTo(0));
    });
  }

  testWidgets('20 meals: capped at 85 %, list scrolls, button stays tappable', (
    tester,
  ) async {
    final opened = await _open(tester, _period(20));
    final screen = tester.view.physicalSize.height;
    expect(
      tester.getSize(sheet).height,
      lessThanOrEqualTo(screen * 0.85 + 0.5),
    );
    expect(tester.getSize(sheet).height, greaterThan(screen * 0.6));
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
    expect(
      tester.getRect(find.byType(FilledButton)).bottom,
      lessThanOrEqualTo(screen),
    );
    await tester.tap(generate);
    await tester.pump(const Duration(milliseconds: 500));
    expect(opened.closed, isTrue);
    expect(opened.result, hasLength(20));
  });

  testWidgets('result: defaults to the main meal, picks the alternative', (
    tester,
  ) async {
    final opened = await _open(tester, _period(2));
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Alternativa 0').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(generate);
    await tester.pump(const Duration(milliseconds: 500));
    final result = opened.result!;
    expect(result.map((s) => s.parentMealId), ['m0', 'm1']);
    expect(result.map((s) => s.selectedMealId), ['v0', 'm1']);
    expect(result.first.date, DateTime(2026, 11, 1));
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
      expect(generate, findsOneWidget);
      expect(tester.getSize(sheet).height, lessThanOrEqualTo(640 * 0.85 + 0.5));
      await tester.tapAt(const Offset(160, 20));
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('320 dp: closed field is one line, open menu shows full names', (
    tester,
  ) async {
    final opened = await _open(
      tester,
      _periodWithLongVariants(),
      size: const Size(320, 640),
    );
    final field = find.byType(DropdownButtonFormField<String>).first;
    expect(tester.takeException(), isNull);
    final closedText = tester.widget<Text>(
      find.descendant(
        of: field,
        matching: find.text('Principal: Pollo al horno'),
      ).first,
    );
    expect(closedText.maxLines, 1);

    await tester.tap(field);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    for (final name in [_longA, _longB]) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(name).last,
      );
      expect(paragraph.didExceedMaxLines, isFalse, reason: name);
      expect(paragraph.text.toPlainText(), name);
    }

    await tester.tap(find.text(_longB).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(generate);
    await tester.pump(const Duration(milliseconds: 500));
    expect(opened.result!.map((s) => s.selectedMealId), ['vb']);
  });
}
