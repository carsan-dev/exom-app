import 'dart:convert';
import 'dart:io';

import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/diets/data/models/weekly_diet_model.dart';
import 'package:exom_app/features/diets/data/models/monthly_diet_model.dart';
import 'package:exom_app/features/diets/data/models/diet_model.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';

/// Inflated content streams of the pages of [bytes], in page order (the PDF
/// writer emits one compressed content stream per page; font and image
/// streams do not set a fill colour with `rg`).
List<String> _pageContentStreams(List<int> bytes) {
  final text = latin1.decode(bytes);
  final pages = <String>[];
  var from = 0;
  while (true) {
    final marker = text.indexOf('stream\n', from);
    if (marker < 0) break;
    final start = marker + 'stream\n'.length;
    final end = text.indexOf('endstream', start);
    from = end + 'endstream'.length;
    final String decoded;
    try {
      decoded = latin1.decode(ZLibCodec().decode(bytes.sublist(start, end)));
    } on FormatException {
      continue;
    }
    if (decoded.contains(' rg')) pages.add(decoded);
  }
  return pages;
}

/// Day boxes of the weekly diet PDF drawn with nothing inside, per page
/// (1-based). A day box is the stroke of its border colour (#E5D4C5); its
/// content is painted right after the stroke, inside the graphics state that
/// encloses the box, so an empty box closes that state without any text.
Map<int, int> _emptyDayBoxesPerPage(List<int> bytes) {
  final result = <int, int>{};
  final pages = _pageContentStreams(bytes);
  for (var page = 0; page < pages.length; page++) {
    final content = pages[page];
    var from = 0;
    while (true) {
      final box = content.indexOf(_borderStroke, from);
      if (box < 0) break;
      final stroke = content.indexOf(' S ', box);
      from = stroke + 3;
      var depth = 0;
      var hasText = false;
      for (final token in content.substring(from).split(RegExp(r'\s+'))) {
        if (token == 'q') depth++;
        if (token == 'Q') depth--;
        if (token == 'BT') hasText = true;
        if (depth < 0 || hasText) break;
      }
      if (!hasText) result[page + 1] = (result[page + 1] ?? 0) + 1;
    }
  }
  return result;
}

const _borderStroke = '0.89804 0.83137 0.77255 RG 1 w';

/// Day boxes drawn per page (1-based), empty or not. A box that spans two
/// pages counts once on each.
Map<int, int> _dayBoxesPerPage(List<int> bytes) {
  final pages = _pageContentStreams(bytes);
  return {
    for (var page = 0; page < pages.length; page++)
      page + 1: _borderStroke.allMatches(pages[page]).length,
  };
}

/// Meal name long enough to wrap onto a second line at 10 pt in an A4 box.
const _twoLineMealName =
    'Bowl templado de arroz integral con pollo a la plancha, verduras '
    'salteadas, aguacate y semillas de calabaza con aliño de limón';

/// Plan name long enough to wrap onto several lines at 11 pt.
const _longPlanName =
    'Plan de alimentación personalizado de definición muscular con enfoque '
    'en proteína alta, hidratos de carbono cíclicos y grasas saludables, '
    'revisado cada dos semanas por el equipo de nutrición del centro';

DietEntity _dietWithMeals(
  int meals, {
  String planName = 'Plan',
  String mealName = 'Comida',
}) => DietEntity(
  id: 'diet-${meals}m',
  name: planName,
  meals: List.generate(
    meals,
    (index) => MealEntity(
      id: 'meal-$index',
      type: 'LUNCH',
      name: '$mealName $index',
      nutritionalBadges: const [],
      ingredients: const [],
      variants: const [],
    ),
  ),
);

WeeklyDietDayEntity _dayWithMeals(
  DateTime date,
  int meals, {
  String planName = 'Plan',
  String mealName = 'Comida',
}) => WeeklyDietDayEntity(
  date: date,
  diet: _dietWithMeals(meals, planName: planName, mealName: mealName),
);

