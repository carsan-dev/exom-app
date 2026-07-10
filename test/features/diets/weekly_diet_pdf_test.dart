import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/diets/data/models/weekly_diet_model.dart';
import 'package:exom_app/features/diets/data/models/monthly_diet_model.dart';
import 'package:exom_app/features/diets/data/models/diet_model.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';

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
}
