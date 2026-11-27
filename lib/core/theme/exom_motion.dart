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

  // --- L5 motion patterns (contract T0.5, ESPEC §4). Curves: what enters uses
  // [sheetEnterCurve] (except the M1 push, L5-D35), what leaves
  // [sheetExitCurve], in-place changes ease-out.
  // Rules for every pattern: no animation delays the action (the tap acts at
  // once and the motion accompanies it), every animation is interruptible,
  // and nothing but the milestone lasts more than [ordinaryMax].

  /// Longest ordinary animation (the milestone and the launch are apart).
  static const Duration ordinaryMax = Duration(milliseconds: 600);

  // M1 Push and back: the new screen enters [pushOffset] from the advance side
  // with a fade in [pushIn]; the previous one dims to [pushPreviousOpacity].
  // Back is the inverse in [pushOut]. Reduced: a [reducedScreen] fade. Wired
  // on Android through `ExomPushPageTransitionsBuilder` in the app theme; iOS
  // keeps the Cupertino transition and its back gesture.
  static const Duration pushIn = screen;
  static const Duration pushOut = Duration(milliseconds: 200);
  static const double pushOffset = 24;
  static const double pushPreviousOpacity = 0.6;
  // L5-D35 (owner, 2026-11-20): the push enters on easeOutCubic instead of
  // [sheetEnterCurve] to spread the motion, so a frame dropped while the new
  // screen is first rastered shows less. The sheet and the other entering
  // patterns keep [sheetEnterCurve].
  static const Curve pushEnterCurve = Curves.easeOutCubic;
  static const Curve pushExitCurve = sheetExitCurve;

  // M2 Tab change: crossfade without offset, the old tab leaves in
  // [tabFadeOut] while the new one enters in [tabFadeIn]; the active bar of
  // the bottom navigation slides in [navIndicatorSlide]. Reduced: cut.
  static const Duration tabFadeOut = Duration(milliseconds: 60);
  static const Duration tabFadeIn = Duration(milliseconds: 100);
  static const Duration navIndicatorSlide = Duration(milliseconds: 200);
  static const Curve navIndicatorCurve = Curves.easeOut;

  // M3 Content arrival (`ExomArrival`): skeleton to content in [arrivalFade];
  // the first [arrivalRiseRows] rows rise [arrivalRise] staggered by
  // [arrivalStagger]. First load only, never on refresh. Reduced: 120 ms fade.
  static const Duration arrivalFade = chipCrossfade;
  static const double arrivalRise = 8;
  static const Duration arrivalStagger = Duration(milliseconds: 30);
  static const int arrivalRiseRows = 6;
  static const Curve arrivalCurve = sheetEnterCurve;

  // M4 In-place change: `AnimatedSwitcher` crossfade of icon and text in
  // [inPlaceSwitch]; a selection (calendar day, segment, chip) slides its fill
  // in [selectionSlide]. Reduced: 120 ms fade.
  static const Duration inPlaceSwitch = chipCrossfade;
  static const Duration selectionSlide = Duration(milliseconds: 200);
  static const Curve inPlaceCurve = Curves.easeOut;

  // M5 Progress and figures: bars grow in [growBar] (`ExomGrowBar`; an upload
  // follows its bytes linearly); percentages count up in [countUp] the first
  // time they appear (`ExomCountUp`). Reduced: final value directly.
  static const Duration growBar = Duration(milliseconds: 300);
  static const Curve growBarCurve = Curves.easeOut;
  static const Duration countUp = milestoneCount;
  static const Curve countUpCurve = Curves.easeOut;

  // M5 Streak weeks grid: each lit square takes [streakSquareFill] to go from
  // the rule tone to the data colour, overlapping its neighbours so the
  // whole grid reads as one wave over [countUp] (`ChallengeStreakWeeks`).
  static const Duration streakSquareFill = Duration(milliseconds: 300);

  // M6 Press: [pressIn]/[pressOut] at [pressScale] (`TappableScale` and the
  // `Exom*Button`s); rows switch to the raised fill at once. Reduced:
  // [reducedPressOpacity].

  // M7 Expand and collapse (the `ExomAccordion` widget arrives in T0.3a):
  // height in [expandHeight] ease-out, the chevron turns
  // [expandChevronTurns] (180°), the content fades in [expandContentFade].
  // Reduced: no animated height; fade.
  static const Duration expandHeight = Duration(milliseconds: 200);
  static const Curve expandCurve = Curves.easeOut;
  static const double expandChevronTurns = 0.5;
  static const Duration expandContentFade = reducedFade;

  // M8 Immediate response (pattern, not a widget): switches, "mark as read",
  // chips and selection change the UI in under 100 ms, before the network
  // call; if the server fails they go back to the previous state and say so
  // with an inline message (`ExomInlineMessage`, T0.2). The same in reduced
  // motion. Never imply remote success before it is confirmed.

  // M9 Form step (`ExomStepTransition`): the new step enters [stepOffset]
  // from the side it advances to, in [step]; the progress rule fills its
  // segment in [stepProgressRule]. Reduced: 100 ms fade; the rule jumps.
  static const Duration step = screen;
  // The step that leaves fades out in [stepExit] (the same reduced).
  static const Duration stepExit = Duration(milliseconds: 100);
  static const double stepOffset = 24;
  static const Curve stepCurve = sheetEnterCurve;
  // M9 push (`ExomStepTransitionStyle.slide`, recap form and onboarding,
  // L5-C5b): the step that leaves moves fully out to one side while the new
  // one enters from the other, both opaque, in [stepSlide] on
  // [stepSlideCurve] (norms 6 and 9). Reduced: the 100 ms fade above.
  static const Duration stepSlide = Duration(milliseconds: 280);
  static const Curve stepSlideCurve = Curves.easeInOutCubic;
  static const Duration stepProgressRule = growBar;
  static const Curve stepProgressRuleCurve = Curves.easeOut;

  // Month change of Calendario (L5-A4c, sketch `a-diario.html#calendario`):
  // the grid, the month title and the protagonist figure move as an M9 step
  // ([step], [stepOffset], [stepCurve] in, [sheetExitCurve] out; towards the
  // start when the month advances) and the selected day's fill slides in
  // [selectionSlide]. While the next month loads the previous one stays on
  // screen; if the load lasts longer than [busyIndicatorDelay] a discreet
  // `ExomOperationBar` appears over it, so a fast load never flashes it. The
  // delay is the same with reduced motion (it is not an animation).
  static const Duration busyIndicatorDelay = Duration(milliseconds: 400);

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
    required this.pushSlides,
    required this.pushIn,
    required this.pushOut,
    required this.pushOffset,
    required this.pushPreviousOpacity,
    required this.tabFades,
    required this.tabFadeIn,
    required this.tabFadeOut,
    required this.navIndicatorSlide,
    required this.arrivalFade,
    required this.arrivalRise,
    required this.arrivalStagger,
    required this.inPlaceSwitch,
    required this.selectionSlides,
    required this.selection,
    required this.growBar,
    required this.countUp,
    required this.expandAnimatesHeight,
    required this.expandHeight,
    required this.expandChevron,
    required this.expandContentFade,
    required this.stepSlides,
    required this.step,
    required this.stepOffset,
    required this.stepProgressRule,
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
    pushSlides: true,
    pushIn: ExomMotion.pushIn,
    pushOut: ExomMotion.pushOut,
    pushOffset: ExomMotion.pushOffset,
    pushPreviousOpacity: ExomMotion.pushPreviousOpacity,
    tabFades: true,
    tabFadeIn: ExomMotion.tabFadeIn,
    tabFadeOut: ExomMotion.tabFadeOut,
    navIndicatorSlide: ExomMotion.navIndicatorSlide,
    arrivalFade: ExomMotion.arrivalFade,
    arrivalRise: ExomMotion.arrivalRise,
    arrivalStagger: ExomMotion.arrivalStagger,
    inPlaceSwitch: ExomMotion.inPlaceSwitch,
    selectionSlides: true,
    selection: ExomMotion.selectionSlide,
    growBar: ExomMotion.growBar,
    countUp: ExomMotion.countUp,
    expandAnimatesHeight: true,
    expandHeight: ExomMotion.expandHeight,
    expandChevron: ExomMotion.expandHeight,
    expandContentFade: ExomMotion.expandContentFade,
    stepSlides: true,
    step: ExomMotion.step,
    stepOffset: ExomMotion.stepOffset,
    stepProgressRule: ExomMotion.stepProgressRule,
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
    pushSlides: false,
    pushIn: ExomMotion.reducedScreen,
    pushOut: ExomMotion.reducedScreen,
    pushOffset: 0,
    pushPreviousOpacity: 1,
    tabFades: false,
    tabFadeIn: Duration.zero,
    tabFadeOut: Duration.zero,
    navIndicatorSlide: Duration.zero,
    arrivalFade: ExomMotion.reducedFade,
    arrivalRise: 0,
    arrivalStagger: Duration.zero,
    inPlaceSwitch: ExomMotion.reducedFade,
    selectionSlides: false,
    selection: ExomMotion.reducedFade,
    growBar: Duration.zero,
    countUp: Duration.zero,
    expandAnimatesHeight: false,
    expandHeight: Duration.zero,
    expandChevron: Duration.zero,
    expandContentFade: ExomMotion.reducedFade,
    stepSlides: false,
    step: ExomMotion.reducedScreen,
    stepOffset: 0,
    stepProgressRule: Duration.zero,
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

  /// M1: false in reduced mode (fade only, no offset, no dimming).
  final bool pushSlides;
  final Duration pushIn;
  final Duration pushOut;
  final double pushOffset;

  /// M1: opacity the covered screen dims to (1 in reduced mode).
  final double pushPreviousOpacity;

  /// M2: false in reduced mode (cut).
  final bool tabFades;
  final Duration tabFadeIn;
  final Duration tabFadeOut;
  final Duration navIndicatorSlide;

  /// M3: fade of the content; [arrivalRise] and [arrivalStagger] are zero in
  /// reduced mode.
  final Duration arrivalFade;
  final double arrivalRise;
  final Duration arrivalStagger;

  /// M4: crossfade in place; the selection slides its fill unless reduced
  /// ([selectionSlides] false: it fades in [selection]).
  final Duration inPlaceSwitch;
  final bool selectionSlides;
  final Duration selection;

  /// M5: zero in reduced mode (final value directly).
  final Duration growBar;
  final Duration countUp;

  /// M7: no animated height in reduced mode; the content still fades.
  final bool expandAnimatesHeight;
  final Duration expandHeight;
  final Duration expandChevron;
  final Duration expandContentFade;

  /// M9: false in reduced mode (fade only); the progress rule jumps.
  final bool stepSlides;
  final Duration step;
  final double stepOffset;
  final Duration stepProgressRule;
}
