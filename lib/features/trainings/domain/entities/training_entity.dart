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

enum ExerciseMeasureType { reps, seconds }

class SetPerformance {
  final int setNumber;
  final int? reps;
  final int? seconds;
  final double? weightKg;
  final int? rir;

  const SetPerformance({
    required this.setNumber,
    this.reps,
    this.seconds,
    this.weightKg,
    this.rir,
  });

  factory SetPerformance.fromJson(Map<String, dynamic> json) {
    return SetPerformance(
      setNumber: (json['set_number'] as num).toInt(),
      reps: (json['reps'] as num?)?.toInt(),
      seconds: (json['seconds'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      rir: (json['rir'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'set_number': setNumber,
    if (reps != null) 'reps': reps,
    if (seconds != null) 'seconds': seconds,
    if (weightKg != null) 'weight_kg': weightKg,
    if (rir != null) 'rir': rir,
  };
}

typedef CompletedExerciseProgress = ({
  Set<String> ids,
  Map<String, double> weights,
  Map<String, List<SetPerformance>> performances,
});

class TrainingDayProgress {
  final Set<String> ids;
  final Map<String, double> weights;
  final Map<String, List<SetPerformance>> performances;
  final String? note;
  final String? adminReplyText;
  final DateTime? adminReplySentAt;

  const TrainingDayProgress({
    this.ids = const {},
    this.weights = const {},
    this.performances = const {},
    this.note,
    this.adminReplyText,
    this.adminReplySentAt,
  });
}

class TrainingExerciseEntity {
  final String id;
  final int order;
  final int sets;
  final String repsOrDuration;
  final ExerciseMeasureType? measureType;
  final int? targetValue;
  final int? targetRir;
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
    this.measureType,
    this.targetValue,
    this.targetRir,
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
  final String? assignmentTrainingId;
  final String? assignmentDate;
  final bool requiresLastSetVideo;

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
    this.assignmentTrainingId,
    this.assignmentDate,
    this.requiresLastSetVideo = false,
  });
}

class RemainingTrainingProgress {
  final int remainingExercises;
  final int remainingSets;
  final int? remainingDurationMin;

  const RemainingTrainingProgress({
    required this.remainingExercises,
    required this.remainingSets,
    this.remainingDurationMin,
  });
}

extension RemainingTrainingProgressCalculation on TrainingEntity {
  RemainingTrainingProgress remainingProgress(Set<String> completedIds) {
    final completedExercises = exercises
        .where(
          (item) =>
              completedIds.contains(item.id) ||
              completedIds.contains(item.exercise.id),
        )
        .toList(growable: false);
    final totalSets = exercises.fold<int>(0, (sum, item) => sum + item.sets);
    final completedSets = completedExercises.fold<int>(
      0,
      (sum, item) => sum + item.sets,
    );
    final remainingSets = (totalSets - completedSets).clamp(0, totalSets);
    final duration = estimatedDurationMin;

    return RemainingTrainingProgress(
      remainingExercises: (exercises.length - completedExercises.length).clamp(
        0,
        exercises.length,
      ),
      remainingSets: remainingSets,
      remainingDurationMin: duration == null || totalSets <= 0
          ? null
          : (duration * remainingSets / totalSets).round().clamp(0, duration),
    );
  }
}
