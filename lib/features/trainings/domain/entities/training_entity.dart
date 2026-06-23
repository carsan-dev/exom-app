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

class SetPerformance {
  final int setNumber;
  final int? reps;
  final int? seconds;
  final double? weightKg;

  const SetPerformance({
    required this.setNumber,
    this.reps,
    this.seconds,
    this.weightKg,
  });

  Map<String, dynamic> toJson() => {
    'set_number': setNumber,
    if (reps != null) 'reps': reps,
    if (seconds != null) 'seconds': seconds,
    if (weightKg != null) 'weight_kg': weightKg,
  };
}

class TrainingExerciseEntity {
  final String id;
  final int order;
  final int sets;
  final String repsOrDuration;
  final int restSeconds;
  final bool requestSetTracking;
  final String? blockId;
  final int? positionInBlock;
  final String? blockName;
  final int? blockOrder;
  final int? blockRounds;
  final int? restBetweenRoundsSeconds;
  final ExerciseEntity exercise;

  const TrainingExerciseEntity({
    required this.id,
    required this.order,
    required this.sets,
    required this.repsOrDuration,
    required this.restSeconds,
    this.requestSetTracking = false,
    this.blockId,
    this.positionInBlock,
    this.blockName,
    this.blockOrder,
    this.blockRounds,
    this.restBetweenRoundsSeconds,
    required this.exercise,
  });
}

class TrainingHistoryEntity {
  final String id;
  final String name;
  final List<String> types;
  final String? accentColor;
  final String level;
  final int? estimatedDurationMin;
  final int? estimatedCalories;
  final DateTime date;
  final bool isCompleted;

  const TrainingHistoryEntity({
    required this.id,
    required this.name,
    required this.types,
    this.accentColor,
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
  final List<String> types;
  final String? accentColor;
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
    required this.types,
    this.accentColor,
    required this.level,
    this.estimatedDurationMin,
    this.estimatedCalories,
    this.warmupDescription,
    this.cooldownDescription,
    required this.tags,
    required this.exercises,
  });
}
