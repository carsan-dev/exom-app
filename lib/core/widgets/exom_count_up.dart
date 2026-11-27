import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/widgets.dart';

/// M5 figure that counts up from 0 to [value] in [ExomMotion.countUp]
/// (ease-out) the first time it appears. Later changes of [value] show the
/// new value directly. Reduced motion: the final value directly.
///
/// Only the first value it is built with counts: if that value is 0 (e.g. a
/// placeholder while the data loads) and the real figure arrives later, the
/// figure is shown directly, without counting. To count the loaded figure,
/// build this widget only once the data is there.
///
/// It does not format numbers itself: [formatter] turns the (animated) value
/// into text, so units, decimals and locale stay with the caller. Assistive
/// technology always gets the formatted final value, never the animated one.
class ExomCountUp extends StatefulWidget {
  const ExomCountUp({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.textAlign,
  });

  final double value;
  final String Function(double value) formatter;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<ExomCountUp> createState() => _ExomCountUpState();
}

class _ExomCountUpState extends State<ExomCountUp>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    _resolved = true;
    final duration = ExomMotion.of(context).countUp;
    if (duration > Duration.zero && widget.value != 0) {
      _controller = AnimationController(vsync: this, duration: duration)
        ..forward();
    }
  }

  @override
  void didUpdateWidget(ExomCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the first appearance counts up.
    if (oldWidget.value != widget.value) {
      _controller?.value = 1;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _text(double shown) => Text(
    widget.formatter(shown),
    style: widget.style,
    textAlign: widget.textAlign,
  );

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Semantics(
      container: true,
      label: widget.formatter(widget.value),
      child: ExcludeSemantics(
        child: controller == null
            ? _text(widget.value)
            : AnimatedBuilder(
                animation: controller,
                builder: (context, _) => _text(
                  widget.value *
                      ExomMotion.countUpCurve.transform(controller.value),
                ),
              ),
      ),
    );
  }
}
