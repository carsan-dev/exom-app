import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';

/// Flat V4 panel (redesign L2). The name is kept for source compatibility:
/// there is no glass any more.
///
/// Paints the theme `panel` colour (`surface`, or `surfaceElevated` when
/// [elevated]) with a 1 px `rule` border and no shadow. The V4 default radius
/// is 0; callers that pass an explicit [borderRadius] keep it, and [padding] and
/// [margin] behave as before. [accentColor] no longer tints the card (flat
/// system); it is kept for API compatibility.
///
/// When `onTap` or `onLongPress` is provided the card gets the shared press
/// feedback of [TappableScale] (scale .97, or opacity only with reduced motion).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 0,
    this.accentColor,
    this.onTap,
    this.onLongPress,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double borderRadius;
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final decoration = BoxDecoration(
      // As before L2, an accent card is a plain panel even when [elevated].
      color: elevated && accentColor == null
          ? palette.surfaceElevated
          : palette.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: palette.borderSoft, width: 1),
    );

    final container = Container(
      margin: margin,
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null || onLongPress != null) {
      return TappableScale(
        onTap: onTap,
        onLongPress: onLongPress,
        child: container,
      );
    }

    return container;
  }
}
