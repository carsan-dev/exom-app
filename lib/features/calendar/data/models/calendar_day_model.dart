import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';

class CalendarDayModel extends CalendarDayEntity {
  const CalendarDayModel({
    required super.date,
    required super.hasTraining,
    required super.hasDiet,
    required super.isRestDay,
    required super.trainingCompleted,
    required super.dietCompleted,
    super.trainingsAssigned,
    super.trainingsDone,
    super.trainingCompletionMode,
  });

  factory CalendarDayModel.fromJson(Map<String, dynamic> json) {
    return CalendarDayModel(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.utc(1970),
      hasTraining: json['has_training'] as bool? ?? false,
      hasDiet: json['has_diet'] as bool? ?? false,
      isRestDay: json['is_rest_day'] as bool? ?? false,
      trainingCompleted: json['training_completed'] as bool? ?? false,
      dietCompleted: json['diet_completed'] as bool? ?? false,
      trainingsAssigned: _count(json['trainings_assigned']),
      trainingsDone: _count(json['trainings_done']),
      trainingCompletionMode: switch (json['training_completion_mode']) {
        final String mode => mode,
        _ => null,
      },
    );
  }

  /// A whole number >= 0, or `null` for anything else (absent on an older
  /// API or an older saved calendar).
  static int? _count(Object? value) {
    if (value is int) return value >= 0 ? value : null;
    if (value is double && value.isFinite && value >= 0) {
      return value == value.truncateToDouble() ? value.toInt() : null;
    }
    return null;
  }
}
