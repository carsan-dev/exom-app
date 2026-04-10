class ExerciseEntity {
  final String id;
  final String name;
  final List<String> muscleGroups;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? techniqueText;
  final String? commonErrorsText;
  final String? explanationText;

  const ExerciseEntity({
    required this.id,
    required this.name,
    required this.muscleGroups,
    this.videoUrl,
    this.thumbnailUrl,
    this.techniqueText,
    this.commonErrorsText,
    this.explanationText,
  });
}

class TrainingExerciseEntity {
  final String id;
  final int order;
  final int sets;
  final String repsOrDuration;
  final int restSeconds;
  final ExerciseEntity exercise;

  const TrainingExerciseEntity({
    required this.id,
    required this.order,
    required this.sets,
    required this.repsOrDuration,
    required this.restSeconds,
    required this.exercise,
  });
}

class TrainingHistoryEntity {
  final String id;
  final String name;
  final String type;
  final String level;
  final int? estimatedDurationMin;
  final int? estimatedCalories;
  final DateTime date;
  final bool isCompleted;

  const TrainingHistoryEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.level,
    this.estimatedDurationMin,
    this.estimatedCalories,
    required this.date,
    required this.isCompleted,
  });
}

class TrainingEntity {
  final String id;
  final String name;
  final String type;
  final String level;
  final int? estimatedDurationMin;
  final int? estimatedCalories;
  final String? warmupDescription;
  final String? cooldownDescription;
  final List<String> tags;
  final List<TrainingExerciseEntity> exercises;

  const TrainingEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.level,
    this.estimatedDurationMin,
    this.estimatedCalories,
    this.warmupDescription,
    this.cooldownDescription,
    required this.tags,
    required this.exercises,
  });
}
