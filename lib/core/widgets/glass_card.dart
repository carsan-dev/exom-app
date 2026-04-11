import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';

/// Simulated glass card widget (no BackdropFilter — performant for lists).
///
/// Replaces the common pattern of `Container(decoration: BoxDecoration(color: palette.surface...))`.
/// Uses semi-transparent fill + subtle gradient + luminous border + soft shadow.
///
/// When `onTap` is provided the card animates (scale + selection haptic) on
/// press — no more Material ripple on top of the glass surface.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 20,
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
    final decoration = accentColor != null
        ? GlassDecoration.accentCard(accentColor!, borderRadius: borderRadius)
        : elevated
            ? GlassDecoration.elevated(borderRadius: borderRadius)
            : GlassDecoration.card(borderRadius: borderRadius);

    final container = Container(
      margin: margin,
      decoration: decoration,
      child: Padding(
        padding: padding,
        child: child,
      ),
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
