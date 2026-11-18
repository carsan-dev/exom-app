import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:flutter/widgets.dart';

/// Motion tokens of the EXOM redesign (plan `rediseno-exom-app.md` §7-§8).
///
/// Every ordinary transition is <= 300 ms and interruptible. Widgets should not
/// read these constants directly when the value depends on the user's motion
/// preference: use [ExomMotion.of], which returns the reduced variant when
/// [PerformanceProfile.prefersReducedMotion] is true (decision D8: a narrow
/// screen alone does not reduce motion).
abstract final class ExomMotion {
  // a) Tocar registrar: scale 1 -> .97, 80 ms ease-out in, 120 ms out.
  static const Duration pressIn = Duration(milliseconds: 80);
  static const Duration pressOut = Duration(milliseconds: 120);
  static const Curve pressCurve = Curves.easeOut;
  static const double pressScale = 0.97;

  /// Reduced press feedback: no scale, only this opacity while pressed.
  static const double reducedPressOpacity = 0.8;

  // b) Abrir y cerrar una hoja.
  static const Duration sheetEnter = Duration(milliseconds: 280);
  static const Curve sheetEnterCurve = Cubic(0.22, 0.75, 0.18, 1);
  static const Duration scrim = Duration(milliseconds: 200);
  static const Curve scrimCurve = Curves.linear;
  static const Duration sheetExit = Duration(milliseconds: 200);
  static const Curve sheetExitCurve = Cubic(0.4, 0, 1, 1);

  /// Secondary action: set chip crossfade (principle 8).
  static const Duration chipCrossfade = Duration(milliseconds: 160);

  /// Screen transitions (principle 9).
  static const Duration screen = Duration(milliseconds: 240);
  static const Curve screenCurve = Curves.easeOut;

  // c) Terminar la sesión (milestone).
  static const Duration milestoneBand = Duration(milliseconds: 450);
  static const Curve milestoneBandCurve = sheetEnterCurve;
  static const Duration milestoneLetterStagger = Duration(milliseconds: 40);
  static const Duration milestoneCount = Duration(milliseconds: 600);
  static const Curve milestoneCountCurve = Curves.easeOut;
  static const Duration milestoneMax = Duration(milliseconds: 900);

  /// The "back home" button of the milestone is tappable from this point.
  static const Duration milestoneInteractiveAfter = Duration(milliseconds: 300);

  // Reduced motion variants.
  static const Duration reducedFade = Duration(milliseconds: 120);
  static const Duration reducedScreen = Duration(milliseconds: 100);
  static const Duration reducedMilestone = Duration(milliseconds: 150);

  /// Resolves the motion spec for [context] through [PerformanceProfile].
  static ExomMotionSpec of(BuildContext context) {
    return resolve(reduced: PerformanceProfile.prefersReducedMotion(context));
  }

  /// Pure resolver, for tests and non-widget callers.
  static ExomMotionSpec resolve({required bool reduced}) {
    return reduced ? ExomMotionSpec.reduced : ExomMotionSpec.standard;
  }
}

/// Resolved motion values for one motion preference.
@immutable
class ExomMotionSpec {
  const ExomMotionSpec._({
    required this.isReduced,
    required this.pressScale,
    required this.pressOpacity,
    required this.pressIn,
    required this.pressOut,
    required this.pressCurve,
    required this.sheetSlides,
    required this.sheetEnter,
    required this.sheetEnterCurve,
    required this.sheetExit,
    required this.sheetExitCurve,
    required this.scrim,
    required this.chipCrossfade,
    required this.screenSlides,
    required this.screen,
    required this.screenCurve,
    required this.milestoneBand,
    required this.milestoneCount,
    required this.milestoneTotal,
  });

  /// Full motion.
  static const ExomMotionSpec standard = ExomMotionSpec._(
    isReduced: false,
    pressScale: ExomMotion.pressScale,
    pressOpacity: 1,
    pressIn: ExomMotion.pressIn,
    pressOut: ExomMotion.pressOut,
    pressCurve: ExomMotion.pressCurve,
    sheetSlides: true,
    sheetEnter: ExomMotion.sheetEnter,
    sheetEnterCurve: ExomMotion.sheetEnterCurve,
    sheetExit: ExomMotion.sheetExit,
    sheetExitCurve: ExomMotion.sheetExitCurve,
    scrim: ExomMotion.scrim,
    chipCrossfade: ExomMotion.chipCrossfade,
    screenSlides: true,
    screen: ExomMotion.screen,
    screenCurve: ExomMotion.screenCurve,
    milestoneBand: ExomMotion.milestoneBand,
    milestoneCount: ExomMotion.milestoneCount,
    milestoneTotal: ExomMotion.milestoneMax,
  );

  /// Reduced motion: no scale or translate; fades of at most 120 ms; screens
  /// 100 ms; the milestone becomes a 150 ms crossfade to the final values.
  static const ExomMotionSpec reduced = ExomMotionSpec._(
    isReduced: true,
    pressScale: 1,
    pressOpacity: ExomMotion.reducedPressOpacity,
    pressIn: ExomMotion.pressIn,
    pressOut: ExomMotion.pressOut,
    pressCurve: Curves.linear,
    sheetSlides: false,
    sheetEnter: ExomMotion.reducedFade,
    sheetEnterCurve: Curves.linear,
    sheetExit: ExomMotion.reducedFade,
    sheetExitCurve: Curves.linear,
    scrim: ExomMotion.reducedFade,
    chipCrossfade: ExomMotion.reducedFade,
    screenSlides: false,
    screen: ExomMotion.reducedScreen,
    screenCurve: Curves.linear,
    milestoneBand: Duration.zero,
    milestoneCount: Duration.zero,
    milestoneTotal: ExomMotion.reducedMilestone,
  );

  final bool isReduced;
  final double pressScale;
  final double pressOpacity;
  final Duration pressIn;
  final Duration pressOut;
  final Curve pressCurve;

  /// False in reduced mode: sheets fade instead of sliding.
  final bool sheetSlides;
  final Duration sheetEnter;
  final Curve sheetEnterCurve;
  final Duration sheetExit;
  final Curve sheetExitCurve;
  final Duration scrim;
  final Duration chipCrossfade;
  final bool screenSlides;
  final Duration screen;
  final Curve screenCurve;
  final Duration milestoneBand;
  final Duration milestoneCount;
  final Duration milestoneTotal;
}
