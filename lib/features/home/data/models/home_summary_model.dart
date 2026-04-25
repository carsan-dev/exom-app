import 'package:exom_app/core/utils/training_type_utils.dart';

class HomeSummaryModel {
  final String? trainingName;
  final List<String> trainingTypes;
  final String? trainingAccentColor;
  final int? trainingDurationMin;
  final bool trainingCompleted;
  final String? trainingId;
  final int exercisesCompleted;
  final int totalExercises;
  final String? dietName;
  final String? dietId;
  final String? nextMealId;
  final String? nextMealName;
  final int? totalCalories;
  final int mealsCompleted;
  final int totalMeals;
  final bool isRestDay;
  final int streakDays;
  final String? clientName;
  final String? avatarUrl;
  final double? lastWeightKg;
  final DateTime? lastWeightDate;
  final double? lastSleepHours;

  const HomeSummaryModel({
    this.trainingName,
    this.trainingTypes = const [],
    this.trainingAccentColor,
    this.trainingDurationMin,
    this.trainingCompleted = false,
    this.trainingId,
    this.exercisesCompleted = 0,
    this.totalExercises = 0,
    this.dietName,
    this.dietId,
    this.nextMealId,
    this.nextMealName,
    this.totalCalories,
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

  factory HomeSummaryModel.fromParts({
    required Map<String, dynamic>? training,
    required Map<String, dynamic>? diet,
    required Map<String, dynamic>? streak,
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? latestMetric,
    required Map<String, dynamic>? progress,
  }) {
    final firstName = profile?['first_name'] as String?;
    final lastName = profile?['last_name'] as String?;
    final fullName = [
      firstName,
      lastName,
    ].where((s) => s != null && s.isNotEmpty).join(' ');

    DateTime? weightDate;
    if (latestMetric?['date'] != null) {
      weightDate = DateTime.tryParse(latestMetric!['date'] as String);
    }

    final trainingExercises =
        (training?['exercises'] as List?) ??
        (training?['training_exercises'] as List?) ??
        [];
    final totalExercises = trainingExercises.length;
    final completedExIds = (progress?['exercises_completed'] as List? ?? [])
        .map((e) => (e as Map<String, dynamic>)['exercise_id'] as String)
        .toSet();
    final exercisesCompleted = completedExIds.length;
    final trainingCompleted =
        (progress?['training_completed'] as bool?) ??
        (totalExercises > 0 && exercisesCompleted >= totalExercises);

    final dietMeals = diet?['meals'] as List? ?? [];
    final totalMeals = dietMeals.length;
    final completedMealIds = (progress?['meals_completed'] as List? ?? [])
        .map((e) => e as String)
        .toSet();
    final mealsCompleted = completedMealIds.length;
    final normalizedMeals = dietMeals
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    final nextMeal = normalizedMeals.cast<Map<String, dynamic>?>().firstWhere(
      (meal) => !completedMealIds.contains(meal?['id'] as String?),
      orElse: () => normalizedMeals.isNotEmpty ? normalizedMeals.first : null,
    );

    final trainingTypes = resolveTrainingTypes(
      types:
          (training?['types'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList(growable: false),
      legacyType: training?['type'] as String?,
    );

    return HomeSummaryModel(
      trainingId: training?['id'] as String?,
      trainingName: training?['name'] as String?,
      trainingTypes: trainingTypes,
      trainingAccentColor: normalizeTrainingAccentHex(
        training?['accentColor'] as String?,
      ),
      trainingDurationMin: training?['estimated_duration_min'] as int?,
      trainingCompleted: trainingCompleted,
      exercisesCompleted: exercisesCompleted,
      totalExercises: totalExercises,
      dietId: diet?['id'] as String?,
      dietName: diet?['name'] as String?,
      nextMealId: nextMeal?['id'] as String?,
      nextMealName: nextMeal?['name'] as String?,
      totalCalories: diet?['total_calories'] as int?,
      mealsCompleted: mealsCompleted,
      totalMeals: totalMeals,
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
