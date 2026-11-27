import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/widgets.dart';

/// How [ExomStepTransition] moves from one step to the next.
enum ExomStepTransitionStyle {
  /// The overlapped M9: the new step enters [ExomMotion.stepOffset] dp from
  /// the side the form advances to with a fade while the previous one fades
  /// out towards the other side.
  overlap,

  /// A horizontal push (L5-C5b): the previous step moves fully out to one
  /// side while the new one enters from the other, both fully opaque and
  /// clipped to the area of the transition, in [ExomMotion.stepSlide] on
  /// [ExomMotion.stepSlideCurve]. Going back pushes the other way. Reduced
  /// motion: the short fade of [overlap].
  slide,
}

/// M9 form step: when [step] changes, the new [child] enters
/// [ExomMotion.stepOffset] dp from the side the form advances to (the
/// reading-direction end when [step] grows, the start when it goes back) with
/// a fade, in [ExomMotion.step]; the previous step leaves towards the other
/// side. Reduced motion: a 100 ms fade, no offset.
///
/// The new step takes taps from the first frame; the leaving one ignores
/// them and is out of the semantics tree (L5-A4c). A new change mid-animation starts from where things are: each step
/// keeps the curve of the direction its animation started in until it comes
/// to rest, so reversing mid-way does not jump.
///
/// [style] picks the push of [ExomStepTransitionStyle.slide] instead; the
/// default stays the overlapped M9.
class ExomStepTransition extends StatefulWidget {
  const ExomStepTransition({
    super.key,
    required this.step,
    required this.child,
    this.style = ExomStepTransitionStyle.overlap,
  });

  final int step;
  final Widget child;
  final ExomStepTransitionStyle style;

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
    if (widget.style == ExomStepTransitionStyle.slide && motion.stepSlides) {
      return _StepPush(step: widget.step, child: widget.child);
    }
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
    // The leaving step is only painted: it takes no taps and a screen reader
    // does not read it (L5-A4c), so the content is never announced twice.
    return IgnorePointer(
      ignoring: !widget.incoming,
      child: ExcludeFocus(
        excluding: !widget.incoming,
        child: ExcludeSemantics(
          excluding: !widget.incoming,
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
        ),
      ),
    );
  }
}

/// The push of [ExomStepTransitionStyle.slide]. Two steps at most are
/// painted: [_a] and [_b] move as one strip, [_b] at `side * (1 - t)` widths
/// and [_a] at `-side * t` widths, where t is the curved progress. Advancing
/// runs t to 1 ([_b] is the step on screen); going back to [_a] mid-way runs
/// it back to 0 from where it is, so the push reverses without a jump. A
/// change to a third step mid-way jumps: the step on screen until then
/// becomes the one that leaves, from its place, and the other one is
/// dropped, so steps never pile up.
class _StepPush extends StatefulWidget {
  const _StepPush({required this.step, required this.child});

  final int step;
  final Widget child;

  @override
  State<_StepPush> createState() => _StepPushState();
}

class _StepPushState extends State<_StepPush>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ExomMotion.stepSlide,
    value: 1,
  )..addStatusListener(_onStatus);
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: ExomMotion.stepSlideCurve,
  );

  /// The step the strip leaves from (null at rest) and its last child.
  int? _a;
  Widget? _aChild;

  /// The step the strip moves to and its last child.
  late int _b;
  late Widget _bChild;

  /// 1 when the strip moves towards the start (advancing), -1 otherwise.
  double _side = 1;

  /// True while the step on screen is [_b] (the strip runs or rests at 1).
  bool _towardsB = true;

  /// True while a new push resets the strip to 0 (that is not a rest).
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    _b = widget.step;
    _bChild = widget.child;
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted || _restarting || status.isAnimating || _a == null) return;
    final dismissed = status.isDismissed;
    setState(() {
      if (dismissed) {
        // Rest on [_a]: it becomes the only step.
        _b = _a!;
        _bChild = _aChild ?? _bChild;
        _towardsB = true;
      }
      _a = null;
      _aChild = null;
    });
    // Back to the rest value of a single step (no listener work left: [_a]
    // is already null).
    if (dismissed) _controller.value = 1;
  }

  @override
  void didUpdateWidget(_StepPush oldWidget) {
    super.didUpdateWidget(oldWidget);
    final step = widget.step;
    final onScreen = _towardsB ? _b : _a;
    if (step == onScreen) return;
    if (_controller.isAnimating && step == (_towardsB ? _a : _b)) {
      // Back to the step that is leaving: the push runs the other way from
      // where it is.
      if (_towardsB) {
        _bChild = oldWidget.child;
        _controller.reverse();
      } else {
        _aChild = oldWidget.child;
        _controller.forward();
      }
      _towardsB = !_towardsB;
      return;
    }
    // A new push from the step on screen (a jump when one was running).
    _a = oldWidget.step;
    _aChild = oldWidget.child;
    _b = step;
    _side = step > oldWidget.step ? 1 : -1;
    _towardsB = true;
    _restarting = true;
    _controller.value = 0;
    _restarting = false;
    _controller.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _slot(int step, Widget child, double dx, {required bool active}) {
    // The step that leaves is only painted: it takes no taps and a screen
    // reader does not read it (L5-A4c).
    return KeyedSubtree(
      key: ValueKey<(String, int)>(('exom-step-push', step)),
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: KeyedSubtree(key: ValueKey<int>(step), child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final side = _side * (rtl ? -1.0 : 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final a = _a;
            final aChild = _aChild;
            final moving = a != null && aChild != null;
            final t = _progress.value;
            final bOnScreen = _towardsB;
            return ClipRect(
              // Clipped only while moving, so a step at rest paints as it
              // did.
              clipBehavior: moving ? Clip.hardEdge : Clip.none,
              child: Stack(
                alignment: AlignmentDirectional.topStart,
                children: [
                  if (moving && bOnScreen)
                    _slot(a, aChild, -side * t * width, active: false),
                  if (moving && !bOnScreen)
                    _slot(_b, _bChild, side * (1 - t) * width, active: false),
                  if (bOnScreen)
                    _slot(
                      _b,
                      widget.child,
                      moving ? side * (1 - t) * width : 0,
                      active: true,
                    )
                  else if (moving)
                    _slot(a, widget.child, -side * t * width, active: true),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
