import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';

/// Automatic prompt card over a dimmed scrim. By default it is the quick-tour
/// prompt; the optional parameters reuse the same card for other automatic
/// prompts (Sunday recap reminder) and add the «No volver a mostrar» row.
class TutorialPromptDialog extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSkip;

  /// Icon in the circle. Defaults to [ExomIcons.explore].
  final IconData icon;

  /// Texts; each `null` falls back to the quick-tour copy.
  final String? title;
  final String? description;
  final String? startLabel;
  final String? skipLabel;

  /// Value of the «No volver a mostrar» checkbox.
  final bool dontShowAgain;

  /// When non-null the «No volver a mostrar» row is shown (whole row
  /// tappable, at least 48 dp high) and reports every toggle.
  final ValueChanged<bool>? onDontShowAgainChanged;

  const TutorialPromptDialog({
    super.key,
    required this.onStart,
    required this.onSkip,
    this.icon = ExomIcons.explore,
    this.title,
    this.description,
    this.startLabel,
    this.skipLabel,
    this.dontShowAgain = false,
    this.onDontShowAgainChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: palette.borderSoft,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: palette.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title ?? l10n.tutorialPromptTitle,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description ?? l10n.tutorialPromptDescription,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (onDontShowAgainChanged case final onChanged?) ...[
                const SizedBox(height: 16),
                _DontShowAgainRow(value: dontShowAgain, onChanged: onChanged),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    startLabel ?? l10n.tutorialStartButton,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSkip,
                child: Text(
                  skipLabel ?? l10n.tutorialSkipButton,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «No volver a mostrar»: checkbox plus label, the whole row is one tap
/// target of at least 48 dp (the visible checkbox is smaller).
class _DontShowAgainRow extends StatelessWidget {
  const _DontShowAgainRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    return MergeSemantics(
      // Transparent Material: the ripple paints over the card, not under it.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('prompt-dont-show-again'),
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: value,
                    onChanged: (checked) => onChanged(checked ?? false),
                    activeColor: palette.primary,
                    checkColor: palette.onPrimary,
                    side: BorderSide(color: palette.textMuted, width: 1.5),
                  ),
                  Flexible(
                    child: Text(
                      l10n.promptDontShowAgain,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
