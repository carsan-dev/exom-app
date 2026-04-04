class RecapEntity {
  final String id;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final String status; // DRAFT, SUBMITTED, REVIEWED

  // Training
  final int? trainingEffort;
  final int? trainingSessions;
  final String? trainingProgress;
  final String? trainingNotes;

  // Nutrition
  final String? nutritionQuality;
  final bool hydrationEnabled;
  final String? hydrationLevel;
  final int? foodQuality;
  final String? nutritionNotes;

  // Recovery
  final String? sleepHoursRange;
  final String? fatigueLevel;
  final List<String> musclePainZones;
  final String? painIntensity;
  final String? recoveryNotes;

  // General
  final String? mood;
  final bool stressEnabled;
  final int? stressLevel;
  final String? generalNotes;

  // Improvement
  final int? improvementAppRating;
  final int? improvementServiceRating;
  final List<String> improvementAreas;
  final String? improvementFeedbackText;

  // Admin feedback (visible to client)
  final String? clientFeedbackText;
  final DateTime? clientFeedbackSentAt;
  final DateTime? clientFeedbackReadAt;

  // Dates
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const RecapEntity({
    required this.id,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.status,
    this.trainingEffort,
    this.trainingSessions,
    this.trainingProgress,
    this.trainingNotes,
    this.nutritionQuality,
    this.hydrationEnabled = false,
    this.hydrationLevel,
    this.foodQuality,
    this.nutritionNotes,
    this.sleepHoursRange,
    this.fatigueLevel,
    this.musclePainZones = const [],
    this.painIntensity,
    this.recoveryNotes,
    this.mood,
    this.stressEnabled = false,
    this.stressLevel,
    this.generalNotes,
    this.improvementAppRating,
    this.improvementServiceRating,
    this.improvementAreas = const [],
    this.improvementFeedbackText,
    this.clientFeedbackText,
    this.clientFeedbackSentAt,
    this.clientFeedbackReadAt,
    this.reviewedAt,
    required this.createdAt,
  });

  bool get isDraft => status == 'DRAFT';
  bool get isSubmitted => status == 'SUBMITTED';
  bool get isReviewed => status == 'REVIEWED';

  bool get hasClientFeedback =>
      clientFeedbackText != null && clientFeedbackText!.trim().isNotEmpty;

  bool get hasUnreadClientFeedback =>
      hasClientFeedback && clientFeedbackReadAt == null;

  RecapEntity copyWith({DateTime? clientFeedbackReadAt}) {
    return RecapEntity(
      id: id,
      weekStartDate: weekStartDate,
      weekEndDate: weekEndDate,
      status: status,
      trainingEffort: trainingEffort,
      trainingSessions: trainingSessions,
      trainingProgress: trainingProgress,
      trainingNotes: trainingNotes,
      nutritionQuality: nutritionQuality,
      hydrationEnabled: hydrationEnabled,
      hydrationLevel: hydrationLevel,
      foodQuality: foodQuality,
      nutritionNotes: nutritionNotes,
      sleepHoursRange: sleepHoursRange,
      fatigueLevel: fatigueLevel,
      musclePainZones: musclePainZones,
      painIntensity: painIntensity,
      recoveryNotes: recoveryNotes,
      mood: mood,
      stressEnabled: stressEnabled,
      stressLevel: stressLevel,
      generalNotes: generalNotes,
      improvementAppRating: improvementAppRating,
      improvementServiceRating: improvementServiceRating,
      improvementAreas: improvementAreas,
      improvementFeedbackText: improvementFeedbackText,
      clientFeedbackText: clientFeedbackText,
      clientFeedbackSentAt: clientFeedbackSentAt,
      clientFeedbackReadAt: clientFeedbackReadAt ?? this.clientFeedbackReadAt,
      reviewedAt: reviewedAt,
      createdAt: createdAt,
    );
  }
}
