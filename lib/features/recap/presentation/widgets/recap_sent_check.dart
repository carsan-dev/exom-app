import 'package:flutter/material.dart';

/// Large check next to the headline of «Enviado» (L5-C5b, owner decision
/// 2026-11-25: option C of the sketch `c5b-enviado-cabecera` with the check of
/// option B). Decorative: it has no semantics of its own, the headline and the
/// confirmed state already say the recap was sent.
///
/// [progress] runs the «Sello» animation over [duration] (0 → 1): the stroke
/// is drawn along the path in the first 180 ms (ease-out), then the check is
/// stamped in 80 ms (scale 1.12 x 0.88 settling to its own size with a small
/// ease-out-back). At 1 it is whole and at rest; at 0 nothing is drawn. It is
/// painted from [progress] alone, so the animation never rebuilds the page.
class RecapSentCheck extends StatelessWidget {
  const RecapSentCheck({
    super.key,
    required this.progress,
    required this.color,
    required this.size,
  });

  final Animation<double> progress;
  final Color color;
  final double size;

  static const Duration duration = Duration(milliseconds: 260);
  static const Duration _traceDuration = Duration(milliseconds: 180);

  /// Fraction of [duration] where the stamp starts (and the haptic plays).
  static final double stampStart =
      _traceDuration.inMicroseconds / duration.inMicroseconds;

  static const double _stampX = 1.12;
  static const double _stampY = 0.88;

  /// Drawn fraction of the path at [t] of the animation.
  static double traceAt(double t) {
    if (t >= stampStart) return 1;
    if (t <= 0) return 0;
    return Curves.easeOut.transform(t / stampStart);
  }

  /// Horizontal (dx) and vertical (dy) scale of the stamp at [t].
  static Offset stampScaleAt(double t) {
    if (t < stampStart) return const Offset(1, 1);
    final p = (t - stampStart) / (1 - stampStart);
    if (p >= 1) return const Offset(1, 1);
    final k = Curves.easeOutBack.transform(p);
    return Offset(_stampX + (1 - _stampX) * k, _stampY + (1 - _stampY) * k);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: RecapSentCheckPainter(progress: progress, color: color),
        ),
      ),
    );
  }
}

/// Paints the check of [RecapSentCheck] (Lucide-like path on a 24 grid, round
/// caps and joins, stroke one seventh of the side).
class RecapSentCheckPainter extends CustomPainter {
  RecapSentCheckPainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  /// Drawn fraction of the path now.
  double get trace => RecapSentCheck.traceAt(progress.value);

  /// Stamp scale now (1, 1 at rest).
  Offset get stampScale => RecapSentCheck.stampScaleAt(progress.value);

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = trace;
    if (drawn <= 0) return;
    final unit = size.shortestSide / 24;
    final path = Path()
      ..moveTo(4.5 * unit, 12.5 * unit)
      ..lineTo(9.5 * unit, 17.5 * unit)
      ..lineTo(19.5 * unit, 7 * unit);
    final metric = path.computeMetrics().first;
    final visible = drawn >= 1
        ? path
        : metric.extractPath(0, metric.length * drawn);
    final scale = stampScale;
    final center = size.center(Offset.zero);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale.dx, scale.dy)
      ..translate(-center.dx, -center.dy)
      ..drawPath(
        visible,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide / 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(RecapSentCheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
