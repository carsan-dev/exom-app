import 'package:exom_app/core/utils/training_type_utils.dart';

class HomeSummaryModel {
  final String? trainingName;
  final List<String> trainingTypes;
  final String? trainingAccentColor;
  final int? trainingDurationMin;
  final int? remainingTrainingDurationMin;
  final bool trainingCompleted;
  final String? trainingId;
  final int exercisesCompleted;
  final int totalExercises;
  final String? dietName;
  final String? dietId;
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

  const HomeSummaryModel({
    this.trainingName,
    this.trainingTypes = const [],
    this.trainingAccentColor,
    this.trainingDurationMin,
    this.remainingTrainingDurationMin,
    this.trainingCompleted = false,
    this.trainingId,
    this.exercisesCompleted = 0,
    this.totalExercises = 0,
    this.dietName,
    this.dietId,
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
    var totalTrainingSets = 0;
    var completedTrainingSets = 0;
    for (final rawExercise
        in trainingExercises.whereType<Map<String, dynamic>>()) {
      final sets = (rawExercise['sets'] as num?)?.toInt() ?? 0;
      totalTrainingSets += sets;
      final exercise = rawExercise['exercise'] as Map<String, dynamic>?;
      final isCompleted =
          completedExIds.contains(rawExercise['id']) ||
          completedExIds.contains(exercise?['id']);
      if (isCompleted) completedTrainingSets += sets;
    }
    final trainingDuration = (training?['estimated_duration_min'] as num?)
        ?.toInt();
    final remainingTrainingDuration =
        trainingDuration == null || totalTrainingSets <= 0
        ? null
        : (trainingDuration *
                  (totalTrainingSets - completedTrainingSets).clamp(
                    0,
                    totalTrainingSets,
                  ) /
                  totalTrainingSets)
              .round()
              .clamp(0, trainingDuration);
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
    final nextMeal = normalizedMeals.cast<Map<String, dynamic>?>().firstWhere((
      meal,
    ) {
      if (meal == null) return false;
      final groupIds = <String?>[
        meal['id'] as String?,
        ...(meal['variants'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((variant) => variant['id'] as String?),
      ];
      return !groupIds.any(completedMealIds.contains);
    }, orElse: () => normalizedMeals.isNotEmpty ? normalizedMeals.first : null);
    var consumedCalories = 0;
    for (final meal in normalizedMeals) {
      final options = <Map<String, dynamic>>[
        meal,
        ...(meal['variants'] as List? ?? const [])
            .whereType<Map<String, dynamic>>(),
      ];
      for (final option in options) {
        if (completedMealIds.contains(option['id'])) {
          consumedCalories += (option['calories'] as num?)?.toInt() ?? 0;
          break;
        }
      }
    }
    final totalCalories = (diet?['total_calories'] as num?)?.toInt();

    final trainingTypes = resolveTrainingTypes(
      types: (training?['types'] as List<dynamic>?)
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
      trainingDurationMin: trainingDuration,
      remainingTrainingDurationMin: remainingTrainingDuration,
      trainingCompleted: trainingCompleted,
      exercisesCompleted: exercisesCompleted,
      totalExercises: totalExercises,
      dietId: diet?['id'] as String?,
      dietName: diet?['name'] as String?,
      nextMealId: nextMeal?['id'] as String?,
      nextMealName: nextMeal?['name'] as String?,
      totalCalories: totalCalories,
      remainingCalories: totalCalories == null
          ? null
          : (totalCalories - consumedCalories).clamp(0, totalCalories).toInt(),
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
