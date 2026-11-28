// L6 S11-07: extreme exercise, training and meal names (a 40-character word
// without spaces and a 120-character phrase) on the screens of the L5
// redesign, at 320 dp wide with 1.3x text, in both themes. Complements
// long_string_overflow_test.dart, which sweeps realistic names in one theme.
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../features/challenges/challenges_test_support.dart';
import '../features/diets/diets_redesign_fixture.dart';
import '../features/home/presentation/pages/home_e1_harness.dart' as inicio;
import '../features/recap/presentation/pages/recap_detail_redesign_test.dart'
    show pumpDetail, recapDetailFilled;
import '../features/trainings/presentation/pages/active_exercise_redesign_test.dart'
    show activeExerciseDraftKey, activeExerciseTrainingId, pumpActiveExercise;
import '../features/trainings/presentation/pages/circuit_test_harness.dart'
    show circuitExercise, preL3State, pumpCircuit;
import '../features/trainings/presentation/pages/training_detail_redesign_test.dart'
    show pumpTrainingDetail;

const _scaler = TextScaler.linear(1.3);
const _themes = [Brightness.light, Brightness.dark];

/// 40 characters, no spaces.
const _word = 'SentadillaSentadillaSentadillaSentadilla';

/// 120 characters, with spaces.
final _phrase =
    ('Sentadilla búlgara con mancuernas y pausa isométrica abajo seguida de un '
                'empuje explosivo hacia arriba ' *
            2)
        .substring(0, 120)
        .trim();

const _kinds = ['word', 'phrase'];

String _name(String kind) => kind == 'word' ? _word : _phrase;

String _label(Brightness brightness, String kind) =>
    '${brightness.name}, $kind name';

TrainingExerciseEntity _exercise(int order, String name, {int sets = 3}) =>
    TrainingExerciseEntity(
      id: 'te-$order',
      order: order,
      sets: sets,
      repsOrDuration: '8',
      measureType: ExerciseMeasureType.reps,
      targetValue: 8,
      targetRir: 2,
      restSeconds: 90,
      requestSetTracking: true,
      exercise: ExerciseEntity(
        id: 'ex-$order',
        name: name,
        muscleGroups: [_word, _phrase],
        techniqueText: '- $_phrase\n- $_word',
        commonErrorsText: '- $_phrase\n- $_word',
        explanationText: _phrase,
      ),
    );

Future<void> _scrollAll(WidgetTester tester, {int steps = 10}) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < steps; i++) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

