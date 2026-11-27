import 'package:exom_app/core/widgets/exom_sync_status.dart';

const _exerciseActionTypes = {
  'mark_exercise_completed',
  'unmark_exercise_completed',
};

const _completeTraining = 'complete_training';

/// Sync status of one training exercise on the training detail, derived only
/// from state the app already holds (no network call).
///
/// [ownedActions] are the offline queue actions of the signed-in owner
/// (`LocalStorage.getPendingSyncActions()`, already filtered by owner). The
/// last mark/unmark action of this exercise, date and execution decides:
/// `uploading` -> sending, `failed` -> failed, anything else still queued ->
/// pending. Without such an action, a completed exercise follows the
/// `complete_training` action of the same training, date and execution
/// ("Completar todo" marks every exercise complete without a mark action of
/// its own), with the same mapping. An action leaves the queue only after the
/// server acknowledged it (or after an explicit discard), so with neither
/// action a completed exercise is confirmed. Not completed, a local draft
/// with saved sets is "saved on this phone"; otherwise there is nothing to
/// show.
ExomSyncState? exerciseSyncState({
  required Iterable<Map<String, dynamic>> ownedActions,
  required String trainingId,
  required String date,
  required String trainingExerciseId,
  required String? sessionId,
  required bool isCompleted,
  required bool hasLocalDraft,
}) {
  Map<String, dynamic>? last;
  Map<String, dynamic>? completion;
  for (final action in ownedActions) {
    if (action['date'] != date || action['training_session_id'] != sessionId) {
      continue;
    }
    if (_exerciseActionTypes.contains(action['type']) &&
        action['training_exercise_id'] == trainingExerciseId) {
      last = action;
    } else if (action['type'] == _completeTraining &&
        action['training_id'] == trainingId) {
      completion = action;
    }
  }
  if (last != null) return _queueState(last);
  if (isCompleted) {
    return completion == null
        ? ExomSyncState.confirmada
        : _queueState(completion);
  }
  if (hasLocalDraft) return ExomSyncState.guardadaEnMovil;
  return null;
}

ExomSyncState _queueState(Map<String, dynamic> action) =>
    switch (action['status']) {
      'uploading' => ExomSyncState.enviando,
      'failed' => ExomSyncState.fallida,
      _ => ExomSyncState.pendiente,
    };

/// Aggregated status of a circuit from its members' [exerciseSyncState]:
/// failed, then sending, then pending; confirmed only when [allCompleted] and
/// no member is still in the queue.
ExomSyncState? circuitSyncState(
  Iterable<ExomSyncState?> members, {
  required bool allCompleted,
}) {
  final states = members.toSet();
  for (final state in const [
    ExomSyncState.fallida,
    ExomSyncState.enviando,
    ExomSyncState.pendiente,
  ]) {
    if (states.contains(state)) return state;
  }
  return allCompleted ? ExomSyncState.confirmada : null;
}
