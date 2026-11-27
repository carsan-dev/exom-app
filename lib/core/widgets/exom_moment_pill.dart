import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:flutter/material.dart';

/// Moment pill, e.g. «Hoy» (`.x-pill`): lime fill ([ExomThemePalette.limeFill])
/// with carbon ink ([ExomThemePalette.onLimeFill]), DM Sans 600 14 px in upper
/// case with .08 em tracking, at least 32 px tall. In the light theme it gets a
/// 1.5 px outline ([ExomThemePalette.limeFillOutline]) so the lime fill reads
/// against the bone background (D13). One per screen, never in the lower third:
/// the screen guarantees that.
///
/// Only the painted text is upper case; assistive technology reads [label] as
/// given. The pill is as wide as its content, not stretched by the parent.
class ExomMomentPill extends StatelessWidget {
  const ExomMomentPill(this.label, {super.key});

  final String label;

  /// `.x-pill` corner radius (2 px in the sketch; no [ExomRadius] token has it).
  static const double _radius = 2;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final outline = palette.limeFillOutline;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.limeFill,
            borderRadius: BorderRadius.circular(_radius),
          ),
          position: DecorationPosition.background,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: outline == null
                  ? null
                  : Border.all(color: outline, width: ExomRule.outline),
            ),
            position: DecorationPosition.foreground,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.6,
                  vertical: 4.9,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: 14 * 0.08,
                      color: palette.onLimeFill,
                    ),
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
