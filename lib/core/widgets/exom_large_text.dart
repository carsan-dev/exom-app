import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Text scale from which the screens with a pinned footer adapt to large text
/// (L5-D63): the detail footer scrolls away and the sheets with a pinned foot
/// open taller. Below it they stay exactly as before.
const double kExomLargeTextScale = 1.3;

/// Whether [context] uses large text in the sense of L5-D63.
bool exomIsLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) >= kExomLargeTextScale;

/// Initial size of a draggable sheet with a pinned foot (L5-D63): with large
/// text it opens tall enough to show its lead block, [leadBottom] measured
/// from the top of the sheet's content, above a foot of [footHeight], within
/// [maxSize]. Otherwise, or before anything is measured, it is [initialSize].
double exomSheetInitialSize(
  BuildContext context, {
  required double initialSize,
  required double maxSize,
  required double available,
  required double leadBottom,
  required double footHeight,
}) {
  if (!exomIsLargeText(context) || available <= 0 || leadBottom <= 0) {
    return initialSize;
  }
  return math.max(
    initialSize,
    math.min((leadBottom + footHeight) / available, maxSize),
  );
}

/// Reports where its child ends inside the enclosing scroll view, measured
/// from the top of the scroll content (whatever the scroll offset), after
/// each layout it builds in. Paints and lays out nothing of its own.
class ExomScrollContentBottomReporter extends StatefulWidget {
  const ExomScrollContentBottomReporter({
    super.key,
    required this.onBottom,
    required this.child,
  });

  final ValueChanged<double> onBottom;
  final Widget child;

  @override
  State<ExomScrollContentBottomReporter> createState() =>
      _ExomScrollContentBottomReporterState();
}

class _ExomScrollContentBottomReporterState
    extends State<ExomScrollContentBottomReporter> {
  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject();
    final scrollable = context.findAncestorStateOfType<ScrollableState>();
    final viewport = scrollable?.context.findRenderObject();
    if (box is! RenderBox ||
        !box.hasSize ||
        scrollable == null ||
        viewport is! RenderBox ||
        !viewport.hasSize) {
      return;
    }
    final bottom = box
        .localToGlobal(Offset(0, box.size.height), ancestor: viewport)
        .dy;
    widget.onBottom(bottom + scrollable.position.pixels);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return widget.child;
  }
}

/// Reports the height of its child after each layout it builds in. Paints
/// and lays out nothing of its own.
class ExomHeightReporter extends StatefulWidget {
  const ExomHeightReporter({
    super.key,
    required this.onHeight,
    required this.child,
  });

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<ExomHeightReporter> createState() => _ExomHeightReporterState();
}

class _ExomHeightReporterState extends State<ExomHeightReporter> {
  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) widget.onHeight(box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return widget.child;
  }
}
