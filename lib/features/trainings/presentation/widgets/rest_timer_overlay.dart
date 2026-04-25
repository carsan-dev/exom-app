import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_timer_inline.dart';
import 'package:exom_app/l10n/app_localizations.dart';

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
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RestTimerOverlay(
        restSeconds: restSeconds,
        nextExerciseName: nextExerciseName,
        onDone: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: GlassDecoration.elevated(borderRadius: 28),
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              RestTimerInline(
                totalSeconds: restSeconds,
                restEndsAt: DateTime.now().add(Duration(seconds: restSeconds)),
                subtitle: nextExerciseName != null
                    ? l10n.restTimerNextExercise(nextExerciseName!)
                    : null,
                onSkip: onDone,
                onFinished: onDone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
