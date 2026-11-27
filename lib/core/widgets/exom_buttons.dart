import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Minimum height of the primary and secondary buttons (plan §6).
const double kExomButtonMinHeight = 56;

/// Foreground of the enabled primary (lime) button, for what leaves it.
const Color kExomPrimaryForeground = AppColors.textOnPrimary;

/// Minimum tap target of every EXOM control (plan §6).
const double kExomMinTapTarget = 48;

const double _radius = 4;

TextStyle _labelStyle(Color color, {double letterSpacing = 0.32}) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  height: 1.2,
  letterSpacing: letterSpacing,
  color: color,
);

/// Primary action of a state ("the next step"): lime fill, carbon label.
///
/// Sketch «A · Ejercicio activo»: uppercase label on the left and optional
/// [trailingIcon] on the right, min height 56, radius 4, DM Sans 600 16. In
/// the light theme it carries a 1.5 px carbon border (lime on bone is never
/// text, only fill). Only one primary button per state (plan §6).
///
/// Press feedback is [TappableScale] (scale .97, or opacity only with reduced
/// motion); the action fires on tap and is never delayed by the animation.
///
/// While [busy] the button keeps its fill, shows a progress indicator in the
/// trailing slot and ignores every tap, so a repeated tap can never start a
/// second operation (plan §8a). Screen readers hear the localized
/// `buttonBusyA11y` value («En curso») besides the disabled state. With [onPressed] null it is disabled. The label
/// wraps onto several lines instead of clipping at large text sizes.
class ExomPrimaryButton extends StatelessWidget {
  const ExomPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.busy = false,
    this.semanticLabel,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final bool busy;

  /// Replaces the static [trailingIcon] in its 22 px slot (for example an
  /// icon that animates); an [Icon] inside takes the size and colour of the
  /// label. Null keeps the [trailingIcon]; [busy] still shows the progress
  /// indicator instead.
  final Widget? trailing;

  /// Overrides the accessible label (defaults to [label] in its original
  /// case; only the painted label is uppercase).
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onPressed == null;
    final fill = disabled ? palette.borderSoft : AppColors.primary;
    final foreground = disabled
        ? (isDark ? palette.textDisabled : palette.textSecondary)
        : kExomPrimaryForeground;

    final Widget? trailingSlot = busy
        ? ExcludeSemantics(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            ),
          )
        : trailing != null
        ? IconTheme.merge(
            data: IconThemeData(size: 22, color: foreground),
            child: SizedBox.square(dimension: 22, child: trailing),
          )
        : trailingIcon == null
        ? null
        : Icon(trailingIcon, size: 22, color: foreground);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_radius),
        border: isDark
            ? null
            : Border.all(color: AppColors.textOnPrimary, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: kExomButtonMinHeight,
          minWidth: double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: _labelStyle(foreground),
                ),
              ),
              if (trailingSlot != null) ...[
                const SizedBox(width: 12),
                trailingSlot,
              ],
            ],
          ),
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        container: true,
        button: true,
        enabled: _enabled,
        // The original case: the painted label is uppercase only for looks,
        // and some screen readers spell short uppercase words as acronyms.
        label: semanticLabel ?? label,
        // While busy, screen readers hear "in progress" and not only
        // "disabled".
        value: busy ? AppLocalizations.of(context).buttonBusyA11y : null,
        excludeSemantics: true,
        child: TappableScale.light(
          enabled: _enabled,
          onTap: _enabled ? onPressed : null,
          child: surface,
        ),
      ),
    );
  }
}

/// Secondary action: outlined with a 1.5 px `text` border, transparent fill,
/// sentence-case label (sketch `.btn-out`). Min height 56, radius 4. Optional
/// leading [icon]. Same press feedback and disabled rules as
/// [ExomPrimaryButton].
class ExomSecondaryButton extends StatelessWidget {
  const ExomSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.labelKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Key of the label `Text` (the tutorial locates it by key).
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final enabled = onPressed != null;
    final colour = enabled ? palette.textPrimary : palette.textDisabled;
    return MergeSemantics(
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        child: TappableScale(
          enabled: enabled,
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: enabled ? palette.textPrimary : palette.borderSoft,
                width: 1.5,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kExomButtonMinHeight,
                minWidth: double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 22, color: colour),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        key: labelKey,
                        textAlign: TextAlign.center,
                        style: _labelStyle(colour),
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
}

/// Quiet action ("Cancelar", "Saltar descanso"): underlined `text`-coloured
/// label without a box (sketch `.btn-quiet`), tap target at least 48x48.
class ExomQuietButton extends StatelessWidget {
  const ExomQuietButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final enabled = onPressed != null;
    final colour = enabled ? palette.textPrimary : palette.textDisabled;
    return MergeSemantics(
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        child: TappableScale(
          enabled: enabled,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kExomMinTapTarget,
              minWidth: kExomMinTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _labelStyle(colour, letterSpacing: 0).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: colour,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
