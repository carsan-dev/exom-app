import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';

/// Simulated glass card widget (no BackdropFilter — performant for lists).
///
/// Replaces the common pattern of `Container(decoration: BoxDecoration(color: palette.surface...))`.
/// Uses semi-transparent fill + subtle gradient + luminous border + soft shadow.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 20,
    this.accentColor,
    this.onTap,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double borderRadius;
  final Color? accentColor;
  final VoidCallback? onTap;
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

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}
