import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/services/ingredient_unit_formatter.dart';
import 'package:exom_app/features/diets/services/weekly_shopping_list_builder.dart';

void main() {
  const builder = WeeklyShoppingListBuilder();

  test('principal is default and variant fully replaces it per date', () {
    final monday = DateTime(2026, 6, 15);
    final tuesday = DateTime(2026, 6, 16);
    final main = _meal(
      id: 'meal',
      ingredients: [_ingredient('rice', 'Arroz', 1, 'cup')],
      variants: [
        _meal(
          id: 'variant',
          ingredients: [_ingredient('pasta', 'Pasta', 2, 'cup')],
        ),
      ],
    );
    final week = _week({monday: main, tuesday: main});

    final items = builder.build(
      week: week,
      locale: 'es',
      selections: [
        WeeklyMealSelection(
          date: tuesday,
          parentMealId: main.id,
          selectedMealId: 'variant',
        ),
      ],
    );

    expect(items.map((item) => item.name), ['Arroz', 'Pasta']);
    expect(items.first.quantity, 1);
    expect(items.last.quantity, 2);
  });

  test('same unit sums, mixed convertible units become grams', () {
    final week = _week({
      DateTime(2026, 6, 15): _meal(
        id: 'one',
        ingredients: [
          _ingredient('chicken', 'Pollo', 1, 'palm', grams: 110),
          _ingredient('apple', 'Manzana', 1, 'piece'),
        ],
      ),
      DateTime(2026, 6, 16): _meal(
        id: 'two',
        ingredients: [
          _ingredient('chicken', 'Pollo', 2, 'slice', grams: 80),
          _ingredient('apple', 'Manzana', 2, 'piece'),
        ],
      ),
    });

    final items = builder.build(week: week, locale: 'es');
    final apple = items.firstWhere((item) => item.name == 'Manzana');
    final chicken = items.firstWhere((item) => item.name == 'Pollo');
    expect(apple.quantity, 3);
    expect(apple.unit, 'piece');
    expect(chicken.quantity, 190);
    expect(chicken.unit, 'g');
  });

  test(
    'mixed units without conversion stay separate and to taste appears once',
    () {
      final week = _week({
        DateTime(2026, 6, 15): _meal(
          id: 'one',
          ingredients: [
            _ingredient('salt', 'Sal', 1, 'pinch'),
            _ingredient('salt', 'Sal', 0, 'to_taste'),
            _ingredient('salt', 'Sal', 1, 'teaspoon'),
            _ingredient('salt', 'Sal', 0, 'to_taste'),
          ],
        ),
      });

      final items = builder.build(week: week, locale: 'es');
      expect(items, hasLength(2));
      expect(items.where((item) => item.toTaste), hasLength(1));
      expect(
        items.map((item) => item.unit),
        containsAll(['pinch', 'teaspoon']),
      );
    },
  );

  test('groups by id, falls back to normalized name, and sorts names', () {
    final week = _week({
      DateTime(2026, 6, 15): _meal(
        id: 'one',
        ingredients: [
          _ingredient('', '  AZÚCAR ', 1, 'teaspoon'),
          _ingredient('', 'azucar', 2, 'teaspoon'),
          _ingredient('banana', 'Banana', 1, 'piece'),
        ],
      ),
    });
    final items = builder.build(week: week, locale: 'es');
    expect(items, hasLength(2));
    expect(items.first.name.trim(), 'AZÚCAR');
    expect(items.first.quantity, 3);
    expect(items.last.name, 'Banana');
  });

  test('unit formatter localizes plural, decimals, and unknown codes', () {
    final es = IngredientUnitFormatter(locale: 'es');
    final en = IngredientUnitFormatter(locale: 'en');
    expect(es.amount(quantityValue: 1, unitCode: 'palm'), '1 palma');
    expect(es.amount(quantityValue: 2, unitCode: 'palm'), '2 palmas');
    expect(en.amount(quantityValue: 2, unitCode: 'slice'), '2 slices');
    expect(es.amount(quantityValue: 1.5, unitCode: 'cup'), '1,5 tazas');
    expect(en.amount(quantityValue: 2, unitCode: 'mystery'), '2 mystery');
    expect(es.amount(quantityValue: 0, unitCode: 'to_taste'), 'al gusto');
  });
}

MealIngredientEntity _ingredient(
  String id,
  String name,
  double quantity,
  String unit, {
  double? grams,
}) => MealIngredientEntity(
  id: id,
  name: name,
  quantity: quantity,
  unit: unit,
  gramsEquivalent: grams,
);

MealEntity _meal({
  required String id,
  List<MealIngredientEntity> ingredients = const [],
  List<MealEntity> variants = const [],
}) => MealEntity(
  id: id,
  type: 'LUNCH',
  name: id,
  nutritionalBadges: const [],
  ingredients: ingredients,
  variants: variants,
);

WeeklyDietEntity _week(Map<DateTime, MealEntity> meals) {
  final dates = meals.keys.toList()..sort();
  return WeeklyDietEntity(
    weekStart: dates.first,
    weekEnd: dates.last,
    days: [
      for (final entry in meals.entries)
        WeeklyDietDayEntity(
          date: entry.key,
          diet: DietEntity(id: 'diet', name: 'Diet', meals: [entry.value]),
        ),
    ],
  );
}
