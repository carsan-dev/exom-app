import 'package:exom_app/core/utils/training_type_utils.dart';

List<String> _resolveTrainingTypesFromJson(Map<String, dynamic> json) {
  final rawTypes =
      (json['types'] as List<dynamic>?)
          ?.map((item) => item.toString())
          .toList(growable: false) ??
      const <String>[];
  final legacyType = json['type'] as String?;

  return resolveTrainingTypes(types: rawTypes, legacyType: legacyType);
}

String? _resolveAccentColorFromJson(Map<String, dynamic> json) {
  final rawValue = json['accentColor'] as String?;
  return normalizeTrainingAccentHex(rawValue);
}

class ExerciseModel {
  final String id;
  final String name;
  final List<String> muscleGroups;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? techniqueText;
  final String? commonErrorsText;
  final String? explanationText;

  const ExerciseModel({
    required this.id,
    required this.name,
    required this.muscleGroups,
    this.videoUrl,
    this.thumbnailUrl,
    this.techniqueText,
    this.commonErrorsText,
    this.explanationText,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      muscleGroups:
          (json['muscle_groups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      videoUrl: json['video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      techniqueText: json['technique_text'] as String?,
      commonErrorsText: json['common_errors_text'] as String?,
      explanationText: json['explanation_text'] as String?,
    );
  }
}

class TrainingExerciseModel {
  final String id;
  final int order;
  final int sets;
  final String repsOrDuration;
  final int restSeconds;
  final String? blockId;
  final int? positionInBlock;
  final String? blockName;
  final int? blockOrder;
  final int? blockRounds;
  final int? restBetweenRoundsSeconds;
  final ExerciseModel exercise;

  const TrainingExerciseModel({
    required this.id,
    required this.order,
    required this.sets,
    required this.repsOrDuration,
    required this.restSeconds,
    this.blockId,
    this.positionInBlock,
    this.blockName,
    this.blockOrder,
    this.blockRounds,
    this.restBetweenRoundsSeconds,
    required this.exercise,
  });

  factory TrainingExerciseModel.fromJson(Map<String, dynamic> json) {
    final block = json['block'] as Map<String, dynamic>?;
    return TrainingExerciseModel(
      id: json['id'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      sets: json['sets'] as int? ?? 0,
      repsOrDuration: json['reps_or_duration'] as String? ?? '',
      restSeconds: json['rest_seconds'] as int? ?? 60,
      blockId: json['block_id'] as String?,
      positionInBlock: json['position_in_block'] as int?,
      blockName: block?['name'] as String?,
      blockOrder: block?['order'] as int?,
      blockRounds: block?['rounds'] as int?,
      restBetweenRoundsSeconds: block?['rest_between_rounds_seconds'] as int?,
      exercise: ExerciseModel.fromJson(
        (json['exercise'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}

class TrainingHistoryModel {
  final String id;
  final String name;
  final List<String> types;
  final String? accentColor;
  final String level;
  final int? estimatedDurationMin;
  final int? estimatedCalories;
  final DateTime date;
  final bool isCompleted;

  const TrainingHistoryModel({
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

  factory TrainingHistoryModel.fromAssignmentJson(
    Map<String, dynamic> json, {
    required bool isCompleted,
  }) {
    final training = (json['training'] as Map<String, dynamic>?) ?? const {};

    return TrainingHistoryModel(
      id: training['id'] as String? ?? '',
      name: training['name'] as String? ?? '',
      types: _resolveTrainingTypesFromJson(training),
      accentColor: _resolveAccentColorFromJson(training),
      level: training['level'] as String? ?? '',
      estimatedDurationMin: (training['estimated_duration_min'] as num?)
          ?.toInt(),
      estimatedCalories: (training['estimated_calories'] as num?)?.toInt(),
      date:
          DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.utc(1970),
      isCompleted: isCompleted,
    );
  }
}

class TrainingModel {
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
  final List<TrainingExerciseModel> exercises;

  const TrainingModel({
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

  factory TrainingModel.fromJson(Map<String, dynamic> json) {
    return TrainingModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      types: _resolveTrainingTypesFromJson(json),
      accentColor: _resolveAccentColorFromJson(json),
      level: json['level'] as String? ?? '',
      estimatedDurationMin: json['estimated_duration_min'] as int?,
      estimatedCalories: json['estimated_calories'] as int?,
      warmupDescription: json['warmup_description'] as String?,
      cooldownDescription: json['cooldown_description'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      exercises:
          (json['exercises'] as List<dynamic>?)
              ?.map(
                (e) =>
                    TrainingExerciseModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}
