import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/home/data/models/home_summary_model.dart';

void main() {
  test('estimates remaining training minutes weighted by sets', () {
    final summary = HomeSummaryModel.fromParts(
      training: {
        'estimated_duration_min': 60,
        'exercises': [
          {
            'id': 'training-exercise-1',
            'sets': 2,
            'exercise': {'id': 'exercise-1'},
          },
          {
            'id': 'training-exercise-2',
            'sets': 4,
            'exercise': {'id': 'exercise-2'},
          },
        ],
      },
      diet: null,
      streak: null,
      profile: null,
      latestMetric: null,
      progress: {
        'exercises_completed': [
          {'exercise_id': 'exercise-1'},
        ],
      },
    );

    expect(summary.remainingTrainingDurationMin, 40);
  });

  test('calculates remaining calories from completed meal variant', () {
    final summary = HomeSummaryModel.fromParts(
      training: null,
      diet: {
        'total_calories': 2000,
        'meals': [
          {
            'id': 'breakfast',
            'name': 'Breakfast',
            'calories': 400,
            'variants': [
              {'id': 'breakfast-variant', 'calories': 550},
            ],
          },
          {'id': 'lunch', 'name': 'Lunch', 'calories': 700},
        ],
      },
      streak: null,
      profile: null,
      latestMetric: null,
      progress: {
        'meals_completed': ['breakfast-variant'],
      },
    );

    expect(summary.remainingCalories, 1450);
    expect(summary.nextMealId, 'lunch');
    expect(summary.isRestDay, isFalse);
  });

  test('keeps total when completed meal has no calories', () {
    final summary = HomeSummaryModel.fromParts(
      training: null,
      diet: {
        'total_calories': 2000,
        'meals': [
          {'id': 'breakfast', 'name': 'Breakfast'},
        ],
      },
      streak: null,
      profile: null,
      latestMetric: null,
      progress: {
        'meals_completed': ['breakfast'],
      },
    );

    expect(summary.remainingCalories, 2000);
  });

  test('counts all current trainings and ignores replaced-plan history', () {
    final summary = HomeSummaryModel.fromParts(
      training: {
        'trainings': [
          {
            'id': 'training-new-1',
            'name': 'Nuevo 1',
            'exercises': [
              {
                'id': 'training-exercise-new-1',
                'exercise': {'id': 'exercise-new-1'},
              },
              {
                'id': 'training-exercise-new-2',
                'exercise': {'id': 'exercise-new-2'},
              },
            ],
          },
          {
            'id': 'training-new-2',
            'name': 'Nuevo 2',
            'exercises': [
              {
                'id': 'training-exercise-new-3',
                'exercise': {'id': 'exercise-new-3'},
              },
              {
                'id': 'training-exercise-new-4',
                'exercise': {'id': 'exercise-new-4'},
              },
            ],
          },
        ],
      },
      diet: null,
      streak: null,
      profile: null,
      latestMetric: null,
      progress: {
        'training_completed': true,
        'trainings_completed': ['training-old-1', 'training-old-2'],
        'exercises_completed': List.generate(
          18,
          (index) => {
            'training_exercise_id': 'training-exercise-old-$index',
            'exercise_id': 'exercise-old-$index',
          },
        ),
      },
    );

    expect(summary.totalExercises, 4);
    expect(summary.exercisesCompleted, 0);
    expect(summary.trainingCompleted, isFalse);
    expect(summary.trainings.map((training) => training.completed), [
      false,
      false,
    ]);
  });

  test('counts completed occurrences across every current training', () {
    final summary = HomeSummaryModel.fromParts(
      training: {
        'trainings': [
          {
            'id': 'training-1',
            'exercises': [
              {
                'id': 'training-exercise-1',
                'exercise': {'id': 'exercise-shared'},
              },
              {
                'id': 'training-exercise-2',
                'exercise': {'id': 'exercise-2'},
              },
            ],
          },
          {
            'id': 'training-2',
            'exercises': [
              {
                'id': 'training-exercise-3',
                'exercise': {'id': 'exercise-shared'},
              },
            ],
          },
        ],
      },
      diet: null,
      streak: null,
      profile: null,
      latestMetric: null,
      progress: {
        'exercises_completed': [
          {
            'training_exercise_id': 'training-exercise-1',
            'exercise_id': 'exercise-shared',
          },
          {
            'training_exercise_id': 'training-exercise-3',
            'exercise_id': 'exercise-shared',
          },
        ],
      },
    );

    expect(summary.totalExercises, 3);
    expect(summary.exercisesCompleted, 2);
    expect(summary.trainings.map((training) => training.completed), [
      false,
      true,
    ]);
    expect(summary.trainingCompleted, isFalse);
  });

  test('ignores completed meals from a replaced diet', () {
    final summary = HomeSummaryModel.fromParts(
      training: null,
      diet: {
        'meals': [
          {'id': 'new-breakfast'},
          {'id': 'new-lunch'},
        ],
      },
      streak: null,
      profile: null,
      latestMetric: null,
      progress: {
        'meals_completed': ['old-breakfast', 'old-lunch'],
      },
    );

    expect(summary.totalMeals, 2);
    expect(summary.mealsCompleted, 0);
  });
}
