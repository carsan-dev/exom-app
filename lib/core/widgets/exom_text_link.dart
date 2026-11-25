import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Underlined text link of the L5 redesign (`.x-link`, `.x-err`): DM Sans 14 /
/// 600 in the text colour with a 1.5 px underline in the data colour. With
/// [danger] both text and underline use the error colour. A null [onTap]
/// renders it disabled.
///
/// The touch target is at least 48 x 48 even when the label is short; the
/// visible text is smaller. Assistive technology gets one node that is both a
/// link and a button with the label as text. The label wraps, never ellipsised.
///
/// An optional [icon] (L5-E5, e.g. play for «Ver técnica» with a video) goes
/// before the label in the link ink; it is decorative (the label is what is
/// read). Without it the link is exactly as before.
class ExomTextLink extends StatelessWidget {
  const ExomTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final IconData? icon;

  /// Icon size next to the 14 px label (1.3 em, as [ExomKicker]'s icon).
  static const double _iconSize = 18;

  /// Minimum touch target on each axis (plan §2 and §11).
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final enabled = onTap != null;
    final Color ink = !enabled
        ? palette.textDisabled
        : danger
        ? palette.error
        : palette.textPrimary;
    final Color underline = !enabled
        ? palette.textDisabled
        : danger
        ? palette.error
        : palette.data;
    final iconData = icon;
    final text = Text(
      label,
      style: TextStyle(
        fontFamily: AppTheme.bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: ink,
        decoration: TextDecoration.underline,
        decorationColor: underline,
        decorationThickness: 1.5,
      ),
    );
    return Semantics(
      link: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: minTarget,
              minHeight: minTarget,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
              child: Center(
                widthFactor: 1,
                child: iconData == null
                    ? text
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconData, size: _iconSize, color: ink),
                          const SizedBox(width: 6),
                          Flexible(child: text),
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
