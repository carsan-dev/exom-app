import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';

// Prefill of the set sheet (decision D4 of the redesign, approved 2026-11-18).
// Every function returns stored values verbatim (kilograms, whole counts):
// formatting and unit conversion happen only when painting.

/// Weight of the previous session for [setNumber]: that set's weight when it
/// has one, otherwise the weight of the last set (highest number) that has
/// one. Unlike `performanceForSet`, never falls back to a set without weight.
double? previousWeightForSet(List<SetPerformance>? previous, int setNumber) {
  if (previous == null || previous.isEmpty) return null;
  SetPerformance? lastWeighted;
  for (final set in previous) {
    if (set.weightKg == null) continue;
    if (set.setNumber == setNumber) return set.weightKg;
    if (lastWeighted == null || set.setNumber >= lastWeighted.setNumber) {
      lastWeighted = set;
    }
  }
  return lastWeighted?.weightKg;
}

/// Weight (kg) prefilled for [setNumber]: today's value for this set, then
/// the last weight of this execution ([sessionWeightKg], which starts at the
/// exercise's `initialWeightKg`), then the previous session's same set, then
/// the previous session's last weighted set; null when there is none.
double? prefillWeightKg({
  required SetPerformance? today,
  required double? sessionWeightKg,
  required List<SetPerformance>? previous,
  required int setNumber,
}) {
  return today?.weightKg ??
      sessionWeightKg ??
      previousWeightForSet(previous, setNumber);
}

/// Reps (or seconds when [timed]) prefilled for a set: today's value for this
/// set, then the last set logged in this execution, then the previous
/// session's same set, then the prescription [target]; null when none.
int? prefillCount({
  required SetPerformance? today,
  required SetPerformance? lastThisExecution,
  required SetPerformance? previousSameSet,
  required int? target,
  required bool timed,
}) {
  int? of(SetPerformance? set) => timed ? set?.seconds : set?.reps;
  return of(today) ?? of(lastThisExecution) ?? of(previousSameSet) ?? target;
}

/// RIR preselected in the sheet: a set already logged today shows its stored
/// value (none when it was saved without RIR); a new set preselects the
/// prescription's [targetRir] (none when there is no target).
int? prefillRir({required SetPerformance? today, required int? targetRir}) {
  if (today != null) return today.rir;
  return targetRir;
}

/// Chip that represents [rir] in the 0-5+ choice: values above 5 are shown as
/// «5+» (the stored value itself is kept unless the user picks another chip).
int? rirChipFor(int? rir) {
  if (rir == null) return null;
  return rir > 5 ? 5 : rir;
}
