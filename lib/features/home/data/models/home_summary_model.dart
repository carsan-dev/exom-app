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
  final double? lastWeightKg;
  final DateTime? lastWeightDate;
  final double? lastSleepHours;

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
    this.lastWeightKg,
    this.lastWeightDate,
    this.lastSleepHours,
  });

  factory HomeSummaryModel.fromParts({
    required Map<String, dynamic>? training,
    required Map<String, dynamic>? diet,
    required Map<String, dynamic>? streak,
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? latestMetric,
  }) {
    final firstName = profile?['first_name'] as String?;
    final lastName = profile?['last_name'] as String?;
    final fullName = [firstName, lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    DateTime? weightDate;
    if (latestMetric?['date'] != null) {
      weightDate = DateTime.tryParse(latestMetric!['date'] as String);
    }

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
      clientName: fullName.isNotEmpty ? fullName : null,
      avatarUrl: profile?['avatar_url'] as String?,
      lastWeightKg: (profile?['current_weight'] as num?)?.toDouble(),
      lastWeightDate: weightDate,
      lastSleepHours: (latestMetric?['sleep_hours'] as num?)?.toDouble(),
    );
  }
}
