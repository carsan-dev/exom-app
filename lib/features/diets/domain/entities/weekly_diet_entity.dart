import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';

class WeeklyDietDayEntity {
  final DateTime date;
  final DietEntity? diet;

  const WeeklyDietDayEntity({required this.date, required this.diet});
}

class WeeklyDietEntity {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<WeeklyDietDayEntity> days;

  const WeeklyDietEntity({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
  });

  bool get hasDiets => days.any((day) => day.diet != null);
}
