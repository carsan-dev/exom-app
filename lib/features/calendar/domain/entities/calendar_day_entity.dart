class CalendarDayEntity {
  final DateTime date;
  final bool hasTraining;
  final bool hasDiet;
  final bool isRestDay;
  final bool trainingCompleted;
  final bool dietCompleted;

  /// Trainings assigned that day (`trainings_assigned`), `null` when the API
  /// or the saved calendar does not send it.
  final int? trainingsAssigned;

  /// Recorded completions of the trainings assigned that day
  /// (`trainings_done`), `null` when absent.
  final int? trainingsDone;

  /// `training_completion_mode`: `ALL` (every training) or `ANY` (one of
  /// them completes the day); `null` when absent.
  final String? trainingCompletionMode;

  const CalendarDayEntity({
    required this.date,
    required this.hasTraining,
    required this.hasDiet,
    required this.isRestDay,
    required this.trainingCompleted,
    required this.dietCompleted,
    this.trainingsAssigned,
    this.trainingsDone,
    this.trainingCompletionMode,
  });
}
