import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// Execution states of the local registry that mean «not finished yet»
/// (`pending-sync`, `failed` and `conflict` are finished work waiting to be
/// sent, not unfinished work).
const _unfinishedExecutionStatuses = ['pending', 'pending-finalize'];

/// Whether the current owner has a workout in progress on this device: an
/// unfinished execution or an active circuit.
///
/// It mirrors the «pending» box of Entrenar: the same
/// `getPendingTrainingExecutions()` list, keeping only effective statuses
/// `pending` and `pending-finalize`. That method already covers drafts: a
/// draft whose execution is registered is judged by the registry status
/// (leftover 0-set drafts of a finished execution never count), and a draft
/// whose execution is not registered is listed as `pending` only when its
/// date/session suffix is verifiable; drafts without a session id are not
/// listed. So `getActiveWorkouts()` is deliberately not read on its own.
///
/// Read-only over the owner's namespace (L5-D67).
bool hasUnfinishedLocalWorkout(LocalStorage storage) {
  final executions = storage.getPendingTrainingExecutions();
  if (executions.any(
    (entry) => _unfinishedExecutionStatuses.contains(entry['status']),
  )) {
    return true;
  }
  return storage.hasActiveCircuitState;
}

/// Decides whether the user's «Cerrar sesión» may go on (L5-D67).
///
/// Without an unfinished local workout it returns `true` at once, so the
/// log-out is exactly what it was. With one, it asks in a confirmation sheet
/// (the work stays on this device and returns when signing back in with the
/// same account) and returns `true` only if the user confirms, the [context]
/// is still mounted and the session is still the one that was on screen.
///
/// If reading the local state fails the check is skipped and it returns
/// `true`: a storage problem must never keep the user from signing out.
Future<bool> confirmLogoutIfUnfinishedWorkout(BuildContext context) async {
  try {
    return await _confirmLogout(context);
  } catch (error) {
    // Type only: the message could carry account data.
    debugPrint('Logout: confirmation failed (${error.runtimeType})');
    return true;
  }
}

Future<bool> _confirmLogout(BuildContext context) async {
  final storage = sl<LocalStorage>();
  final sessionStamp = storage.sessionStamp;
  if (!hasUnfinishedLocalWorkout(storage)) return true;
  if (!context.mounted) return false;

  final l10n = AppLocalizations.of(context);
  final confirmed = await showExomSheet<bool>(
    context: context,
    title: l10n.logoutUnfinishedWorkoutTitle,
    body: l10n.logoutUnfinishedWorkoutBody,
    actions: [
      Builder(
        builder: (sheetContext) => ExomPrimaryButton(
          key: const Key('logout-unfinished-confirm'),
          label: l10n.logoutUnfinishedWorkoutConfirm,
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
      ),
      Builder(
        builder: (sheetContext) => ExomSecondaryButton(
          key: const Key('logout-unfinished-cancel'),
          label: l10n.cancel,
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
      ),
    ],
  );
  // The session may have changed while the sheet was open: never sign out
  // whoever owns the storage now.
  if (confirmed != true || !context.mounted) return false;
  return storage.sessionStamp == sessionStamp;
}
