Map<String, dynamic> overlayPendingProgressActions({
  required Map<String, dynamic> progress,
  required Iterable<Map<String, dynamic>> actions,
  required String date,
}) {
  final result = Map<String, dynamic>.from(progress);
  final exercises = (progress['exercises_completed'] as List? ?? const [])
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList(growable: true);
  final meals = (progress['meals_completed'] as List? ?? const [])
      .map((entry) => entry.toString())
      .toSet();
  final trainings = (progress['trainings_completed'] as List? ?? const [])
      .map((entry) => entry.toString())
      .toSet();

  for (final action in actions) {
    if (action['date'] != date) continue;

    switch (action['type']) {
      case 'mark_exercise_completed':
        final trainingExerciseId = action['training_exercise_id'] as String?;
        final exerciseId = action['exercise_id'] as String?;
        if (trainingExerciseId == null && exerciseId == null) continue;

        final existingIndex = exercises.indexWhere(
          (entry) =>
              (trainingExerciseId != null &&
                  entry['training_exercise_id'] == trainingExerciseId) ||
              (entry['training_exercise_id'] == null &&
                  exerciseId != null &&
                  entry['exercise_id'] == exerciseId),
        );
        final existing = existingIndex < 0
            ? <String, dynamic>{}
            : exercises.removeAt(existingIndex);
        exercises.add({
          ...existing,
          'training_exercise_id': ?trainingExerciseId,
          'exercise_id': ?exerciseId,
          if (action['weight_used'] != null)
            'weight_used': action['weight_used'],
          if (action['sets'] != null) 'sets': action['sets'],
          'completed_at':
              existing['completed_at'] ??
              action['queued_at'] ??
              DateTime.now().toUtc().toIso8601String(),
        });
      case 'unmark_exercise_completed':
        final id =
            action['training_exercise_id'] as String? ??
            action['exercise_id'] as String?;
        if (id == null) continue;
        exercises.removeWhere(
          (entry) =>
              entry['training_exercise_id'] == id || entry['exercise_id'] == id,
        );
      case 'complete_training':
        final trainingId = action['training_id'] as String?;
        if (trainingId != null) trainings.add(trainingId);
      case 'mark_meal_completed':
        final mealId = action['meal_id'] as String?;
        if (mealId != null) meals.add(mealId);
      case 'unmark_meal_completed':
        final mealId = action['meal_id'] as String?;
        if (mealId != null) meals.remove(mealId);
    }
  }

  result['exercises_completed'] = exercises;
  result['meals_completed'] = meals.toList(growable: false);
  result['trainings_completed'] = trainings.toList(growable: false);
  return result;
}
