import 'package:exom_app/features/calendar/domain/entities/week_summary_entity.dart';

class WeekSummaryModel extends WeekSummaryEntity {
  const WeekSummaryModel({
    required super.weekStart,
    required super.trainingsAssigned,
    required super.trainingsCompleted,
    required super.totalMeals,
    required super.mealsCompleted,
  });

  factory WeekSummaryModel.fromJson(Map<String, dynamic> json) {
    return WeekSummaryModel(
      weekStart: json['week_start'] as String,
      trainingsAssigned: json['trainings_assigned'] as int? ?? 0,
      trainingsCompleted: json['trainings_completed'] as int? ?? 0,
      totalMeals: json['total_meals'] as int? ?? 0,
      mealsCompleted: json['meals_completed'] as int? ?? 0,
    );
  }
}
