import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';

class DietPeriodDayEntity {
  final DateTime date;
  final DietEntity? diet;

  const DietPeriodDayEntity({required this.date, required this.diet});
}

class DietPeriodEntity {
  final DateTime start;
  final DateTime end;
  final List<DietPeriodDayEntity> days;

  const DietPeriodEntity({
    required this.start,
    required this.end,
    required this.days,
  });

  bool get hasDiets => days.any((day) => day.diet != null);
}
