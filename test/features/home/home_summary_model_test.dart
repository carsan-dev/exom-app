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
}
