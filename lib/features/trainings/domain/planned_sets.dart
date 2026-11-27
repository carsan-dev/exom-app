/// The single rule for the planned sets of a session (decision L4b-D5).
///
/// A standalone exercise counts its own `sets`. An exercise of a circuit
/// block (`blockId` set) counts `sets x rounds` of the block: the API stores
/// `sets: 1` per circuit exercise and the rounds on the block. Used by the
/// Inicio fact line and remaining minutes and by
/// `TrainingEntity.remainingProgress`, so they cannot drift apart.
library;

/// Rounds of a circuit block when the payload omits them (API default).
const int defaultBlockRounds = 3;

/// Planned sets of one exercise.
int plannedSetsOf({
  required int sets,
  required bool inBlock,
  int? blockRounds,
}) {
  if (!inBlock) return sets;
  final rounds = blockRounds ?? defaultBlockRounds;
  return sets * (rounds < 1 ? 1 : rounds);
}

/// Total and completed planned sets of a list of exercises.
class PlannedSetsTally {
  const PlannedSetsTally({required this.total, required this.completed});

  final int total;
  final int completed;

  int get remaining => (total - completed).clamp(0, total < 0 ? 0 : total);

  /// [durationMin] prorated by the remaining sets; `null` without a duration
  /// or without sets.
  int? remainingMinutes(int? durationMin) {
    if (durationMin == null || total <= 0) return null;
    return (durationMin * remaining / total).round().clamp(0, durationMin);
  }
}

/// Adds the planned sets of [exercises]; completed exercises count in full
/// (an exercise is marked completed only once every round is done).
PlannedSetsTally tallyPlannedSets<T>(
  Iterable<T> exercises, {
  required int Function(T exercise) plannedSets,
  required bool Function(T exercise) isCompleted,
}) {
  var total = 0;
  var completed = 0;
  for (final exercise in exercises) {
    final sets = plannedSets(exercise);
    total += sets;
    if (isCompleted(exercise)) completed += sets;
  }
  return PlannedSetsTally(total: total, completed: completed);
}
