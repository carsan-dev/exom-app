import 'package:exom_app/core/services/pending_progress_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const date = '2026-09-03';

  test(
    'canonical pending action does not claim an unattributed historical entry',
    () {
      final legacy = {
        'exercise_id': 'e',
        'weight_used': 40,
        'completed_at': 'old',
      };
      final merged = overlayPendingProgressActions(
        progress: {
          'exercises_completed': [legacy],
        },
        actions: [
          {
            'type': 'mark_exercise_completed',
            'date': date,
            'training_exercise_id': 'te',
            'exercise_id': 'e',
            'weight_used': 50,
          },
        ],
        date: date,
      );
      expect(merged['exercises_completed'], [
        legacy,
        containsPair('training_exercise_id', 'te'),
      ]);
      expect(legacy.containsKey('training_exercise_id'), false);
    },
  );

  test('pending edit cannot choose one of two historical records', () {
    final entries = [20, 30]
        .map(
          (weight) => {
            'training_exercise_id': 'te',
            'exercise_id': 'e',
            'weight_used': weight,
          },
        )
        .toList();
    final merged = overlayPendingProgressActions(
      progress: {'exercises_completed': entries},
      actions: [
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'te',
          'exercise_id': 'e',
          'weight_used': 50,
        },
      ],
      date: date,
    );
    expect(merged['exercises_completed'], entries);
  });

  test('keeps same-day pending executions separate by session and set', () {
    final merged = overlayPendingProgressActions(
      progress: {'exercises_completed': <Map<String, dynamic>>[]},
      actions: const [
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'te',
          'exercise_id': 'e',
          'training_session_id': 'session-a',
          'sets': [
            {'set_number': 1, 'reps': 8},
          ],
        },
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'te',
          'exercise_id': 'e',
          'training_session_id': 'session-b',
          'sets': [
            {'set_number': 1, 'reps': 12},
          ],
        },
      ],
      date: date,
    );

    final entries = (merged['exercises_completed'] as List)
        .cast<Map<String, dynamic>>();
    expect(entries, hasLength(2));
    expect(entries.map((entry) => entry['training_session_id']), [
      'session-a',
      'session-b',
    ]);
    expect((entries[0]['sets'] as List).single['reps'], 8);
    expect((entries[1]['sets'] as List).single['reps'], 12);
  });

  test('unmarking session B preserves the pending session A entry', () {
    final merged = overlayPendingProgressActions(
      progress: {'exercises_completed': <Map<String, dynamic>>[]},
      actions: const [
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'te',
          'exercise_id': 'e',
          'training_session_id': 'session-a',
          'sets': [
            {'set_number': 1, 'reps': 8},
          ],
        },
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'te',
          'exercise_id': 'e',
          'training_session_id': 'session-b',
          'sets': [
            {'set_number': 1, 'reps': 12},
          ],
        },
        {
          'type': 'unmark_exercise_completed',
          'date': date,
          'training_exercise_id': 'te',
          'training_session_id': 'session-b',
        },
      ],
      date: date,
    );

    final entries = (merged['exercises_completed'] as List)
        .cast<Map<String, dynamic>>();
    expect(entries, hasLength(1));
    expect(entries.single['training_session_id'], 'session-a');
    expect((entries.single['sets'] as List).single['reps'], 8);
  });

  test('sessionless legacy remains unattributed beside pending session', () {
    const legacy = {
      'training_exercise_id': 'te',
      'exercise_id': 'e',
      'sets': [
        {'set_number': 1, 'reps': 6},
      ],
    };
    final merged = overlayPendingProgressActions(
      progress: {
        'exercises_completed': [legacy],
      },
      actions: const [
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'te',
          'exercise_id': 'e',
          'training_session_id': 'session-a',
          'sets': [
            {'set_number': 1, 'reps': 8},
          ],
        },
      ],
      date: date,
    );

    final entries = (merged['exercises_completed'] as List)
        .cast<Map<String, dynamic>>();
    expect(entries, hasLength(2));
    expect(entries.first, legacy);
    expect(entries.first.containsKey('training_session_id'), false);
    expect(entries.last['training_session_id'], 'session-a');
  });

  test('keeps queued exercise completions over stale server progress', () {
    final merged = overlayPendingProgressActions(
      progress: {
        'exercises_completed': <Map<String, dynamic>>[],
        'meals_completed': <String>[],
      },
      actions: const [
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'training-exercise-1',
          'exercise_id': 'exercise-1',
          'weight_used': 22.5,
          'sets': [
            {'set_number': 1, 'reps': 10, 'weight_kg': 22.5},
          ],
          'status': 'uploading',
        },
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'training-exercise-2',
          'exercise_id': 'exercise-2',
          'status': 'queued',
        },
      ],
      date: date,
    );

    final exercises = (merged['exercises_completed'] as List)
        .cast<Map<String, dynamic>>();
    expect(exercises.map((entry) => entry['training_exercise_id']).toSet(), {
      'training-exercise-1',
      'training-exercise-2',
    });
    expect(exercises.first['weight_used'], 22.5);
    expect((exercises.first['sets'] as List).single['reps'], 10);
  });

  test('applies queued mutations in order and only for the requested date', () {
    final merged = overlayPendingProgressActions(
      progress: {
        'exercises_completed': [
          {
            'training_exercise_id': 'training-exercise-1',
            'exercise_id': 'exercise-1',
          },
        ],
        'meals_completed': ['meal-1'],
      },
      actions: const [
        {
          'type': 'unmark_exercise_completed',
          'date': date,
          'training_exercise_id': 'training-exercise-1',
        },
        {
          'type': 'mark_meal_completed',
          'date': '2026-09-04',
          'meal_id': 'meal-other-day',
        },
        {'type': 'unmark_meal_completed', 'date': date, 'meal_id': 'meal-1'},
      ],
      date: date,
    );

    expect(merged['exercises_completed'], isEmpty);
    expect(merged['meals_completed'], isEmpty);
  });

  test('pending legacy set update preserves cached RIR by set number', () {
    final merged = overlayPendingProgressActions(
      progress: {
        'exercises_completed': [
          {
            'training_exercise_id': 'training-exercise-1',
            'exercise_id': 'exercise-1',
            'sets': [
              {'set_number': 1, 'reps': 8, 'rir': 3},
              {'set_number': 2, 'reps': 7, 'rir': 4},
            ],
          },
        ],
      },
      actions: const [
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'training-exercise-1',
          'exercise_id': 'exercise-1',
          'sets': [
            {'set_number': 1, 'reps': 10, 'rir': null},
          ],
          'status': 'queued',
        },
      ],
      date: date,
    );

    final sets = (merged['exercises_completed'] as List).single['sets'] as List;
    expect(sets, [
      {'set_number': 1, 'reps': 10, 'rir': 3},
      {'set_number': 2, 'reps': 7, 'rir': 4},
    ]);
  });

  test('does not present permanently failed actions as server progress', () {
    final merged = overlayPendingProgressActions(
      progress: {
        'exercises_completed': <Map<String, dynamic>>[],
        'meals_completed': <String>[],
        'trainings_completed': <String>[],
      },
      actions: const [
        {
          'type': 'mark_exercise_completed',
          'date': date,
          'training_exercise_id': 'training-exercise-1',
          'exercise_id': 'exercise-1',
          'status': 'failed',
        },
        {
          'type': 'mark_meal_completed',
          'date': date,
          'meal_id': 'meal-1',
          'status': 'failed',
        },
        {
          'type': 'complete_training',
          'date': date,
          'training_id': 'training-1',
          'status': 'failed',
        },
      ],
      date: date,
    );

    expect(merged['exercises_completed'], isEmpty);
    expect(merged['meals_completed'], isEmpty);
    expect(merged['trainings_completed'], isEmpty);
  });
}
