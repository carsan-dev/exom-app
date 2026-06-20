import 'package:exom_app/features/diets/data/models/diet_model.dart';

class WeeklyDietDayModel {
  final DateTime date;
  final DietModel? diet;

  const WeeklyDietDayModel({required this.date, required this.diet});

  factory WeeklyDietDayModel.fromJson(Map<String, dynamic> json) {
    final diet = json['diet'];
    return WeeklyDietDayModel(
      date: DateTime.parse(json['date'] as String),
      diet: diet is Map
          ? DietModel.fromJson(Map<String, dynamic>.from(diet))
          : null,
    );
  }
}

class WeeklyDietModel {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<WeeklyDietDayModel> days;

  const WeeklyDietModel({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
  });

  factory WeeklyDietModel.fromJson(Map<String, dynamic> json) {
    return WeeklyDietModel(
      weekStart: DateTime.parse(json['week_start'] as String),
      weekEnd: DateTime.parse(json['week_end'] as String),
      days: (json['days'] as List<dynamic>? ?? const [])
          .map(
            (day) => WeeklyDietDayModel.fromJson(
              Map<String, dynamic>.from(day as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
