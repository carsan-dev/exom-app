// L6 P12 goldens: a dense training detail (superset and circuit among single
// rows, done / in progress / pending), the first rest of a session with no
// earlier history and no next exercise, and the extreme scene (320x640 dp,
// 1.3x text, a 40-character word and a 120-character phrase) in the training
// detail and in the meal detail. Dark and light.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l6_p12_densos_y_extremos_golden_test.dart
@Tags(['golden'])
library;

import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/widgets/exom_component_harness.dart' show expectNoOverflow;
import '../features/diets/diets_redesign_fixture.dart';
import '../features/trainings/presentation/pages/active_exercise_redesign_test.dart'
    show activeExerciseDraftKey, activeExerciseTrainingId, pumpActiveExercise;
import '../features/trainings/presentation/pages/training_detail_redesign_test.dart'
    show pumpDenseTrainingDetail, pumpTrainingDetail;
import 'redesign_scenes.dart' show loadRedesignFonts;

/// 40 characters, no spaces.
const _word = 'SentadillaSentadillaSentadillaSentadilla';

/// 120 characters, with spaces.
final _phrase =
    ('Sentadilla búlgara con mancuernas y pausa isométrica abajo seguida de un '
                'empuje explosivo hacia arriba ' *
            2)
        .substring(0, 120)
        .trim();

TrainingExerciseEntity _exercise(int order, String name) =>
    TrainingExerciseEntity(
      id: 'te-$order',
      order: order,
      sets: 3,
      repsOrDuration: '8',
      measureType: ExerciseMeasureType.reps,
      targetValue: 8,
      targetRir: 2,
      restSeconds: 90,
      requestSetTracking: true,
      exercise: ExerciseEntity(id: 'ex-$order', name: name, muscleGroups: []),
    );

DietEntity _extremeDiet() => DietEntity(
  id: 'diet-1',
  name: _phrase,
  totalCalories: 2150,
  totalProteinG: 160,
  totalCarbsG: 220,
  totalFatG: 70,
  meals: [
    MealEntity(
      id: 'm-lunch',
      type: 'LUNCH',
      name: _phrase,
      calories: 780,
      proteinG: 41,
      carbsG: 70,
      fatG: 37,
      nutritionalBadges: [_word, 'Proteína'],
      ingredients: [
        MealIngredientEntity(id: 'i-1', name: _phrase, quantity: 80, unit: 'g'),
        MealIngredientEntity(id: 'i-2', name: _word, quantity: 1.5, unit: 'g'),
      ],
      variants: [
        MealEntity(
          id: 'm-lunch-b',
          type: 'LUNCH',
          name: _word,
          calories: 740,
          proteinG: 38,
          carbsG: 82,
          fatG: 21,
          nutritionalBadges: const [],
          ingredients: const [],
          variants: const [],
        ),
      ],
    ),
  ],
);

void main() {
  for (final brightness in Brightness.values) {
    final b = brightness.name;

    testWidgets('golden detalle_denso_${b}_1_0x', (tester) async {
      await loadRedesignFonts();
      await initializeDateFormatting('es');
      await pumpDenseTrainingDetail(tester, brightness: brightness);
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/detalle_denso_${b}_1_0x.png'),
      );
    });

    // First rest of the session: the first set just logged, no earlier
    // history for the exercise and no next exercise in the plan.
    testWidgets('golden descanso_vacio_${b}_1_0x', (tester) async {
      await initializeDateFormatting('es');
      final only = _exercise(1, 'Sentadilla búlgara');
      await pumpActiveExercise(
        tester,
        initialWeightKg: 60,
        seed: ActiveWorkoutHiveModel(
          trainingId: activeExerciseTrainingId,
          exerciseId: activeExerciseDraftKey,
          currentSet: 2,
          completedSets: 1,
          restEndsAt: DateTime.now().add(const Duration(seconds: 90)),
          lastWeightKg: 60,
          completedSetData: const [
            {'set_number': 1, 'reps': 8, 'weight_kg': 60.0, 'rir': 2},
          ],
        ),
        exercise: only,
        trainingExercises: [only],
        brightness: brightness,
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/descanso_vacio_${b}_1_0x.png'),
      );
    });

    testWidgets('golden extremos_320_detalle_${b}_1_3x', (tester) async {
      await loadRedesignFonts();
      await initializeDateFormatting('es');
      await pumpTrainingDetail(
        tester,
        training: TrainingEntity(
          id: 'training-1',
          name: _phrase,
          types: const ['FUERZA'],
          level: 'INTERMEDIATE',
          estimatedDurationMin: 55,
          tags: const [],
          exercises: [_exercise(1, _word), _exercise(2, _phrase)],
        ),
        width: 320,
        locale: const Locale('es'),
        textScaler: const TextScaler.linear(1.3),
        brightness: brightness,
      );
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/extremos_320_detalle_${b}_1_3x.png'),
      );
    });

    testWidgets('golden extremos_320_detalle_comida_${b}_1_3x', (tester) async {
      await loadRedesignFonts();
      await initializeDateFormatting('es');
      await pumpMealSheetScene(
        tester,
        diet: _extremeDiet(),
        brightness: brightness,
        width: 320,
        height: 640,
        textScale: 1.3,
      );
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/extremos_320_detalle_comida_${b}_1_3x.png'),
      );
    });
  }
}
