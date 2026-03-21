class HomeSummaryEntity {
  final String? trainingId;
  final String? trainingName;
  final String? trainingType;
  final int? trainingDurationMin;
  final bool trainingCompleted;
  final String? dietId;
  final String? dietName;
  final int? totalCalories;
  final bool isRestDay;
  final int streakDays;
  final String? clientName;
  final String? avatarUrl;

  const HomeSummaryEntity({
    this.trainingId,
    this.trainingName,
    this.trainingType,
    this.trainingDurationMin,
    this.trainingCompleted = false,
    this.dietId,
    this.dietName,
    this.totalCalories,
    this.isRestDay = false,
    this.streakDays = 0,
    this.clientName,
    this.avatarUrl,
  });
}
