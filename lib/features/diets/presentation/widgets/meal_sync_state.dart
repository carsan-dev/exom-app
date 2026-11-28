import 'package:exom_app/core/widgets/exom_sync_status.dart';

const _mealActionTypes = {'mark_meal_completed', 'unmark_meal_completed'};

/// Sync status of one meal on the diet screen, derived only from state the app
/// already holds (no network call, nothing written).
///
/// [ownedActions] are the offline queue actions of the signed-in owner
/// (`LocalStorage.getPendingSyncActions()`, already filtered by owner). The
/// last mark/unmark action for the day [date] on any of [mealIds] (the meal and
/// its options: completing an option completes the meal) decides:
/// `uploading` -> sending, `failed` -> failed, anything else still queued ->
/// pending. Without such an action there is nothing to show: an action leaves
/// the queue only after the server acknowledged it.
ExomSyncState? mealSyncState({
  required Iterable<Map<String, dynamic>> ownedActions,
  required String date,
  required Set<String> mealIds,
}) {
  Map<String, dynamic>? last;
  for (final action in ownedActions) {
    if (action['date'] != date ||
        !_mealActionTypes.contains(action['type']) ||
        !mealIds.contains(action['meal_id'])) {
      continue;
    }
    last = action;
  }
  if (last == null) return null;
  return switch (last['status']) {
    'uploading' => ExomSyncState.enviando,
    'failed' => ExomSyncState.fallida,
    _ => ExomSyncState.pendiente,
  };
}
