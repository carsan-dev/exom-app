import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';

class RecapModel extends RecapEntity {
  const RecapModel({
    required super.id,
    required super.weekStartDate,
    required super.weekEndDate,
    required super.status,
    super.trainingEffort,
    super.trainingSessions,
    super.trainingProgress,
    super.trainingNotes,
    super.nutritionQuality,
    super.hydrationEnabled,
    super.hydrationLevel,
    super.foodQuality,
    super.nutritionNotes,
    super.sleepHoursRange,
    super.fatigueLevel,
    super.musclePainZones,
    super.painIntensity,
    super.recoveryNotes,
    super.mood,
    super.stressEnabled,
    super.stressLevel,
    super.generalNotes,
    super.improvementAppRating,
    super.improvementServiceRating,
    super.improvementAreas,
    super.improvementFeedbackText,
    super.clientFeedbackText,
    super.clientFeedbackSentAt,
    super.clientFeedbackReadAt,
    super.reviewedAt,
    required super.createdAt,
  });

  factory RecapModel.fromJson(Map<String, dynamic> json) {
    return RecapModel(
      id: json['id'] as String,
      weekStartDate: DateTime.parse(json['week_start_date'] as String),
      weekEndDate: DateTime.parse(json['week_end_date'] as String),
      status: json['status'] as String? ?? 'DRAFT',
      trainingEffort: json['training_effort'] as int?,
      trainingSessions: json['training_sessions'] as int?,
      trainingProgress: json['training_progress'] as String?,
      trainingNotes: json['training_notes'] as String?,
      nutritionQuality: json['nutrition_quality'] as String?,
      hydrationEnabled: json['hydration_enabled'] as bool? ?? false,
      hydrationLevel: json['hydration_level'] as String?,
      foodQuality: json['food_quality'] as int?,
      nutritionNotes: json['nutrition_notes'] as String?,
      sleepHoursRange: json['sleep_hours_range'] as String?,
      fatigueLevel: json['fatigue_level'] as String?,
      musclePainZones:
          (json['muscle_pain_zones'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      painIntensity: json['pain_intensity'] as String?,
      recoveryNotes: json['recovery_notes'] as String?,
      mood: json['mood'] as String?,
      stressEnabled: json['stress_enabled'] as bool? ?? false,
      stressLevel: json['stress_level'] as int?,
      generalNotes: json['general_notes'] as String?,
      improvementAppRating: json['improvement_app_rating'] as int?,
      improvementServiceRating: json['improvement_service_rating'] as int?,
      improvementAreas:
          (json['improvement_areas'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      improvementFeedbackText: json['improvement_feedback_text'] as String?,
      clientFeedbackText: json['client_feedback_text'] as String?,
      clientFeedbackSentAt: json['client_feedback_sent_at'] != null
          ? DateTime.parse(json['client_feedback_sent_at'] as String)
          : null,
      clientFeedbackReadAt: json['client_feedback_read_at'] != null
          ? DateTime.parse(json['client_feedback_read_at'] as String)
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static Map<String, dynamic> toCreateJson(Map<String, dynamic> formData) {
    final payload = Map<String, dynamic>.from(formData);

    payload.removeWhere(
      (key, value) =>
          value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List &&
              value.isEmpty &&
              key != 'muscle_pain_zones' &&
              key != 'improvement_areas'),
    );

    payload['muscle_pain_zones'] = List<String>.from(
      (payload['muscle_pain_zones'] as List<dynamic>?) ?? const <String>[],
    );
    payload['improvement_areas'] = List<String>.from(
      (payload['improvement_areas'] as List<dynamic>?) ?? const <String>[],
    );

    if (payload['hydration_enabled'] != true) {
      payload.remove('hydration_level');
    }

    if (payload['stress_enabled'] != true) {
      payload.remove('stress_level');
    }

    return payload;
  }
}
