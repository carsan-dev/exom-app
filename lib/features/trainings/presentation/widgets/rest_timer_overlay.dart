import 'package:flutter/material.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_timer_inline.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Rest timer in a sheet (L5-E3a): a straight [showExomSheet] (D12) that
/// cannot be dismissed by tapping outside or dragging, like before; it closes
/// when the rest ends or is skipped, and, like every `showExomSheet`, when
/// the router location changes (CC 11).
class RestTimerOverlay extends StatelessWidget {
  final int restSeconds;
  final String? nextExerciseName;
  final VoidCallback onDone;

  const RestTimerOverlay({
    super.key,
    required this.restSeconds,
    this.nextExerciseName,
    required this.onDone,
  });

  static Future<void> show(
    BuildContext context, {
    required int restSeconds,
    String? nextExerciseName,
  }) {
    return showExomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => RestTimerOverlay(
        restSeconds: restSeconds,
        nextExerciseName: nextExerciseName,
        onDone: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: RestTimerInline(
        totalSeconds: restSeconds,
        restEndsAt: DateTime.now().add(Duration(seconds: restSeconds)),
        subtitle: nextExerciseName != null
            ? l10n.restTimerNextExercise(nextExerciseName!)
            : null,
        onSkip: onDone,
        onFinished: onDone,
      ),
    );
  }
}
