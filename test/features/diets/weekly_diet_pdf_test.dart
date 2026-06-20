import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/diets/data/models/weekly_diet_model.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';

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
}
