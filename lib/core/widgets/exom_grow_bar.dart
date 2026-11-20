import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/widgets.dart';

/// M5 progress bar that grows to [value] (0-1) in [ExomMotion.growBar]
/// ease-out. A later [value] animates from where the bar is, so a change
/// mid-animation retargets at once. [followsBytes] makes the growth linear,
/// for an upload that follows its bytes. Reduced motion: the final value
/// directly.
///
/// Colours, height and corner radius come from the caller. Assistive
/// technology gets [semanticsLabel] and [semanticsValue] (the final value,
/// never the animated one); without [semanticsValue] it gets the rounded
/// final percentage (e.g. `43 %`).
class ExomGrowBar extends StatelessWidget {
  const ExomGrowBar({
    super.key,
    required this.value,
    required this.color,
    this.trackColor,
    this.height = 4,
    this.borderRadius,
    this.followsBytes = false,
    this.semanticsLabel,
    this.semanticsValue,
  });

  /// Key of the filled part (tests).
  static const Key fillKey = Key('exom-grow-bar-fill');

  final double value;
  final Color color;
  final Color? trackColor;
  final double height;
  final BorderRadius? borderRadius;
  final bool followsBytes;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final motion = ExomMotion.of(context);
    final target = value.clamp(0.0, 1.0);
    Widget bar = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: motion.growBar,
      curve: followsBytes ? Curves.linear : ExomMotion.growBarCurve,
      builder: (context, progress, _) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          key: fillKey,
          widthFactor: progress,
          heightFactor: 1,
          child: ColoredBox(color: color),
        ),
      ),
    );
    final track = trackColor;
    if (track != null) {
      bar = ColoredBox(color: track, child: bar);
    }
    final radius = borderRadius;
    if (radius != null) {
      bar = ClipRRect(borderRadius: radius, child: bar);
    }
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: semanticsValue ?? '${(target * 100).round()} %',
      child: SizedBox(height: height, width: double.infinity, child: bar),
    );
  }
}
