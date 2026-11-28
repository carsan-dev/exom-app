import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/widgets.dart';

/// M3 content arrival: when the content replaces its skeleton it fades in
/// over [ExomMotion.arrivalFade], and the first [ExomMotion.arrivalRiseRows]
/// rows wrapped in [ExomArrivalItem] rise [ExomMotion.arrivalRise] dp,
/// staggered by [ExomMotion.arrivalStagger]. Reduced motion: a 120 ms fade,
/// no rise.
///
/// First load only: the animation runs once, when this widget is first
/// inserted; later rebuilds (a refresh with new data) show the content as is.
/// Pass [animate] false when the content was already on screen (e.g. it comes
/// from a cache) so it does not animate at all.
///
/// Generic: it does not know about skeletons. The caller swaps its skeleton
/// for `ExomArrival(child: content)`. The content takes taps from the first
/// frame; the animation never delays them.
class ExomArrival extends StatefulWidget {
  const ExomArrival({super.key, required this.child, this.animate = true});

  final Widget child;
  final bool animate;

  @override
  State<ExomArrival> createState() => _ExomArrivalState();
}

class _ExomArrivalState extends State<ExomArrival>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  ExomMotionSpec? _motion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motion != null) return;
    final motion = ExomMotion.of(context);
    _motion = motion;
    _controller.duration =
        motion.arrivalFade +
        motion.arrivalStagger * (ExomMotion.arrivalRiseRows - 1);
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _motion!;
    final total = _controller.duration!.inMicroseconds;
    final fade = Interval(
      0,
      total == 0 ? 1 : motion.arrivalFade.inMicroseconds / total,
      curve: motion.isReduced ? Curves.linear : ExomMotion.arrivalCurve,
    );
    return _ArrivalScope(
      animation: _controller,
      motion: motion,
      child: FadeTransition(
        opacity: _controller.drive(CurveTween(curve: fade)),
        child: widget.child,
      ),
    );
  }
}

class _ArrivalScope extends InheritedWidget {
  const _ArrivalScope({
    required this.animation,
    required this.motion,
    required super.child,
  });

  final AnimationController animation;
  final ExomMotionSpec motion;

  @override
  bool updateShouldNotify(_ArrivalScope oldWidget) =>
      animation != oldWidget.animation || motion != oldWidget.motion;
}

/// A row of an [ExomArrival]. Rows with [index] below
/// [ExomMotion.arrivalRiseRows] rise into place with their stagger; the rest
/// (and every row outside an [ExomArrival] or with reduced motion) are left
/// as they are.
class ExomArrivalItem extends StatelessWidget {
  const ExomArrivalItem({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ArrivalScope>();
    if (scope == null ||
        index < 0 ||
        index >= ExomMotion.arrivalRiseRows ||
        scope.motion.arrivalRise == 0) {
      return child;
    }
    final motion = scope.motion;
    final total = scope.animation.duration!.inMicroseconds;
    final start = (motion.arrivalStagger * index).inMicroseconds;
    final end = start + motion.arrivalFade.inMicroseconds;
    final rise = Interval(
      start / total,
      end / total,
      curve: ExomMotion.arrivalCurve,
    );
    return AnimatedBuilder(
      animation: scope.animation,
      child: child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          motion.arrivalRise * (1 - rise.transform(scope.animation.value)),
        ),
        child: child,
      ),
    );
  }
}
