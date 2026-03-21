class WeekSummaryEntity {
  final String weekStart;
  final int trainingsAssigned;
  final int trainingsCompleted;
  final int totalMeals;
  final int mealsCompleted;

  const WeekSummaryEntity({
    required this.weekStart,
    required this.trainingsAssigned,
    required this.trainingsCompleted,
    required this.totalMeals,
    required this.mealsCompleted,
  });
}
