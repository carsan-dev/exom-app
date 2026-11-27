import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Screen background (V4, redesign L2): the flat theme background colour in
/// both themes. The former brown/beige gradient and veil are gone.
///
/// The child is expanded to fill the available space, as before.
/// [intensity] is kept for API compatibility and has no visual effect.
class ExomStaticBackground extends StatelessWidget {
  const ExomStaticBackground({
    super.key,
    required this.child,
    this.intensity = 1,
  });

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return _FlatBackground(paintBase: true, child: child);
  }
}

/// Former animated background of the splash. In V4 it paints the same flat
/// background as [ExomStaticBackground] and runs no animation (so it costs no
/// frames). The constructor is unchanged: [intensity] and [showVeil] have no
/// visual effect; [showBase] false leaves the background transparent so the
/// parent's colour shows through, as before.
class ExomAnimatedBackground extends StatelessWidget {
  const ExomAnimatedBackground({
    super.key,
    required this.child,
    this.intensity = 1,
    this.showBase = true,
    this.showVeil = true,
  });

  final Widget child;
  final double intensity;
  final bool showBase;
  final bool showVeil;

  @override
  Widget build(BuildContext context) {
    return _FlatBackground(paintBase: showBase, child: child);
  }
}

class _FlatBackground extends StatelessWidget {
  const _FlatBackground({required this.paintBase, required this.child});

  final bool paintBase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (paintBase) ColoredBox(color: context.exomPalette.background),
        child,
      ],
    );
  }
}
