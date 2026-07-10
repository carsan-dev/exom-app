import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';

class WeeklyDietDayEntity extends DietPeriodDayEntity {
  const WeeklyDietDayEntity({required super.date, required super.diet});
}

class WeeklyDietEntity extends DietPeriodEntity {
  final DateTime weekStart;
  final DateTime weekEnd;

  const WeeklyDietEntity({
    required this.weekStart,
    required this.weekEnd,
    required List<WeeklyDietDayEntity> days,
  }) : super(start: weekStart, end: weekEnd, days: days);
}
