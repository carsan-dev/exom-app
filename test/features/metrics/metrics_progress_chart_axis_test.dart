// L5-E9a (O2): the kg unit above the weight chart must not touch the top axis
// label, and the axis labels must stay clear of the last point (which sits at
// the right edge of the plot). Measured with the nonlinear Android scaler.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/android_nonlinear_text_scaler.dart';
import 'metrics_progress_redesign_fixture.dart';

/// Last dot: radius 5 plus half its 1.75 stroke.
const double _lastDotExtent = 5 + 1.75 / 2;

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.3, 1.6]) {
      testWidgets(
        'chart unit and axis labels are clear, ${brightness.name} x$scale',
        (tester) async {
          await pumpProgressScene(
            tester,
            brightness: brightness,
            height: 1400,
            textScaler: AndroidNonlinearTextScaler(scale),
          );
          final chartFinder = find.byType(LineChart);
          final chartRect = tester.getRect(chartFinder);
          final chart = tester.widget<LineChart>(chartFinder);
          final reserved =
              chart.data.titlesData.rightTitles.sideTitles.reservedSize;
          final unit = tester.getRect(
            find.descendant(
              of: find.byKey(const Key('progress-weight-chart')),
              matching: find.text('kg'),
            ),
          );
          final labels =
              find
                  .descendant(of: chartFinder, matching: find.byType(Text))
                  .evaluate()
                  .map((e) => e.widget as Text)
                  .where(
                    (t) =>
                        double.tryParse(t.data!.replaceAll(',', '.')) != null,
                  )
                  .map((t) => tester.getRect(find.byWidget(t)))
                  .toList()
                ..sort((a, b) => a.top.compareTo(b.top));
          expect(labels.length, greaterThanOrEqualTo(2));
          final top = labels.first;
          final bottom = labels.last;
          expect(
            unit.bottom,
            lessThanOrEqualTo(top.top),
            reason: 'unit $unit overlaps top label $top',
          );
          final plotRight = chartRect.right - reserved;
          expect(
            bottom.left - (plotRight + _lastDotExtent),
            greaterThanOrEqualTo(4),
            reason: 'label $bottom too close to the last point at $plotRight',
          );
        },
      );
    }
  }
}