DietEntity _diet(String name) => DietEntity(
  id: 'diet-1',
  name: name,
  totalCalories: 2150,
  totalProteinG: 160,
  totalCarbsG: 220,
  totalFatG: 70,
  meals: [
    MealEntity(
      id: 'm-breakfast',
      type: 'BREAKFAST',
      name: name,
      calories: 520,
      proteinG: 27,
      carbsG: 38,
      fatG: 14,
      nutritionalBadges: [_word, 'Proteína'],
      ingredients: const [],
      variants: const [],
    ),
    MealEntity(
      id: 'm-lunch',
      type: 'LUNCH',
      name: name,
      calories: 780,
      proteinG: 41,
      carbsG: 70,
      fatG: 37,
      nutritionalBadges: [_word, _phrase],
      ingredients: [
        MealIngredientEntity(id: 'i-1', name: name, quantity: 80, unit: 'g'),
        MealIngredientEntity(id: 'i-2', name: _word, quantity: 1.5, unit: 'g'),
      ],
      variants: [
        MealEntity(
          id: 'm-lunch-b',
          type: 'LUNCH',
          name: name,
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
    MealEntity(
      id: 'm-dinner',
      type: 'DINNER',
      name: _word,
      calories: 550,
      proteinG: 57,
      carbsG: 37,
      fatG: 11,
      nutritionalBadges: const [],
      ingredients: const [],
      variants: const [],
    ),
  ],
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  test('fixtures have the documented lengths', () {
    expect(_word.length, 40);
    expect(_word.contains(' '), isFalse);
    expect(_phrase.length, inInclusiveRange(118, 120));
  });

  group('Inicio with extreme names', () {
    for (final brightness in _themes) {
      for (final kind in _kinds) {
        testWidgets(_label(brightness, kind), (tester) async {
          final name = _name(kind);
          await inicio.pumpInicioE1(
            tester,
            repository: inicio.InicioE1Repository(
              (_) => HomeSummaryEntity(
                trainingId: 'training-1',
                trainingName: name,
                trainingDurationMin: 55,
                remainingTrainingDurationMin: 30,
                trainings: [
                  HomeTrainingItemEntity(
                    id: 'training-1',
                    name: name,
                    completed: false,
                  ),
                  HomeTrainingItemEntity(
                    id: 'training-2',
                    name: name,
                    completed: true,
                  ),
                ],
                exercisesCompleted: 2,
                totalExercises: 6,
                totalSets: 22,
                streakDays: 12,
                dietId: 'diet-1',
                dietName: name,
                nextMealId: 'meal-1',
                nextMealName: name,
                totalCalories: 2150,
                remainingCalories: 1400,
                mealsCompleted: 1,
                totalMeals: 4,
                clientName: name,
              ),
            ),
            calendar: inicio.InicioE1Calendar(inicio.InicioE1Calendar.week({})),
            width: 320,
            height: 640,
            brightness: brightness,
            textScaler: _scaler,
          );
          expect(tester.takeException(), isNull);
          await _scrollAll(tester);
        });
      }
    }
  });

  group('Detalle del entreno y hoja de ejercicio with extreme names', () {
    tearDown(() async => sl.reset());
    for (final brightness in _themes) {
      for (final kind in _kinds) {
        for (final started in const [false, true]) {
          testWidgets('${_label(brightness, kind)}, '
              '${started ? 'in progress' : 'before starting'}', (tester) async {
            final name = _name(kind);
            await pumpTrainingDetail(
              tester,
              training: TrainingEntity(
                id: 'training-1',
                name: name,
                types: const ['FUERZA'],
                level: 'INTERMEDIATE',
                estimatedDurationMin: 55,
                tags: const [],
                exercises: [
                  _exercise(1, '$name.', sets: 4),
                  _exercise(2, name),
                  _exercise(3, _word),
                ],
              ),
              completed: started ? const {'te-1'} : const {},
              width: 320,
              locale: const Locale('es'),
              textScaler: _scaler,
              brightness: brightness,
            );
            expect(tester.takeException(), isNull);
            await _scrollAll(tester, steps: 12);
            // Hoja de ejercicio: opens from the first row.
            final scrollable = find.byType(Scrollable).first;
            await tester.drag(scrollable, const Offset(0, 6000));
            await tester.pump();
            final row = find.text('$name.');
            await tester.scrollUntilVisible(row, 100, scrollable: scrollable);
            await tester.pumpAndSettle();
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            await tester.tap(row);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('Ejercicio activo y descanso with extreme names', () {
    for (final brightness in _themes) {
      for (final kind in _kinds) {
        for (final scene in const ['executing', 'rest']) {
          testWidgets('${_label(brightness, kind)}, $scene', (tester) async {
            final name = _name(kind);
            final current = _exercise(1, name);
            final next = _exercise(0, name);
            await pumpActiveExercise(
              tester,
              initialWeightKg: 62.5,
              previous: const [
                SetPerformance(setNumber: 1, reps: 8, weightKg: 60, rir: 2),
              ],
              seed: ActiveWorkoutHiveModel(
                trainingId: activeExerciseTrainingId,
                exerciseId: activeExerciseDraftKey,
                currentSet: 2,
                completedSets: 1,
                restEndsAt: scene == 'rest'
                    ? DateTime.now().add(const Duration(seconds: 90))
                    : null,
                lastWeightKg: 62.5,
                completedSetData: const [
                  {'set_number': 1, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
                ],
              ),
              exercise: current,
              trainingExercises: [next, current],
              width: 320,
              height: 640,
              brightness: brightness,
              textScaler: _scaler,
            );
            for (var i = 0; i < 4; i++) {
              await tester.pump(const Duration(milliseconds: 150));
            }
            expect(tester.takeException(), isNull);
            await _scrollAll(tester);
          });
        }
      }
    }
  });

  group('Circuito y descanso de ronda with extreme names', () {
    const logged = {
      'a': [
        {'set_number': 1, 'reps': 12, 'weight_kg': 62.5, 'rir': 2},
      ],
      'b': [
        {'set_number': 1, 'reps': 12},
      ],
    };
    for (final brightness in _themes) {
      for (final kind in _kinds) {
        for (final resting in const [false, true]) {
          testWidgets('${_label(brightness, kind)}, '
              '${resting ? 'round rest' : 'executing'}', (tester) async {
            final name = _name(kind);
            await pumpCircuit(
              tester,
              exercises: [
                circuitExercise('a', name, targetRir: 2, restSeconds: 30),
                circuitExercise('b', _word, restSeconds: 20),
                circuitExercise('c', name, targetValue: 45),
              ],
              rounds: 3,
              restBetweenRounds: 60,
              width: 320,
              height: 640,
              brightness: brightness,
              textScaler: _scaler,
              blockName: name,
              restored: resting
                  ? preL3State(
                      round: 1,
                      exerciseIndex: 2,
                      status: 'roundResting',
                      restEndsAt: DateTime.now().add(
                        const Duration(seconds: 60),
                      ),
                      performances: logged,
                    )
                  : preL3State(
                      round: 2,
                      exerciseIndex: 1,
                      performances: logged,
                    ),
            );
            expect(tester.takeException(), isNull);
            await _scrollAll(tester);
          });
        }
      }
    }
  });

  group('Recap detalle with extreme free text', () {
    tearDown(() async => sl.reset());
    for (final brightness in _themes) {
      for (final kind in _kinds) {
        testWidgets(_label(brightness, kind), (tester) async {
          final text = _name(kind);
          await pumpDetail(
            tester,
            extra: {
              ...recapDetailFilled,
              'published_changes': text,
              'training_notes': text,
              'nutrition_notes': text,
              'improvement_feedback_text': text,
              'client_feedback_text': text,
              'published_coach_summary': text,
            },
            dark: brightness == Brightness.dark,
            width: 320,
            textScaler: _scaler,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Dietas y detalle de comida with extreme names', () {
    for (final brightness in _themes) {
      for (final kind in _kinds) {
        testWidgets('Nutrición, ${_label(brightness, kind)}', (tester) async {
          await pumpDietsScene(
            tester,
            diet: _diet(_name(kind)),
            brightness: brightness,
            width: 320,
            height: 640,
            textScale: 1.3,
          );
          expect(tester.takeException(), isNull);
          await _scrollAll(tester, steps: 8);
        });
        testWidgets('Detalle de comida, ${_label(brightness, kind)}', (
          tester,
        ) async {
          await pumpMealSheetScene(
            tester,
            diet: _diet(_name(kind)),
            brightness: brightness,
            width: 320,
            height: 640,
            textScale: 1.3,
          );
          expect(tester.takeException(), isNull);
          await _scrollAll(tester, steps: 8);
        });
      }
    }
  });

  group('Retos with extreme names', () {
    for (final brightness in _themes) {
      for (final kind in _kinds) {
        testWidgets(_label(brightness, kind), (tester) async {
          final text = _name(kind);
          final achievements = [
            AchievementEntity(id: 'a1', name: text, description: text),
            AchievementEntity(id: 'a2', name: _word, description: _word),
          ];
          final repository = FakeChallengesRepository(
            challenges: [
              challengeFixture(
                'goal',
                title: text,
                description: text,
                type: 'MAIN_GOAL',
                current: 34,
                target: 50,
                unit: _word,
                deadline: DateTime(2026, 11, 30),
              ),
              challengeFixture(
                'w1',
                title: text,
                description: text,
                type: 'WEEKLY',
                current: 3,
                target: 4,
                unit: text,
              ),
              challengeFixture(
                'w2',
                title: _word,
                type: 'WEEKLY',
                current: 1,
                target: 1,
                unit: 'pesaje',
                completed: true,
              ),
            ],
            achievements: achievements,
            catalog: [
              ...achievements,
              AchievementEntity(id: 'a3', name: text, description: text),
            ],
          );
          await pumpChallengesPage(
            tester,
            repository,
            width: 320,
            height: 6000,
            mode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            textScaler: _scaler,
          );
          expect(tester.takeException(), isNull);
          await openAchievementsBoard(tester, 'Ver todos');
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
