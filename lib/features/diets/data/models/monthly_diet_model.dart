import 'package:exom_app/features/diets/data/models/weekly_diet_model.dart';

class MonthlyDietModel {
  final DateTime monthStart;
  final DateTime monthEnd;
  final List<WeeklyDietDayModel> days;

  const MonthlyDietModel({
    required this.monthStart,
    required this.monthEnd,
    required this.days,
  });

  factory MonthlyDietModel.fromJson(Map<String, dynamic> json) {
    return MonthlyDietModel(
      monthStart: DateTime.parse(json['month_start'] as String),
      monthEnd: DateTime.parse(json['month_end'] as String),
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
