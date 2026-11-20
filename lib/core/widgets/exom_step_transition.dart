import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/widgets.dart';

/// M9 form step: when [step] changes, the new [child] enters
/// [ExomMotion.stepOffset] dp from the side the form advances to (the
/// reading-direction end when [step] grows, the start when it goes back) with
/// a fade, in [ExomMotion.step]; the previous step leaves towards the other
/// side. Reduced motion: a 100 ms fade, no offset.
///
/// The new step takes taps from the first frame; the leaving one ignores
/// them. A new change mid-animation starts from where things are: each step
/// keeps the curve of the direction its animation started in until it comes
/// to rest, so reversing mid-way does not jump.
class ExomStepTransition extends StatefulWidget {
  const ExomStepTransition({
    super.key,
    required this.step,
    required this.child,
  });

  final int step;
  final Widget child;

  @override
  State<ExomStepTransition> createState() => _ExomStepTransitionState();
}

class _ExomStepTransitionState extends State<ExomStepTransition> {
  /// 1 when the last change advanced, -1 when it went back.
  double _advance = 1;

  @override
  void didUpdateWidget(ExomStepTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step != oldWidget.step) {
      _advance = widget.step > oldWidget.step ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = ExomMotion.of(context);
    final side =
        _advance *
        (Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0);
    final current = ValueKey<int>(widget.step);
    return AnimatedSwitcher(
      duration: motion.step,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == current;
        return _StepEntry(
          animation: animation,
          slides: motion.stepSlides,
          offset: motion.stepSlides
              ? motion.stepOffset * (incoming ? side : -side)
              : 0,
          incoming: incoming,
          child: child,
        );
      },
      child: KeyedSubtree(key: current, child: widget.child),
    );
  }
}

/// One step inside the switcher. Its [CurvedAnimation] is created once, so
/// the curve does not change when the animation is reversed mid-way.
class _StepEntry extends StatefulWidget {
  const _StepEntry({
    required this.animation,
    required this.slides,
    required this.offset,
    required this.incoming,
    required this.child,
  });

  final Animation<double> animation;
  final bool slides;

  /// Signed distance the step sits at when fully hidden.
  final double offset;
  final bool incoming;
  final Widget child;

  @override
  State<_StepEntry> createState() => _StepEntryState();
}

class _StepEntryState extends State<_StepEntry> {
  late CurvedAnimation _curved;

  /// Side the step sits at when hidden. It only changes while the step is at
  /// rest and complete, so a rebuild mid-animation (a second change before the
  /// first ends) cannot flip it and make the step jump.
  late double _offset;

  @override
  void initState() {
    super.initState();
    _curved = _create();
    _offset = widget.offset;
  }

  @override
  void didUpdateWidget(_StepEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.slides != widget.slides) {
      _curved.dispose();
      _curved = _create();
    }
    if (widget.animation.value >= 1) _offset = widget.offset;
  }

  CurvedAnimation _create() => widget.slides
      ? CurvedAnimation(
          parent: widget.animation,
          curve: ExomMotion.stepCurve,
          reverseCurve: ExomMotion.sheetExitCurve.flipped,
        )
      : CurvedAnimation(parent: widget.animation, curve: Curves.linear);

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
    final offset = _offset;
    return IgnorePointer(
      ignoring: !widget.incoming,
      child: FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          child: widget.child,
          builder: (context, child) => Transform.translate(
            offset: Offset((1 - curved.value) * offset, 0),
            child: child,
          ),
        ),
      ),
    );
  }
}
