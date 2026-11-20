import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:flutter/material.dart';

/// Small label above content (`.x-k`): [ExomType.kicker] in upper case and the
/// secondary text colour, with an optional icon in the primary text colour
/// (1.3 em, 0.4 em gap).
///
/// Only the painted text is upper case: assistive technology reads [text] in
/// its original case; the icon is decorative. The text wraps, never ellipsised.
class ExomKicker extends StatelessWidget {
  const ExomKicker(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final fontSize = ExomType.kicker.fontSize!;
    final iconData = icon;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (iconData != null) ...[
            Icon(iconData, size: fontSize * 1.3, color: palette.textPrimary),
            SizedBox(width: fontSize * 0.4),
          ],
          Flexible(
            child: Text(
              text.toUpperCase(),
              style: ExomType.kicker.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
