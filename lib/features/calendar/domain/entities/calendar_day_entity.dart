class CalendarDayEntity {
  final DateTime date;
  final bool hasTraining;
  final bool hasDiet;
  final bool isRestDay;
  final bool trainingCompleted;
  final bool dietCompleted;

  const CalendarDayEntity({
    required this.date,
    required this.hasTraining,
    required this.hasDiet,
    required this.isRestDay,
    required this.trainingCompleted,
    required this.dietCompleted,
  });
}
