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

  group('L4b program week and day', () {
    HomeSummaryModel parse(Map<String, dynamic>? training) =>
        HomeSummaryModel.fromParts(
          training: training,
          diet: null,
          streak: null,
          profile: null,
          latestMetric: null,
          progress: null,
        );

    test('reads both fields when present', () {
      final summary = parse({'id': 't', 'program_week': 3, 'program_day': 2});
      expect(summary.programWeek, 3);
      expect(summary.programDay, 2);
    });

    test('reads them from a multi-training payload', () {
      final summary = parse({
        'program_week': 4,
        'program_day': 1,
        'trainings': [
          {'id': 't1', 'name': 'A'},
        ],
      });
      expect(summary.programWeek, 4);
      expect(summary.programDay, 1);
    });

    test('integral doubles are accepted', () {
      final summary = parse({'id': 't', 'program_week': 3.0});
      expect(summary.programWeek, 3);
      expect(summary.programDay, isNull);
    });

    test('absent (older API) means no week', () {
      final summary = parse({'id': 't'});
      expect(summary.programWeek, isNull);
      expect(summary.programDay, isNull);
    });

    test('null means no week', () {
      final summary = parse({
        'id': 't',
        'program_week': null,
        'program_day': null,
      });
      expect(summary.programWeek, isNull);
      expect(summary.programDay, isNull);
    });

    test('wrong types and out-of-range values mean no week, without '
        'throwing', () {
      for (final raw in <Object>[
        '3',
        true,
        2.5,
        0,
        -1,
        const <int>[3],
      ]) {
        final summary = parse({
          'id': 't',
          'program_week': raw,
          'program_day': raw,
        });
        expect(summary.programWeek, isNull, reason: '$raw');
        expect(summary.programDay, isNull, reason: '$raw');
        expect(summary.trainingId, 't');
      }
    });

    test('no training means no week', () {
      expect(parse(null).programWeek, isNull);
    });
  });

  group('L4b total sets (shared rule, L4b-D5)', () {
    test('standalone sets plus circuit sets x rounds across the day', () {
      final summary = HomeSummaryModel.fromParts(
        training: {
          'trainings': [
            {
              'id': 't1',
              'exercises': [
                {'id': 'te1', 'sets': 4},
                {
                  'id': 'te2',
                  'sets': 1,
                  'block_id': 'b1',
                  'block': {'rounds': 3},
                },
                {
                  'id': 'te3',
                  'sets': 1,
                  'block_id': 'b1',
                  'block': {'rounds': 3},
                },
              ],
            },
            {
              'id': 't2',
              'exercises': [
                // Circuit without rounds in the payload: API default 3.
                {'id': 'te4', 'sets': 1, 'blockId': 'b2'},
              ],
            },
          ],
        },
        diet: null,
        streak: null,
        profile: null,
        latestMetric: null,
        progress: null,
      );
      expect(summary.totalSets, 4 + 3 + 3 + 3);
    });

    test('no exercises means zero sets', () {
      final summary = HomeSummaryModel.fromParts(
        training: {'id': 't', 'exercises': const []},
        diet: null,
        streak: null,
        profile: null,
        latestMetric: null,
        progress: null,
      );
      expect(summary.totalSets, 0);
    });

    // Contract change L4b-D5: remaining minutes weigh a circuit exercise by
    // sets x rounds. Before, the circuit exercise below weighed 1 set and the
    // result was 60 * 4 / 5 = 48 min.
    test('remaining minutes weigh a completed circuit exercise by rounds', () {
      final summary = HomeSummaryModel.fromParts(
        training: {
          'id': 't',
          'estimated_duration_min': 60,
          'exercises': [
            {
              'id': 'te1',
              'sets': 4,
              'exercise': {'id': 'e1'},
            },
            {
              'id': 'te2',
              'sets': 1,
              'block_id': 'b1',
              'block': {'rounds': 4},
              'exercise': {'id': 'e2'},
            },
          ],
        },
        diet: null,
        streak: null,
        profile: null,
        latestMetric: null,
        progress: {
          'exercises_completed': [
            {'training_exercise_id': 'te2', 'exercise_id': 'e2'},
          ],
        },
      );
      expect(summary.totalSets, 8);
      expect(summary.remainingTrainingDurationMin, 30);
    });
  });

  group('L4b session photo', () {
    test('first exercise, by order, with a thumbnail of each training', () {
      final summary = HomeSummaryModel.fromParts(
        training: {
          'trainings': [
            {
              'id': 't1',
              'exercises': [
                {
                  'id': 'te2',
                  'order': 2,
                  'exercise': {'thumbnail_url': 'https://cdn/b.jpg'},
                },
                {
                  'id': 'te0',
                  'order': 0,
                  'exercise': {'thumbnail_url': '  '},
                },
                {
                  'id': 'te1',
                  'order': 1,
                  'exercise': {'thumbnail_url': 'https://cdn/a.jpg'},
                },
              ],
            },
            {
              'id': 't2',
              'exercises': [
                {
                  'id': 'te3',
                  'exercise': {'thumbnail_url': null},
                },
              ],
            },
          ],
        },
        diet: null,
        streak: null,
        profile: null,
        latestMetric: null,
        progress: null,
      );
      expect(summary.trainings.first.thumbnailUrl, 'https://cdn/a.jpg');
      expect(summary.trainings.last.thumbnailUrl, isNull);
      expect(summary.trainingThumbnailUrl, 'https://cdn/a.jpg');
    });

    test('a non-string thumbnail is ignored without throwing', () {
      final summary = HomeSummaryModel.fromParts(
        training: {
          'id': 't',
          'exercises': [
            {
              'id': 'te1',
              'exercise': {'thumbnail_url': 42},
            },
          ],
        },
        diet: null,
        streak: null,
        profile: null,
        latestMetric: null,
        progress: null,
      );
      expect(summary.trainingThumbnailUrl, isNull);
    });

    String? thumbnailOf(String url) => HomeSummaryModel.fromParts(
      training: {
        'id': 't',
        'exercises': [
          {
            'id': 'te1',
            'exercise': {'thumbnail_url': url},
          },
        ],
      },
      diet: null,
      streak: null,
      profile: null,
      latestMetric: null,
      progress: null,
    ).trainingThumbnailUrl;

    test('only an http(s) URL with a host is accepted', () {
      for (final invalid in [
        'foo',
        '   ',
        'file:///x.png',
        'ftp://a/b.png',
        'https:///sin-host',
      ]) {
        expect(thumbnailOf(invalid), isNull, reason: invalid);
      }
      expect(thumbnailOf('https://h/x.png'), 'https://h/x.png');
      expect(
        thumbnailOf('http://10.0.2.2:8787/a.png'),
        'http://10.0.2.2:8787/a.png',
      );
    });
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
