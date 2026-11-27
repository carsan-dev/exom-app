import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Single switch for reduced effects in EXOM.
///
/// Decision D8 (approved 2026-11-18, applied in redesign L2) separates two
/// questions that used to be one:
///
/// * [prefersReducedMotion]: the user asked for less motion
///   (`MediaQuery.disableAnimations` or `accessibleNavigation`). Only this
///   governs animation durations and scale/translate effects
///   ([animationDuration], `ExomMotion.of`).
/// * [prefersEconomyRendering]: the screen is narrow (`shortestSide <= 360`),
///   used as a proxy for a low-capability device. Only this governs the
///   size-related economy measures ([imageCacheWidth], [scrollCacheExtent]).
///
/// [prefersReducedEffects] keeps its historical meaning (either of the two)
/// for source compatibility; it now only drives [blurSigma].
class PerformanceProfile {
  const PerformanceProfile._();

  static const double _economyShortestSide = 360;

  /// True when the platform asks for reduced motion.
  static bool prefersReducedMotion(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    return media.disableAnimations || media.accessibleNavigation;
  }

  /// True on narrow screens (`shortestSide <= 360`): smaller image decode
  /// widths and scroll cache. Never affects motion.
  static bool prefersEconomyRendering(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    return media.size.shortestSide <= _economyShortestSide;
  }

  /// Legacy union of [prefersReducedMotion] and [prefersEconomyRendering].
  /// Prefer the specific getters in new code.
  static bool prefersReducedEffects(BuildContext context) {
    return prefersReducedMotion(context) || prefersEconomyRendering(context);
  }

  /// [duration], or zero when the user prefers reduced motion.
  static Duration animationDuration(BuildContext context, Duration duration) {
    return prefersReducedMotion(context) ? Duration.zero : duration;
  }

  /// Blur radius capped at 12, or zero with reduced effects. The V4 shared
  /// widgets no longer blur; kept for API compatibility.
  static double blurSigma(BuildContext context, double sigma) {
    return prefersReducedEffects(context) ? 0 : math.min(sigma, 12);
  }

  static int imageCacheWidth(BuildContext context, double logicalWidth) {
    final media = MediaQuery.maybeOf(context);
    final devicePixelRatio = media?.devicePixelRatio ?? 2;
    final width = (logicalWidth * devicePixelRatio).ceil();
    final maxWidth = prefersEconomyRendering(context) ? 640 : 960;
    return width.clamp(96, maxWidth).toInt();
  }

  static double scrollCacheExtent(BuildContext context) {
    return prefersEconomyRendering(context) ? 320 : 640;
  }
}
