import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Horizontal margin of the dialog to the screen edges: the one of the EXOM
/// flat dialog (`execution_start_countdown.dart`). With the default 40 dp the
/// two actions no longer fit side by side on a phone at text scale 1,0 and the
/// action bar stacked them (OBS-7, L5-D64).
const double discardForeignProgressDialogInset = 20;

/// «Descartar progreso anterior» (L5-D64): asks whether the active exercise
/// saved by another training may be discarded. True only when the user
/// confirms; cancelling or dismissing gives false. It persists nothing: the
/// caller discards and opens the exercise.
///
/// The actions stay in one row while they fit and stack only when they do not
/// (the dialog action bar is an [OverflowBar]), so large text still works.
Future<bool> confirmDiscardForeignProgress(BuildContext context) async {
  final shouldDiscard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      return AlertDialog(
        key: const Key('discard-foreign-progress-dialog'),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: discardForeignProgressDialogInset,
          vertical: 24,
        ),
        title: Text(l10n.activeExerciseDiscardTitle),
        content: Text(l10n.activeExerciseDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.activeExerciseDiscardAction),
          ),
        ],
      );
    },
  );
  return shouldDiscard == true;
}