const _weeklyLabels = WeeklyDietPdfLabels(
  title: 'Dieta semanal',
  noDiet: 'Sin dieta asignada',
  ingredients: 'Ingredientes',
  alternatives: 'Alternativa',
  mealTypes: {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('weekly model parses assigned and empty days', () {
    final model = WeeklyDietModel.fromJson({
      'week_start': '2026-06-15',
      'week_end': '2026-06-21',
      'days': [
        {'date': '2026-06-15', 'diet': null},
        {
          'date': '2026-06-16',
          'diet': {'id': 'diet-1', 'name': 'Plan', 'meals': []},
        },
      ],
    });

    expect(model.weekStart, DateTime(2026, 6, 15));
    expect(model.days.first.diet, isNull);
    expect(model.days.last.diet?.name, 'Plan');
  });

  test('monthly model parses 31 days including empty assignments', () {
    final model = MonthlyDietModel.fromJson({
      'month_start': '2026-07-01',
      'month_end': '2026-07-31',
      'days': List.generate(
        31,
        (index) => {
          'date': '2026-07-${(index + 1).toString().padLeft(2, '0')}',
          'diet': null,
        },
      ),
    });
    expect(model.monthStart, DateTime(2026, 7, 1));
    expect(model.monthEnd, DateTime(2026, 7, 31));
    expect(model.days, hasLength(31));
    expect(model.days.every((day) => day.diet == null), isTrue);
  });

  test('ingredient model preserves id and accepts old cache without it', () {
    final current = MealIngredientModel.fromJson({
      'quantity': 1,
      'unit': 'piece',
      'ingredient': {'id': 'ingredient-1', 'name': 'Apple'},
    });
    final cached = MealIngredientModel.fromJson({
      'quantity': 1,
      'unit': 'piece',
      'ingredient': {'name': 'Apple'},
    });
    expect(current.id, 'ingredient-1');
    expect(cached.id, '');
  });

  test('PDF service creates a valid localized document', () async {
    final week = WeeklyDietEntity(
      weekStart: DateTime(2026, 6, 15),
      weekEnd: DateTime(2026, 6, 21),
      days: List.generate(
        7,
        (index) => WeeklyDietDayEntity(
          date: DateTime(2026, 6, 15 + index),
          diet: null,
        ),
      ),
    );

    final bytes = await const WeeklyDietPdfService().build(
      week: week,
      locale: 'es',
      labels: const WeeklyDietPdfLabels(
        title: 'Dieta semanal',
        noDiet: 'Sin dieta asignada',
        ingredients: 'Ingredientes',
        alternatives: 'Alternativa',
        mealTypes: {},
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('shopping list PDF creates a multipage valid document', () async {
    final week = WeeklyDietEntity(
      weekStart: DateTime(2026, 6, 15),
      weekEnd: DateTime(2026, 6, 21),
      days: const [],
    );
    final items = List.generate(
      120,
      (index) => ShoppingListItem(
        ingredientKey: '$index',
        name: 'Ingrediente español $index',
        quantity: index + 1,
        unit: 'piece',
        gramsEquivalent: null,
        toTaste: false,
      ),
    );
    final bytes = await const WeeklyDietPdfService().buildShoppingList(
      week: week,
      items: items,
      locale: 'es',
      labels: const WeeklyShoppingListPdfLabels(
        title: 'Lista de la compra',
        empty: 'Lista vacía',
      ),
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  group('weekly diet PDF page breaks (L4-I25c)', () {
    /// Variants of the week matrix; each one is built with 1 to 14 meals
    /// per day so the page break crosses every position of a day box.
    final variants = <String, List<WeeklyDietDayEntity> Function(int meals)>{
      'plain': (meals) => List.generate(
        7,
        (index) => _dayWithMeals(DateTime(2026, 6, 15 + index), meals),
      ),
      'day without diet': (meals) => List.generate(
        7,
        (index) => index.isOdd
            ? WeeklyDietDayEntity(
                date: DateTime(2026, 6, 15 + index),
                diet: null,
              )
            : _dayWithMeals(DateTime(2026, 6, 15 + index), meals),
      ),
      'two-line meal names': (meals) => List.generate(
        7,
        (index) => _dayWithMeals(
          DateTime(2026, 6, 15 + index),
          meals,
          mealName: _twoLineMealName,
        ),
      ),
      'long plan name': (meals) => List.generate(
        7,
        (index) => _dayWithMeals(
          DateTime(2026, 6, 15 + index),
          meals,
          planName: _longPlanName,
        ),
      ),
    };

    for (final entry in variants.entries) {
      test('no day box is left empty or blank page (${entry.key})', () async {
        final emptyByMeals = <int, Map<int, int>>{};
        final blankByMeals = <int, List<int>>{};
        for (var meals = 1; meals <= 14; meals++) {
          final week = WeeklyDietEntity(
            weekStart: DateTime(2026, 6, 15),
            weekEnd: DateTime(2026, 6, 21),
            days: entry.value(meals),
          );
          final bytes = await const WeeklyDietPdfService().build(
            week: week,
            locale: 'es',
            labels: _weeklyLabels,
          );
          expect(_pageContentStreams(bytes), isNotEmpty);
          final boxes = _dayBoxesPerPage(bytes);
          // The detector must find a box per painted day (7 per week), or a
          // change of the stroke format would make the check pass vacuously.
          expect(
            boxes.values.fold<int>(0, (a, b) => a + b),
            greaterThanOrEqualTo(7),
            reason: '${entry.key}, $meals meals: day boxes found',
          );
          final blank = [
            for (final page in boxes.entries)
              if (page.value == 0) page.key,
          ];
          if (blank.isNotEmpty) blankByMeals[meals] = blank;
          final empty = _emptyDayBoxesPerPage(bytes);
          if (empty.isNotEmpty) emptyByMeals[meals] = empty;
        }
        expect(
          emptyByMeals,
          isEmpty,
          reason: 'meals per day -> {page: empty day boxes}',
        );
        expect(
          blankByMeals,
          isEmpty,
          reason: 'meals per day -> pages without any day box',
        );
      });
    }

    for (final days in [28, 31]) {
      test('monthly menu of $days days: no empty box, no blank page', () async {
        final start = DateTime(2026, days == 28 ? 2 : 7, 1);
        final period = DietPeriodEntity(
          start: start,
          end: DateTime(start.year, start.month, days),
          days: List.generate(
            days,
            (index) => DietPeriodDayEntity(
              date: DateTime(start.year, start.month, index + 1),
              diet: index % 5 == 4 ? null : _dietWithMeals(2 + index % 4),
            ),
          ),
        );
        final bytes = await const WeeklyDietPdfService().build(
          week: period,
          locale: 'es',
          labels: _weeklyLabels,
        );
        final boxes = _dayBoxesPerPage(bytes);
        expect(
          boxes.values.fold<int>(0, (a, b) => a + b),
          greaterThanOrEqualTo(days),
        );
        expect(boxes.length, greaterThan(1));
        expect(
          boxes.entries.where((page) => page.value == 0),
          isEmpty,
          reason: 'pages without any day box (first and last included)',
        );
        expect(_emptyDayBoxesPerPage(bytes), isEmpty);
      });
    }

    test('the detector sees the text of every filled day box', () async {
      final week = WeeklyDietEntity(
        weekStart: DateTime(2026, 6, 15),
        weekEnd: DateTime(2026, 6, 15),
        days: [_dayWithMeals(DateTime(2026, 6, 15), 2)],
      );
      final bytes = await const WeeklyDietPdfService().build(
        week: week,
        locale: 'es',
        labels: _weeklyLabels,
      );
      final pages = _pageContentStreams(bytes);
      expect(pages, hasLength(1));
      expect(_borderStroke.allMatches(pages.single), hasLength(1));
      expect(_emptyDayBoxesPerPage(bytes), isEmpty);
    });
  });
}
