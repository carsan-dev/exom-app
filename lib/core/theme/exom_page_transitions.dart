import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// M1 (push and back) for Android, installed in the app theme's
/// [PageTransitionsTheme]. It covers every `MaterialPage` / `MaterialPageRoute`
/// of the app at once: `_platformPage` on Android, the router's `builder`
/// routes and the direct `Navigator.push(MaterialPageRoute(...))` calls.
///
/// iOS keeps [CupertinoPageTransitionsBuilder] (its transition and back
/// swipe, risk R3 of the L5 contract).
///
/// The route durations are fixed ([ExomMotion.pushIn] / [ExomMotion.pushOut])
/// because a [PageTransitionsBuilder] has no context for them; with reduced
/// motion [ExomPushTransition] completes its fade within the first
/// [ExomMotionSpec.pushIn] / [ExomMotionSpec.pushOut] of that time.
class ExomPushPageTransitionsBuilder extends PageTransitionsBuilder {
  const ExomPushPageTransitionsBuilder();

  @override
  Duration get transitionDuration => ExomMotion.pushIn;

  @override
  Duration get reverseTransitionDuration => ExomMotion.pushOut;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ExomPushTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// The M1 transition itself: the screen enters [ExomMotion.pushOffset] from
/// the reading-direction end with a fade (enter curve), leaves the same way
/// (exit curve) and dims to [ExomMotion.pushPreviousOpacity] while another
/// screen covers it. Reduced motion: a 100 ms fade, no offset, no dimming.
///
/// It never blocks input: a tap on the incoming screen acts at once and the
/// route can be popped mid-animation. The curves are chosen once per run
/// ([CurvedAnimation] keeps the curve of the direction the animation started
/// in until it comes to rest), so an interrupted push reverses from where the
/// screen is instead of jumping to the exit curve.
class ExomPushTransition extends StatefulWidget {
  const ExomPushTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<ExomPushTransition> createState() => _ExomPushTransitionState();
}

class _ExomPushTransitionState extends State<ExomPushTransition> {
  CurvedAnimation? _enter;
  CurvedAnimation? _covered;
  Animation<double>? _dim;

  /// Motion values the curves were built for.
  Object? _config;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCurves();
  }

