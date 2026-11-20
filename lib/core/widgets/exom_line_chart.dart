import 'dart:math' as math;

import 'package:exom_app/core/charts/weight_chart_axis.dart';
import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// One point of an [ExomLineChart]: [x] orders the points (e.g. days), [y] is
/// the value drawn.
@immutable
class ExomPoint {
  const ExomPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is ExomPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Flat line chart of the L5 redesign (ESPEC §3, `.x-chart`): a 2 dp line in
/// `palette.data` without any fill, the last point filled and labelled
/// ([labelOf], by default the value with the locale separator and up to two
/// decimals), hairline grid at the round marks of `weightAxis` (the L4 axis
/// of the weight chart, reused) and a hairline base.
///
/// States: no points (base only), one point (a labelled point, no line), a
/// series. Points are drawn in [ExomPoint.x] order. Width 100 %, height 40 %
/// of the width (the sketch's 350 x 140).
///
/// Semantics: one node summarising the number of points and the last value
/// («4 puntos, último valor 68,4»; «Sin datos» when empty).
class ExomLineChart extends StatelessWidget {
  const ExomLineChart({super.key, required this.points, this.labelOf});

  final List<ExomPoint> points;
  final String Function(double value)? labelOf;

  /// Key of the chart painter, for tests.
  static const Key painterKey = ValueKey('exom-line-chart-painter');

  static const double _aspect = 0.4;
  static const double _labelGap = 8;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final separator = decimalSeparatorFor(
      Localizations.localeOf(context).languageCode,
    );
    final format =
        labelOf ?? (v) => formatDisplayDecimal(v, decimalSeparator: separator);
    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));
    final last = sorted.isEmpty ? null : sorted.last;
    final lastLabel = last == null ? '' : format(last.y);
    final labelStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: palette.textPrimary,
    );
    final labelHeight =
        MediaQuery.textScalerOf(context).scale(13) * (labelStyle.height ?? 1);

    return Semantics(
      container: true,
      label: l10n.exomChartSummary(sorted.length, lastLabel),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = width * _aspect;
            final layout = _ChartLayout(sorted, Size(width, height));
            final lastOffset = layout.lastOffset;
            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      key: painterKey,
                      painter: _LineChartPainter(
                        layout: layout,
                        line: palette.data,
                        rule: palette.borderSoft,
                      ),
                    ),
                  ),
                  if (lastOffset != null)
                    Positioned(
                      right: math.max(
                        0,
                        width - lastOffset.dx - _ChartLayout.pointRadius,
                      ),
                      top: lastOffset.dy - _labelGap - labelHeight >= 0
                          ? null
                          : math.min(
                              lastOffset.dy + _labelGap,
                              math.max(0, height - labelHeight),
                            ),
                      bottom: lastOffset.dy - _labelGap - labelHeight >= 0
                          ? height - (lastOffset.dy - _labelGap)
                          : null,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.max(
                            ExomSpacing.huge,
                            lastOffset.dx + _ChartLayout.pointRadius,
                          ),
                        ),
                        child: Text(
                          lastLabel,
                          textAlign: TextAlign.end,
                          style: labelStyle,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Geometry shared by the painter and the label.
class _ChartLayout {
  _ChartLayout(this.points, this.size) {
    if (points.isEmpty) {
      axis = null;
      offsets = const [];
      return;
    }
    final ys = points.map((p) => p.y);
    final resolved = weightAxis(ys.reduce(math.min), ys.reduce(math.max));
    axis = resolved;
    final minX = points.first.x;
    final spanX = points.last.x - minX;
    final left = _startInset;
    final right = size.width - _endInset;
    offsets = [
      for (final p in points)
        Offset(
          spanX == 0 ? right : left + (p.x - minX) / spanX * (right - left),
          yOf(p.y),
        ),
    ];
  }

  final List<ExomPoint> points;
  final Size size;
  late final WeightAxis? axis;
  late final List<Offset> offsets;

  static const double pointRadius = 4;
  static const double _startInset = 6;
  static const double _endInset = 6;
  static const double _topInset = 8;
  static const double _bottomInset = 8;

  double get baseY => size.height - ExomRule.hairline / 2;

  double yOf(double value) {
    final a = axis!;
    final top = _topInset;
    final bottom = size.height - _bottomInset;
    final span = a.max - a.min;
    return bottom - (value - a.min) / span * (bottom - top);
  }

  Offset? get lastOffset => offsets.isEmpty ? null : offsets.last;
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.layout,
    required this.line,
    required this.rule,
  });

  final _ChartLayout layout;
  final Color line;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    final rulePaint = Paint()
      ..color = rule
      ..strokeWidth = ExomRule.hairline
      ..style = PaintingStyle.stroke;
    final axis = layout.axis;
    if (axis != null) {
      for (final tick in axis.ticks.skip(1)) {
        final y = layout.yOf(tick);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
      }
    }
    canvas.drawLine(
      Offset(0, layout.baseY),
      Offset(size.width, layout.baseY),
      rulePaint,
    );
    final offsets = layout.offsets;
    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final o in offsets.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..strokeWidth = ExomRule.data
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    if (offsets.isNotEmpty) {
      canvas.drawCircle(
        offsets.last,
        _ChartLayout.pointRadius,
        Paint()
          ..color = line
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.line != line ||
      old.rule != rule ||
      old.layout.size != layout.size ||
      !_samePoints(old.layout.points, layout.points);

  static bool _samePoints(List<ExomPoint> a, List<ExomPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
