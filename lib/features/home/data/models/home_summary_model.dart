class HomeSummaryModel {
  final String? trainingName;
  final String? trainingType;
  final int? trainingDurationMin;
  final bool trainingCompleted;
  final String? trainingId;
  final String? dietName;
  final String? dietId;
  final int? totalCalories;
  final bool isRestDay;
  final int streakDays;
  final String? clientName;
  final String? avatarUrl;

  const HomeSummaryModel({
    this.trainingName,
    this.trainingType,
    this.trainingDurationMin,
    this.trainingCompleted = false,
    this.trainingId,
    this.dietName,
    this.dietId,
    this.totalCalories,
    this.isRestDay = false,
    this.streakDays = 0,
    this.clientName,
    this.avatarUrl,
  });

  factory HomeSummaryModel.fromParts({
    required Map<String, dynamic>? training,
    required Map<String, dynamic>? diet,
    required Map<String, dynamic>? streak,
  }) {
    return HomeSummaryModel(
      trainingId: training?['id'] as String?,
      trainingName: training?['name'] as String?,
      trainingType: training?['type'] as String?,
      trainingDurationMin: training?['estimated_duration_min'] as int?,
      trainingCompleted: training?['completed'] as bool? ?? false,
      dietId: diet?['id'] as String?,
      dietName: diet?['name'] as String?,
      totalCalories: diet?['total_calories'] as int?,
      isRestDay: training == null,
      streakDays: streak?['current_days'] as int? ?? 0,
      clientName: null,
      avatarUrl: null,
    );
  }
}
