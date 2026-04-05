import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';

class CalendarDayModel extends CalendarDayEntity {
  const CalendarDayModel({
    required super.date,
    required super.hasTraining,
    required super.hasDiet,
    required super.isRestDay,
    required super.trainingCompleted,
    required super.dietCompleted,
  });

  factory CalendarDayModel.fromJson(Map<String, dynamic> json) {
    return CalendarDayModel(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.utc(1970),
      hasTraining: json['has_training'] as bool? ?? false,
      hasDiet: json['has_diet'] as bool? ?? false,
      isRestDay: json['is_rest_day'] as bool? ?? false,
      trainingCompleted: json['training_completed'] as bool? ?? false,
      dietCompleted: json['diet_completed'] as bool? ?? false,
    );
  }
}
