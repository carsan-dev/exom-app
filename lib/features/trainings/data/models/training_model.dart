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

T? _readJson<T>(Map<String, dynamic> json, String snakeKey, String camelKey) {
  final value = json[snakeKey] ?? json[camelKey];
  return value is T ? value : null;
}

List<String> _readStringList(
  Map<String, dynamic> json,
  String snakeKey,
  String camelKey,
) {
  final value = json[snakeKey] ?? json[camelKey];
  return switch (value) {
    List<dynamic> items => items.map((e) => e.toString()).toList(),
    _ => const <String>[],
  };
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
      muscleGroups: _readStringList(json, 'muscle_groups', 'muscleGroups'),
      videoUrl: _readJson<String>(json, 'video_url', 'videoUrl'),
      thumbnailUrl: _readJson<String>(json, 'thumbnail_url', 'thumbnailUrl'),
      techniqueText: _readJson<String>(json, 'technique_text', 'techniqueText'),
      commonErrorsText: _readJson<String>(
        json,
        'common_errors_text',
        'commonErrorsText',
      ),
      explanationText: _readJson<String>(
        json,
        'explanation_text',
        'explanationText',
      ),
    );
  }
}

class TrainingExerciseModel {
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
  final ExerciseModel exercise;

  const TrainingExerciseModel({
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

  factory TrainingExerciseModel.fromJson(Map<String, dynamic> json) {
    final block = json['block'] as Map<String, dynamic>?;
    return TrainingExerciseModel(
      id: json['id'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      sets: json['sets'] as int? ?? 0,
      repsOrDuration:
          _readJson<String>(json, 'reps_or_duration', 'repsOrDuration') ?? '',
      restSeconds: _readJson<int>(json, 'rest_seconds', 'restSeconds') ?? 60,
      requestSetTracking:
          _readJson<bool>(json, 'request_set_tracking', 'requestSetTracking') ??
          false,
      blockId: _readJson<String>(json, 'block_id', 'blockId'),
      positionInBlock: _readJson<int>(
        json,
        'position_in_block',
        'positionInBlock',
      ),
      blockName: block?['name'] as String?,
      blockOrder: block?['order'] as int?,
      blockRounds: block?['rounds'] as int?,
      restBetweenRoundsSeconds: _readJson<int>(
        block ?? const <String, dynamic>{},
        'rest_between_rounds_seconds',
        'restBetweenRoundsSeconds',
      ),
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
  final String? assignmentTrainingId;
  final String? assignmentDate;
  final bool requiresLastSetVideo;

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
    this.assignmentTrainingId,
    this.assignmentDate,
    this.requiresLastSetVideo = false,
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
      assignmentTrainingId: json['assignment_training_id'] as String?,
      assignmentDate: json['assignment_date'] as String?,
      requiresLastSetVideo: json['requires_last_set_video'] as bool? ?? false,
    );
  }
}
