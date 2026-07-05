class HomeSummaryEntity {
  final String? trainingId;
  final String? trainingName;
  final List<String> trainingTypes;
  final String? trainingAccentColor;
  final int? trainingDurationMin;
  final bool trainingCompleted;
  final int exercisesCompleted;
  final int totalExercises;
  final String? dietId;
  final String? dietName;
  final String? nextMealId;
  final String? nextMealName;
  final int? totalCalories;
  final int? remainingCalories;
  final int mealsCompleted;
  final int totalMeals;
  final bool isRestDay;
  final int streakDays;
  final String? clientName;
  final String? avatarUrl;
  final double? lastWeightKg;
  final DateTime? lastWeightDate;
  final double? lastSleepHours;

  const HomeSummaryEntity({
    this.trainingId,
    this.trainingName,
    this.trainingTypes = const [],
    this.trainingAccentColor,
    this.trainingDurationMin,
    this.trainingCompleted = false,
    this.exercisesCompleted = 0,
    this.totalExercises = 0,
    this.dietId,
    this.dietName,
    this.nextMealId,
    this.nextMealName,
    this.totalCalories,
    this.remainingCalories,
    this.mealsCompleted = 0,
    this.totalMeals = 0,
    this.isRestDay = false,
    this.streakDays = 0,
    this.clientName,
    this.avatarUrl,
    this.lastWeightKg,
    this.lastWeightDate,
    this.lastSleepHours,
  });
}