  @override
  void didUpdateWidget(ExomPushTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _config = null;
      _syncCurves();
    }
  }

  void _syncCurves() {
    final motion = ExomMotion.of(context);
    final config = (
      motion.pushSlides,
      motion.pushIn,
      motion.pushOut,
      motion.pushPreviousOpacity,
    );
    if (config == _config) return;
    _config = config;
    _disposeCurves();

    final Curve curve;
    final Curve reverseCurve;
    if (motion.pushSlides) {
      curve = ExomMotion.pushEnterCurve;
      reverseCurve = ExomMotion.pushExitCurve.flipped;
    } else {
      // Reduced: the fade takes only the first [motion.pushIn] /
      // [motion.pushOut] of the fixed route durations.
      final shareIn =
          motion.pushIn.inMicroseconds / ExomMotion.pushIn.inMicroseconds;
      final shareOut =
          motion.pushOut.inMicroseconds / ExomMotion.pushOut.inMicroseconds;
      curve = Interval(0, shareIn.clamp(0.0, 1.0));
      reverseCurve = Interval(1 - shareOut.clamp(0.0, 1.0), 1);
    }
    _enter = CurvedAnimation(
      parent: widget.animation,
      curve: curve,
      reverseCurve: reverseCurve,
    );
    final covered = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: ExomMotion.pushEnterCurve,
      reverseCurve: ExomMotion.pushExitCurve.flipped,
    );
    _covered = covered;
    _dim = covered.drive(
      Tween<double>(begin: 1, end: motion.pushPreviousOpacity),
    );
  }

  void _disposeCurves() {
    _enter?.dispose();
    _covered?.dispose();
    _enter = null;
    _covered = null;
    _dim = null;
  }

  @override
  void dispose() {
    _disposeCurves();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = ExomMotion.of(context);
    final enter = _enter!;
    final offset = motion.pushSlides
        ? motion.pushOffset *
              (Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0)
        : 0.0;
    return FadeTransition(
      opacity: _dim!,
      child: FadeTransition(
        opacity: enter,
        child: AnimatedBuilder(
          animation: enter,
          child: widget.child,
          builder: (context, child) => Transform.translate(
            offset: Offset((1 - enter.value) * offset, 0),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// M2 page for the tabs of the main `ShellRoute`: crossfade without offset;
/// the old tab fades out in [ExomMotion.tabFadeOut] while the new one fades
/// in over [ExomMotion.tabFadeIn]. Reduced motion: cut.
///
/// Give it `key: state.pageKey` (the matched route path): switching tabs then
/// replaces the page with this transition, while the same tab with another
/// query (e.g. `?date=`) updates in place and keeps its state, as the former
/// key-less `NoTransitionPage` did.
class ExomTabPage<T> extends CustomTransitionPage<T> {
  const ExomTabPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
         transitionsBuilder: _buildTransition,
         transitionDuration: ExomMotion.tabFadeIn,
         reverseTransitionDuration: ExomMotion.tabFadeIn,
       );

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ExomTabTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// The M2 crossfade used by [ExomTabPage].
///
/// The leaving tab (another tab page covers it) is hidden from assistive
/// technology and ignores taps from the moment it starts leaving, in both
/// modes. With reduced motion it is not painted at all from that moment, so
/// the transparent tab pages never show on top of each other.
class ExomTabTransition extends StatefulWidget {
  const ExomTabTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<ExomTabTransition> createState() => _ExomTabTransitionState();
}

class _ExomTabTransitionState extends State<ExomTabTransition> {
  static final Curve _fadeOutCurve = Interval(
    0,
    ExomMotion.tabFadeOut.inMicroseconds / ExomMotion.tabFadeIn.inMicroseconds,
    curve: ExomMotion.sheetExitCurve,
  );

  late CurvedAnimation _fadeIn;
  late CurvedAnimation _fadeOut;
  late Animation<double> _visibleWhileLeaving;
  late Animation<double> _cutWhileLeaving;

  @override
  void initState() {
    super.initState();
    _createAnimations();
  }

  @override
  void didUpdateWidget(ExomTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _disposeAnimations();
      _createAnimations();
    }
  }

  void _createAnimations() {
    _fadeIn = CurvedAnimation(
      parent: widget.animation,
      curve: ExomMotion.sheetEnterCurve,
    );
    _fadeOut = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: _fadeOutCurve,
    );
    _visibleWhileLeaving = ReverseAnimation(_fadeOut);
    _cutWhileLeaving = widget.secondaryAnimation.drive(const _CutWhenLeaving());
  }

  void _disposeAnimations() {
    _fadeIn.dispose();
    _fadeOut.dispose();
  }

  @override
  void dispose() {
    _disposeAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fades = ExomMotion.of(context).tabFades;
    // Same widget tree in both modes, so a change of the setting keeps the
    // tab's state.
    return FadeTransition(
      opacity: fades ? _fadeIn : kAlwaysCompleteAnimation,
      child: FadeTransition(
        opacity: fades ? _visibleWhileLeaving : _cutWhileLeaving,
        child: AnimatedBuilder(
          animation: widget.secondaryAnimation,
          child: widget.child,
          builder: (context, child) {
            final leaving = widget.secondaryAnimation.value > 0;
            return IgnorePointer(
              ignoring: leaving,
              child: ExcludeSemantics(excluding: leaving, child: child),
            );
          },
        ),
      ),
    );
  }
}

/// 1 while the tab is not covered, 0 as soon as another tab starts covering
/// it (the reduced-motion cut).
class _CutWhenLeaving extends Animatable<double> {
  const _CutWhenLeaving();

  @override
  double transform(double t) => t > 0 ? 0 : 1;
}
