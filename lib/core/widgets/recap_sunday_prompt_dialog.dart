import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/tutorial_prompt_dialog.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// In-app Sunday recap reminder: the quick-tour prompt card with the recap
/// copy, «Rellenar recap» / «Omitir» and the «No volver a mostrar» row.
class RecapSundayPromptDialog extends StatelessWidget {
  const RecapSundayPromptDialog({
    super.key,
    required this.onFill,
    required this.onSkip,
    required this.dontShowAgain,
    required this.onDontShowAgainChanged,
  });

  final VoidCallback onFill;
  final VoidCallback onSkip;
  final bool dontShowAgain;
  final ValueChanged<bool> onDontShowAgainChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TutorialPromptDialog(
      onStart: onFill,
      onSkip: onSkip,
      icon: ExomIcons.barChart,
      title: l10n.recapSundayPromptTitle,
      description: l10n.recapSundayPromptBody,
      startLabel: l10n.recapSundayPromptFill,
      skipLabel: l10n.tutorialSkipButton,
      dontShowAgain: dontShowAgain,
      onDontShowAgainChanged: onDontShowAgainChanged,
    );
  }
}
