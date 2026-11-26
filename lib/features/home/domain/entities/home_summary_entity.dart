class HomeTrainingItemEntity {
  final String id;
  final String name;
  final bool completed;

  /// L4b-D1: thumbnail of its first exercise that has one, if any.
  final String? thumbnailUrl;

  const HomeTrainingItemEntity({
    required this.id,
    required this.name,
    required this.completed,
    this.thumbnailUrl,
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

  /// L4b: program week and training day of the selected date (`null` when
  /// the API does not send them). Day data, never shared between dates.
  final int? programWeek;
  final int? programDay;

  /// L4b-D5: planned sets of every training of the day.
  final int totalSets;

  /// L4b-D1: photo of the primary training, for summaries without
  /// [trainings]; otherwise each item carries its own.
  final String? trainingThumbnailUrl;

  /// E1 D1: why part of this summary is the saved copy (or nothing) instead
  /// of a fresh answer, as `ApiException(status): message` (status 0 = no
  /// network or timeout). `null` when every request answered. Describes this
  /// load only: [withSharedFieldsFrom] keeps this summary's own reason.
  final String? staleReason;

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
    this.programWeek,
    this.programDay,
    this.totalSets = 0,
    this.trainingThumbnailUrl,
    this.staleReason,
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
      programWeek: programWeek,
      programDay: programDay,
      totalSets: totalSets,
      trainingThumbnailUrl: trainingThumbnailUrl,
      staleReason: staleReason,
    );
  }

  /// E6a: a copy with the training [trainingId] done, as the server
  /// confirmed it, or `null` when this summary does not hold that training.
  /// The day is done once every one of its trainings is. Only the completion
  /// flags change: progress figures, minutes left and the streak are not
  /// deducible from the confirmation and stay as they were.
  HomeSummaryEntity? withTrainingCompleted(String trainingId) {
    final List<HomeTrainingItemEntity> items;
    if (trainings.isNotEmpty) {
      if (!trainings.any((training) => training.id == trainingId)) return null;
      items = [
        for (final training in trainings)
          training.id == trainingId && !training.completed
              ? HomeTrainingItemEntity(
                  id: training.id,
                  name: training.name,
                  completed: true,
                  thumbnailUrl: training.thumbnailUrl,
                )
              : training,
      ];
    } else if (this.trainingId == trainingId) {
      items = trainings;
    } else {
      return null;
    }
    return HomeSummaryEntity(
      trainingId: this.trainingId,
      trainingName: trainingName,
      trainingTypes: trainingTypes,
      trainingAccentColor: trainingAccentColor,
      trainingDurationMin: trainingDurationMin,
      remainingTrainingDurationMin: remainingTrainingDurationMin,
      trainingCompleted:
          trainingCompleted ||
          items.isEmpty ||
          items.every((training) => training.completed),
      trainings: items,
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
      streakDays: streakDays,
      clientName: clientName,
      avatarUrl: avatarUrl,
      lastWeightKg: lastWeightKg,
      lastWeightDate: lastWeightDate,
      lastSleepHours: lastSleepHours,
      programWeek: programWeek,
      programDay: programDay,
      totalSets: totalSets,
      trainingThumbnailUrl: trainingThumbnailUrl,
      staleReason: staleReason,
    );
  }
}
