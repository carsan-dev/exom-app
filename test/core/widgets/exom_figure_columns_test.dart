import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';
import 'exom_unit_gap_probe.dart';

const _three = [
  ExomFigure(value: '6', label: 'ejercicios'),
  ExomFigure(value: '42', label: 'minutos', unit: 'min'),
  ExomFigure(value: '18', label: 'series'),
];

const _long = [
  ExomFigure(value: '31,2', label: 'Masa muscular', unit: 'kg'),
  ExomFigure(value: '14,8', label: 'Grasa corporal', unit: '%'),
];

Offset _topLeft(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text));

void main() {
  registerTextComponentMatrix(
    'ExomFigureColumns',
    () => const ExomFigureColumns(items: _three),
  );

  test('ExomFigure is an immutable value', () {
    const a = ExomFigure(value: '1', label: 'a', unit: 'kg');
    expect(a.value, '1');
    expect(a.label, 'a');
    expect(a.unit, 'kg');
    expect(const ExomFigure(value: '1', label: 'a').unit, isNull);
  });

  testWidgets('fits in one row at 360 dp and 1.0 x', (tester) async {
    await pumpComponent(
      tester,
      const ExomFigureColumns(items: _three),
      width: 360,
    );
    final a = _topLeft(tester, 'ejercicios');
    final b = _topLeft(tester, 'minutos');
    final c = _topLeft(tester, 'series');
    expect(b.dx, greaterThan(a.dx));
    expect(c.dx, greaterThan(b.dx));
    expect(b.dy, a.dy);
    expect(c.dy, a.dy);
  });

  testWidgets('falls back to one column when labels do not fit', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const ExomFigureColumns(
        items: [
          ExomFigure(value: '6', label: 'Ejercicios completados'),
          ExomFigure(value: '42', label: 'Entrenamientos', unit: 'min'),
          ExomFigure(value: '18', label: 'Repeticiones'),
        ],
      ),
      width: 320,
      textScale: 1.6,
    );
    final a = _topLeft(tester, 'Ejercicios completados');
    final b = _topLeft(tester, 'Entrenamientos');
    final c = _topLeft(tester, 'Repeticiones');
    expect(b.dy, greaterThan(a.dy));
    expect(c.dy, greaterThan(b.dy));
    expect(b.dx, a.dx);
    expectNoOverflow(tester);
  });

  testWidgets('the decision follows the real text, not a fixed scale', (
    tester,
  ) async {
    // Same scale and width: short labels keep the row, long ones stack.
    await pumpComponent(
      tester,
      const ExomFigureColumns(
        items: [
          ExomFigure(value: '6', label: 'Sets'),
          ExomFigure(value: '4', label: 'Min'),
        ],
      ),
      width: 320,
      textScale: 1.6,
    );
    expect(_topLeft(tester, 'Min').dy, _topLeft(tester, 'Sets').dy);
    await pumpComponent(
      tester,
      const ExomFigureColumns(items: _long),
      width: 320,
      textScale: 2.0,
    );
    expect(
      _topLeft(tester, 'Grasa corporal').dy,
      greaterThan(_topLeft(tester, 'Masa muscular').dy),
    );
  });

  testWidgets('alignLabels: in a row the labels share one y when a figure '
      'shrinks (O5)', (tester) async {
    // «31,2 kg» and «14,8 %» shrink to different sizes at 2.0 x.
    await pumpComponent(
      tester,
      const ExomFigureColumns(items: _long, alignLabels: true),
      width: 320,
      textScale: 2.0,
    );
    expect(
      _topLeft(tester, 'Grasa corporal').dy,
      closeTo(_topLeft(tester, 'Masa muscular').dy, 0.5),
    );
  });

  testWidgets('numbered shows 01, 02, 03 and can be turned off', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const ExomFigureColumns(items: _three),
      width: 360,
    );
    for (final n in const ['01', '02', '03']) {
      expect(find.text(n), findsOneWidget);
    }
    await pumpComponent(
      tester,
      const ExomFigureColumns(items: _three, numbered: false),
      width: 360,
    );
    expect(find.text('01'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('figures in data colour, labels secondary, hairline rules '
        '(${brightness.name})', (tester) async {
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      await pumpComponent(
        tester,
        const ExomFigureColumns(items: _three),
        width: 360,
        brightness: brightness,
      );
      final figure = tester.widget<Text>(find.text('6'));
      expect((figure.textSpan! as TextSpan).style?.color, palette.data);
      expect(
        tester.widget<Text>(find.text('ejercicios')).style?.color,
        palette.textSecondary,
      );
      final rules = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .expand(
            (b) => switch (b) {
              Border() => [b.top, b.bottom, b.left],
              BorderDirectional() => [b.top, b.bottom, b.start],
              _ => const <BorderSide>[],
            },
          )
          .where((s) => s.style == BorderStyle.solid);
      expect(rules, isNotEmpty);
      for (final side in rules) {
        expect(side.color, palette.borderSoft);
        expect(side.width, 1);
      }
    });
  }

  testWidgets('semantics reads label, value and unit per figure', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const ExomFigureColumns(items: _three),
      width: 360,
    );
    expect(find.bySemanticsLabel('minutos: 42 min'), findsOneWidget);
    expect(find.bySemanticsLabel('ejercicios: 6'), findsOneWidget);
    handle.dispose();
  });

  for (final scale in const [1.0, 1.6]) {
    testWidgets('figure and unit do not touch ($scale x)', (tester) async {
      final gap = await measureUnitGap(
        tester,
        (withUnit) => SizedBox(
          width: 400,
          child: ExomFigureColumns(
            numbered: false,
            items: [
              ExomFigure(
                value: '42',
                label: 'minutos',
                unit: withUnit ? 'min' : null,
              ),
            ],
          ),
        ),
        textScale: scale,
      );
      expect(gap, greaterThan(0));
    });
  }

  testWidgets('RTL: the separator hairline sits on the start side', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const Directionality(
        textDirection: TextDirection.rtl,
        child: ExomFigureColumns(items: _three),
      ),
      width: 360,
    );
    final cells = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<BorderDirectional>()
        .toList();
    // The first column has no rule; the other two have it at the start.
    expect(cells, hasLength(2));
    expect(cells[0].start.style, BorderStyle.solid);
    expect(cells[1].start.style, BorderStyle.solid);
    expect(cells[0].end, BorderSide.none);
    // First column is the rightmost one in RTL.
    expect(
      _topLeft(tester, 'ejercicios').dx,
      greaterThan(_topLeft(tester, 'minutos').dx),
    );
  });
}
