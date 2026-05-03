import 'dart:math' as math;

import 'package:flutter/material.dart';

class PerformanceProfile {
  const PerformanceProfile._();

  static bool prefersReducedEffects(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;

    final shortestSide = media.size.shortestSide;
    final lowWidthBudget = shortestSide <= 360;
    return media.disableAnimations ||
        media.accessibleNavigation ||
        lowWidthBudget;
  }

  static Duration animationDuration(
    BuildContext context,
    Duration duration,
  ) {
    return prefersReducedEffects(context) ? Duration.zero : duration;
  }

  static double blurSigma(BuildContext context, double sigma) {
    return prefersReducedEffects(context) ? 0 : math.min(sigma, 12);
  }

  static int imageCacheWidth(BuildContext context, double logicalWidth) {
    final media = MediaQuery.maybeOf(context);
    final devicePixelRatio = media?.devicePixelRatio ?? 2;
    final width = (logicalWidth * devicePixelRatio).ceil();
    final maxWidth = prefersReducedEffects(context) ? 640 : 960;
    return width.clamp(96, maxWidth).toInt();
  }

  static double scrollCacheExtent(BuildContext context) {
    return prefersReducedEffects(context) ? 320 : 640;
  }
}
