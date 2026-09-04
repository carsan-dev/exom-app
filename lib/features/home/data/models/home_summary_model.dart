import 'package:exom_app/core/utils/training_type_utils.dart';

class HomeSummaryModel {
  final List<HomeTrainingItemModel> trainings;
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
    this.trainings = const [],
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
    final dayTrainings = training?['trainings'] is List
        ? (training!['trainings'] as List)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
        : training != null
        ? [training]
        : const <Map<String, dynamic>>[];
    final primaryTraining = dayTrainings.isNotEmpty ? dayTrainings.first : null;
    training = primaryTraining;
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

    List<Map<String, dynamic>> exercisesFor(Map<String, dynamic> training) =>
        ((training['exercises'] as List?) ??
                (training['training_exercises'] as List?) ??
                const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    final trainingExercises = dayTrainings
        .expand(exercisesFor)
        .toList(growable: false);
    final totalExercises = trainingExercises.length;
    final completedEntries = (progress?['exercises_completed'] as List? ?? [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
    final completedTrainingExerciseIds = completedEntries
        .map((entry) => entry['training_exercise_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final legacyCompletedExerciseCounts = <String, int>{};
    for (final entry in completedEntries) {
      if (entry['training_exercise_id'] != null) continue;
      final exerciseId = entry['exercise_id']?.toString();
      if (exerciseId == null || exerciseId.isEmpty) continue;
      legacyCompletedExerciseCounts.update(
        exerciseId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final completedCurrentOccurrenceIds = <String>{};
    for (final rawExercise in trainingExercises) {
      final trainingExerciseId = rawExercise['id']?.toString();
      if (trainingExerciseId == null || trainingExerciseId.isEmpty) continue;
      if (completedTrainingExerciseIds.contains(trainingExerciseId)) {
        completedCurrentOccurrenceIds.add(trainingExerciseId);
        continue;
      }

      final exercise = rawExercise['exercise'] as Map<String, dynamic>?;
      final exerciseId = exercise?['id']?.toString();
      final legacyKey = [trainingExerciseId, exerciseId]
          .whereType<String>()
          .firstWhere(
            (id) => (legacyCompletedExerciseCounts[id] ?? 0) > 0,
            orElse: () => '',
          );
      if (legacyKey.isEmpty) continue;
      completedCurrentOccurrenceIds.add(trainingExerciseId);
      final remaining = legacyCompletedExerciseCounts[legacyKey]! - 1;
      if (remaining == 0) {
        legacyCompletedExerciseCounts.remove(legacyKey);
      } else {
        legacyCompletedExerciseCounts[legacyKey] = remaining;
      }
    }
    final exercisesCompleted = completedCurrentOccurrenceIds.length;
    final completedTrainingIds =
        (progress?['trainings_completed'] as List? ?? const [])
            .map((id) => id.toString())
            .toSet();
    final legacyDayCompletion =
        dayTrainings.length == 1 &&
        progress?['training_completed'] == true &&
        completedEntries.isEmpty &&
        completedTrainingIds.isEmpty;
    bool isTrainingCompleted(Map<String, dynamic> item) {
      final trainingId = item['id']?.toString();
      if (trainingId != null && completedTrainingIds.contains(trainingId)) {
        return true;
      }
      final exercises = exercisesFor(item);
      return (exercises.isNotEmpty &&
              exercises.every(
                (exercise) => completedCurrentOccurrenceIds.contains(
                  exercise['id']?.toString(),
                ),
              )) ||
          legacyDayCompletion;
    }

    final trainingCompleted =
        dayTrainings.isNotEmpty && dayTrainings.every(isTrainingCompleted);
    final trainingDurations = dayTrainings
        .map((item) => (item['estimated_duration_min'] as num?)?.toInt())
        .toList(growable: false);
    final trainingDuration =
        trainingDurations.isNotEmpty &&
            trainingDurations.every((duration) => duration != null)
        ? trainingDurations.whereType<int>().fold<int>(
            0,
            (sum, duration) => sum + duration,
          )
        : null;
    final remainingTrainingDuration = trainingDuration == null
        ? null
        : dayTrainings.fold<int>(0, (sum, item) {
            if (isTrainingCompleted(item)) return sum;
            final duration = (item['estimated_duration_min'] as num?)!.toInt();
            final exercises = exercisesFor(item);
            final totalSets = exercises.fold<int>(
              0,
              (sets, exercise) =>
                  sets + ((exercise['sets'] as num?)?.toInt() ?? 0),
            );
            if (totalSets <= 0) return sum + duration;
            final completedSets = exercises
                .where(
                  (exercise) => completedCurrentOccurrenceIds.contains(
                    exercise['id']?.toString(),
                  ),
                )
                .fold<int>(
                  0,
                  (sets, exercise) =>
                      sets + ((exercise['sets'] as num?)?.toInt() ?? 0),
                );
            return sum +
                (duration *
                        (totalSets - completedSets).clamp(0, totalSets) /
                        totalSets)
                    .round()
                    .clamp(0, duration);
          });

    final dietMeals = diet?['meals'] as List? ?? [];
    final completedMealIds = (progress?['meals_completed'] as List? ?? [])
        .map((e) => e as String)
        .toSet();
    final normalizedMeals = dietMeals
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    final totalMeals = normalizedMeals.length;
    bool isMealGroupCompleted(Map<String, dynamic> meal) => <String?>[
      meal['id'] as String?,
      ...(meal['variants'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((variant) => variant['id'] as String?),
    ].any(completedMealIds.contains);
    final mealsCompleted = normalizedMeals.where(isMealGroupCompleted).length;
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

    final trainingTypes = dayTrainings
        .expand(
          (item) => resolveTrainingTypes(
            types: (item['types'] as List<dynamic>?)
                ?.map((type) => type.toString())
                .toList(growable: false),
            legacyType: item['type'] as String?,
          ),
        )
        .toSet()
        .toList(growable: false);

    return HomeSummaryModel(
      trainings: dayTrainings
          .map(
            (item) => HomeTrainingItemModel(
              id: item['id'] as String? ?? '',
              name: item['name'] as String? ?? '',
              completed: isTrainingCompleted(item),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
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
      isRestDay: training == null && diet == null,
      streakDays: streak?['current_days'] as int? ?? 0,
      clientName: fullName.isNotEmpty ? fullName : null,
      avatarUrl: profile?['avatar_url'] as String?,
      lastWeightKg: (profile?['current_weight'] as num?)?.toDouble(),
      lastWeightDate: weightDate,
      lastSleepHours: (latestMetric?['sleep_hours'] as num?)?.toDouble(),
    );
  }
}

class HomeTrainingItemModel {
  final String id;
  final String name;
  final bool completed;

  const HomeTrainingItemModel({
    required this.id,
    required this.name,
    required this.completed,
  });
}
