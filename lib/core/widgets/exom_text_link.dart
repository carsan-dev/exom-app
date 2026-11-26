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
/// An optional [icon] (L5-E5, e.g. play for «Ver técnica» with a video; L5-F1
/// camera and image icons) goes before the label in the link ink; it is
/// decorative (the label is what is read). An optional [semanticsLabel]
/// (L5-F1) replaces the spoken label when the visible one is a short form;
/// null reads [label]. Without them the link is exactly as before.
class ExomTextLink extends StatelessWidget {
  const ExomTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.icon,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final IconData? icon;

  /// Icon size next to the 14 px label at 1.0x (1.3 em, as [ExomKicker]'s
  /// icon); it scales with the label (L5-F1 r2).
  static const double _iconSize = 18;

  /// Gap between icon and label at 1.0x; it scales with the label.
  static const double _iconGap = 6;

  /// Spoken label; defaults to [label].
  final String? semanticsLabel;

  /// Minimum touch target on each axis (plan §2 and §11).
  static const double minTarget = 48;

  static const double _fontSize = 14;

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
    // The icon and its gap follow the label's effective scale (the label
    // grows with the user's text size, so a fixed icon would shrink beside
    // it). At 1.0x this is exactly 1, keeping 18 px and 6 px.
    final scale = MediaQuery.textScalerOf(context).scale(_fontSize) / _fontSize;
    final text = Text(
      label,
      style: TextStyle(
        fontFamily: AppTheme.bodyFontFamily,
        fontSize: _fontSize,
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
      label: semanticsLabel ?? label,
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
                          Icon(iconData, size: _iconSize * scale, color: ink),
                          SizedBox(width: _iconGap * scale),
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
