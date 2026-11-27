import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/material.dart';

enum _SkeletonKind { numeral, headline, rule, row }

/// Content-shaped loading placeholders of the L5 redesign (`.x-skel-n`,
/// `.x-skel-h2l`, `.x-skel-rule`, `.skel-row`): flat blocks in the `raised`
/// colour, no radius.
///
/// Motion: a soft opacity pulse that repeats while the skeleton is mounted.
/// With reduced motion (`ExomMotion.of(context).isReduced`, i.e.
/// `PerformanceProfile.prefersReducedMotion`) it is static and schedules no
/// frames.
///
/// Semantics: skeletons are excluded from the semantic tree (like the local
/// skeletons they replace, which carry no text). The screen that shows them
/// is responsible for announcing the loading state once.
///
/// Testing screens: with motion on the pulse never settles, so
/// `pumpAndSettle` times out while a skeleton is on screen. Pump a fixed
/// duration (`tester.pump(const Duration(milliseconds: 300))`) or run the test
/// with `MediaQuery.disableAnimations: true`, where `pumpAndSettle` returns.
class ExomSkeleton extends StatelessWidget {
  const ExomSkeleton.numeral({super.key}) : _kind = _SkeletonKind.numeral;
  const ExomSkeleton.headline({super.key}) : _kind = _SkeletonKind.headline;
  const ExomSkeleton.rule({super.key}) : _kind = _SkeletonKind.rule;
  const ExomSkeleton.row({super.key}) : _kind = _SkeletonKind.row;

  final _SkeletonKind _kind;

  /// Width used when the incoming width constraint is unbounded.
  static const double _unboundedWidth = 240;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final raised = palette.surfaceElevated;
    final Widget shape = switch (_kind) {
      _SkeletonKind.numeral => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : double.infinity;
          return Align(
            alignment: AlignmentDirectional.centerStart,
            heightFactor: 1,
            child: SizedBox(
              height: math.min(76.8, 0.24 * width),
              width: math.min(70.4, 0.42 * width),
              child: ColoredBox(color: raised),
            ),
          );
        },
      ),
      _SkeletonKind.headline => FractionallySizedBox(
        widthFactor: 0.64,
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(height: 54.4, child: ColoredBox(color: raised)),
      ),
      _SkeletonKind.rule => SizedBox(
        height: 4,
        width: double.infinity,
        child: ColoredBox(color: raised),
      ),
      _SkeletonKind.row => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.borderSoft)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: ColoredBox(color: raised),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.6,
                        child: SizedBox(
                          height: 16,
                          child: ColoredBox(color: raised),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FractionallySizedBox(
                        widthFactor: 0.4,
                        child: SizedBox(
                          height: 12.8,
                          child: ColoredBox(color: raised),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    };
    // Headline, rule and row fill the available width; inside an unbounded
    // axis (a Row without Expanded, a horizontal scroll) they would fail, so
    // they fall back to a bounded width there.
    final bounded = _kind == _SkeletonKind.numeral
        ? shape
        : LayoutBuilder(
            builder: (context, constraints) => constraints.hasBoundedWidth
                ? shape
                : SizedBox(width: _unboundedWidth, child: shape),
          );
    return ExcludeSemantics(child: _SkeletonPulse(child: bounded));
  }
}

/// Opacity pulse that stops (and renders the child as is) with reduced motion.
class _SkeletonPulse extends StatefulWidget {
  const _SkeletonPulse({required this.child});

  final Widget child;

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(milliseconds: 1200);
  static const double _lowOpacity = 0.5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: _lowOpacity,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  bool _reduced = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ExomMotion.of(context).isReduced;
    if (_reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) return widget.child;
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
