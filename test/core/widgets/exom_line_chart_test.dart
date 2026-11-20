// T0.4 (docs/plans/rediseno-app-l5-contrato-v2.md): ExomLineChart (ESPEC §3,
// `.x-chart`): 2 px data line without fill, last point labelled, base rule.
import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';
import 'expect_no_lime_ink.dart';

const _series = [
  ExomPoint(0, 71.4),
  ExomPoint(30, 70.1),
  ExomPoint(60, 69.0),
  ExomPoint(90, 68.4),
];

Widget _padded(Widget child) => Padding(
  padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
  child: child,
);

Finder get _painter => find.byKey(ExomLineChart.painterKey);

void main() {
  registerTextComponentMatrix(
    'ExomLineChart',
    () => const ExomLineChart(points: _series),
  );

  // Core must not depend on a feature's presentation layer: the pure axis
  // helper lives in lib/core/charts and the metrics path only re-exports it.
  test('the chart imports the axis from core, not from a feature', () {
    final source = File(
      'lib/core/widgets/exom_line_chart.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('package:exom_app/features/')));
    expect(source, contains('package:exom_app/core/charts/weight_chart_axis'));
    expect(File('lib/core/charts/weight_chart_axis.dart').existsSync(), isTrue);
    final legacy = File(
      'lib/features/metrics/presentation/widgets/weight_chart_axis.dart',
    ).readAsStringSync();
    expect(
      legacy.trim().split('\n').where((l) => l.trim().startsWith('export ')),
      hasLength(1),
    );
    expect(legacy, isNot(contains('class WeightAxis')));
  });

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('series: 2 px stroked data line, filled last point, base '
        'rule (${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        _padded(const ExomLineChart(points: _series)),
        brightness: brightness,
      );
      expect(
        _painter,
        paints
          ..line(color: palette.borderSoft, strokeWidth: 1)
          ..path(
            color: palette.data,
            strokeWidth: 2,
            style: PaintingStyle.stroke,
          )
          ..circle(color: palette.data, style: PaintingStyle.fill),
      );
      // No area fill under the line: the only path is the stroked one.
      expect(_painter, paintsExactlyCountTimes(#drawPath, 1));
      expect(find.text('68,4'), findsOneWidget);
      final label = tester.widget<Text>(find.text('68,4'));
      expect(label.style?.color, palette.textPrimary);
    });
  }

  testWidgets('light theme: no lime ink (the line is #4F6B00)', (tester) async {
    await pumpComponent(
      tester,
      _padded(const ExomLineChart(points: _series)),
      brightness: Brightness.light,
    );
    expectNoLimeInk(tester);
  });

  testWidgets('empty: only the base rule, summary says no data', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _padded(const ExomLineChart(points: [])));
    expect(_painter, paintsExactlyCountTimes(#drawPath, 0));
    expect(_painter, paintsExactlyCountTimes(#drawCircle, 0));
    expect(_painter, paints..line());
    expect(find.bySemanticsLabel('Sin datos'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('one point: a labelled point, no line', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      _padded(const ExomLineChart(points: [ExomPoint(0, 68.4)])),
    );
    expect(_painter, paintsExactlyCountTimes(#drawPath, 0));
    expect(_painter, paintsExactlyCountTimes(#drawCircle, 1));
    expect(find.text('68,4'), findsOneWidget);
    expect(find.bySemanticsLabel('1 punto, último valor 68,4'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semantics summary: number of points and last value', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _padded(const ExomLineChart(points: _series)));
    expect(
      find.bySemanticsLabel('4 puntos, último valor 68,4'),
      findsOneWidget,
    );
    await pumpComponent(
      tester,
      _padded(const ExomLineChart(points: _series)),
      locale: const Locale('en'),
    );
    expect(
      find.bySemanticsLabel('4 points, latest value 68.4'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('labelOf formats the last value', (tester) async {
    await pumpComponent(
      tester,
      _padded(
        ExomLineChart(points: _series, labelOf: (v) => '${v.round()} kg'),
      ),
    );
    expect(find.text('68 kg'), findsOneWidget);
  });

  testWidgets('the last point and its label stay inside the chart', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      _padded(const ExomLineChart(points: _series)),
      width: 320,
      textScale: 1.6,
    );
    final chart = tester.getRect(find.byType(ExomLineChart));
    final label = tester.getRect(find.text('68,4'));
    expect(chart.contains(label.topLeft), isTrue);
    expect(label.right, lessThanOrEqualTo(chart.right + 0.01));
    expect(label.bottom, lessThanOrEqualTo(chart.bottom + 0.01));
  });

  testWidgets('a rising series puts the label below the last point', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      _padded(
        const ExomLineChart(points: [ExomPoint(0, 60), ExomPoint(1, 80)]),
      ),
    );
    final chart = tester.getRect(find.byType(ExomLineChart));
    final label = tester.getRect(find.text('80'));
    expect(label.top, greaterThanOrEqualTo(chart.top));
  });
}
