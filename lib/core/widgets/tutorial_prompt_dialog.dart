import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Automatic prompt card over a dimmed scrim. By default it is the quick-tour
/// prompt; the optional parameters reuse the same card for other automatic
/// prompts (Sunday recap reminder) and add the «No volver a mostrar» row.
///
/// L5-F3 (f-resto.html, frame `f3-aviso`), only when [redesigned] is true (the
/// quick-tour prompt): a flat dialog of radius 4 with a 1 px rule and no
/// shadow, 20 from the screen edges and centred; the title in Barlow 28
/// painted upper case, the sentence in the secondary colour at 16, the lime
/// action («Empezar guía») as the only lime and «Omitir» as a quiet underlined
/// action. The redesigned card paints [icon] only when it is non-null; the
/// tour passes none. The card scrolls when it does not fit (large text, short
/// screens).
///
/// By default ([redesigned] false) the card is exactly the C5b one (radius 28,
/// shadow, centred copy, [icon] defaulting to [ExomIcons.explore]); the Sunday
/// recap reminder shares it and keeps that look.
class TutorialPromptDialog extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSkip;

  /// Icon in a circle above the title. Defaults to [ExomIcons.explore]; null
  /// paints none (only meaningful with [redesigned]).
  final IconData? icon;

  /// Paints the L5-F3 flat card. False keeps the previous look untouched.
  final bool redesigned;

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
    this.redesigned = false,
    this.title,
    this.description,
    this.startLabel,
    this.skipLabel,
    this.dontShowAgain = false,
    this.onDontShowAgainChanged,
  });

  @override
  Widget build(BuildContext context) =>
      redesigned ? _buildRedesigned(context) : _buildLegacy(context);

  /// The L5-F3 flat card.
  Widget _buildRedesigned(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final titleText = title ?? l10n.tutorialPromptTitle;
    final iconData = icon;

    return Material(
      // Same scrim as the EXOM sheets and the Material dialogs.
      color: ExomSheetRoute.scrimColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            child: DecoratedBox(
              key: const Key('tutorial-prompt-card'),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(ExomRadius.control),
                border: Border.all(
                  color: palette.borderSoft,
                  width: ExomRule.hairline,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (iconData != null) ...[
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: palette.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData,
                            color: palette.primary,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Painted upper case; screen readers hear the original.
                    Semantics(
                      header: true,
                      label: titleText,
                      excludeSemantics: true,
                      child: Text(
                        titleText.toUpperCase(),
                        style: ExomType.headline2Section.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      description ?? l10n.tutorialPromptDescription,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFontFamily,
                        color: palette.textSecondary,
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                    if (onDontShowAgainChanged case final onChanged?) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _DontShowAgainRow(
                          value: dontShowAgain,
                          onChanged: onChanged,
                          redesigned: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else
                      const SizedBox(height: 20),
                    ExomPrimaryButton(
                      label: startLabel ?? l10n.tutorialStartButton,
                      trailingIcon: ExomIcons.forward,
                      onPressed: onStart,
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: ExomQuietButton(
                        label: skipLabel ?? l10n.tutorialSkipButton,
                        onPressed: onSkip,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // L5-F3 r2 legacy: the C5b card below, shared with the Sunday recap
  // reminder; kept exactly as before the repaint.
  /// The C5b card, as before L5-F3.
  Widget _buildLegacy(BuildContext context) {
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
            border: Border.all(color: palette.borderSoft, width: 0.5),
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
                child: Icon(icon, color: palette.primary, size: 32),
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
                _DontShowAgainRow(
                  value: dontShowAgain,
                  onChanged: onChanged,
                  redesigned: false,
                ),
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
                  style: TextStyle(color: palette.textMuted, fontSize: 14),
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
  const _DontShowAgainRow({
    required this.value,
    required this.onChanged,
    required this.redesigned,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// The L5-F3 card uses the control radius and the body font; the previous
  /// one keeps radius 14 and the default font.
  final bool redesigned;

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
          borderRadius: BorderRadius.circular(
            redesigned ? ExomRadius.control : 14,
          ),
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
                        fontFamily: redesigned ? AppTheme.bodyFontFamily : null,
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
