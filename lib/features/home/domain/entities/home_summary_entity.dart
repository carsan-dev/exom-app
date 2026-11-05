class HomeTrainingItemEntity {
  final String id;
  final String name;
  final bool completed;

  const HomeTrainingItemEntity({
    required this.id,
    required this.name,
    required this.completed,
  });
}

class HomeSummaryEntity {
  final String? trainingId;
  final String? trainingName;
  final List<String> trainingTypes;
  final String? trainingAccentColor;
  final int? trainingDurationMin;
  final int? remainingTrainingDurationMin;
  final bool trainingCompleted;
  final List<HomeTrainingItemEntity> trainings;
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
    this.remainingTrainingDurationMin,
    this.trainingCompleted = false,
    this.trainings = const [],
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

  /// Returns a copy that takes the date-independent profile fields (streak,
  /// name, avatar, latest weight and sleep) from [source].
  HomeSummaryEntity withSharedFieldsFrom(HomeSummaryEntity source) {
    return HomeSummaryEntity(
      trainingId: trainingId,
      trainingName: trainingName,
      trainingTypes: trainingTypes,
      trainingAccentColor: trainingAccentColor,
      trainingDurationMin: trainingDurationMin,
      remainingTrainingDurationMin: remainingTrainingDurationMin,
      trainingCompleted: trainingCompleted,
      trainings: trainings,
      exercisesCompleted: exercisesCompleted,
      totalExercises: totalExercises,
      dietId: dietId,
      dietName: dietName,
      nextMealId: nextMealId,
      nextMealName: nextMealName,
      totalCalories: totalCalories,
      remainingCalories: remainingCalories,
      mealsCompleted: mealsCompleted,
      totalMeals: totalMeals,
      isRestDay: isRestDay,
      streakDays: source.streakDays,
      clientName: source.clientName,
      avatarUrl: source.avatarUrl,
      lastWeightKg: source.lastWeightKg,
      lastWeightDate: source.lastWeightDate,
      lastSleepHours: source.lastSleepHours,
    );
  }
}
