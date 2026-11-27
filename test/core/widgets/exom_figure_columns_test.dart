import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'android_nonlinear_text_scaler.dart';
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

  // L5-E5 (owner decision 2026-11-25): optional parameters for the load
  // columns of the active circuit and the active exercise (`.x-k` above,
  // `e-load` 64 in the data colour, `e-ref` 56 in the text colour with a
  // detail line). Their defaults leave every existing use as it was.
  group('labels above, tone, size and detail (L5-E5)', () {
    test('defaults: data tone, 56, no detail, labels below', () {
      const figure = ExomFigure(value: '1', label: 'a');
      expect(figure.tone, ExomFigureTone.data);
      expect(figure.size, ExomFigureSize.s56);
      expect(figure.detail, isNull);
      expect(figure.semanticsLabel, isNull);
      expect(const ExomFigureColumns(items: _three).labelsAbove, isFalse);
      expect(
        const ExomFigure(value: '1', label: 'a', detail: 'x'),
        isNot(const ExomFigure(value: '1', label: 'a')),
      );
      expect(
        const ExomFigure(value: '1', label: 'a', size: ExomFigureSize.s64),
        isNot(const ExomFigure(value: '1', label: 'a')),
      );
      expect(
        const ExomFigure(value: '1', label: 'a', tone: ExomFigureTone.text),
        isNot(const ExomFigure(value: '1', label: 'a')),
      );
    });

    testWidgets('default stays as before: label below in bodyMedium, figure '
        'at 56 / .85 / -1.12, no kicker', (tester) async {
      await pumpComponent(
        tester,
        const ExomFigureColumns(items: _three),
        width: 360,
      );
      expect(find.byType(ExomKicker), findsNothing);
      final style =
          (tester.widget<Text>(find.text('6')).textSpan! as TextSpan).style!;
      expect(style.fontSize, 56);
      expect(style.height, 0.85);
      expect(style.letterSpacing, -1.12);
      expect(
        _topLeft(tester, 'ejercicios').dy,
        greaterThan(tester.getBottomLeft(find.text('6')).dy - 1),
      );
    });

    for (final brightness in Brightness.values) {
      testWidgets('labelsAbove: kicker above; 64 load in data, 56 reference '
          'in text with its detail below (${brightness.name})', (tester) async {
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        await pumpComponent(
          tester,
          const ExomFigureColumns(
            numbered: false,
            labelsAbove: true,
            items: [
              ExomFigure(
                value: '12',
                unit: 'reps',
                label: 'Objetivo',
                size: ExomFigureSize.s64,
              ),
              ExomFigure(
                value: '10',
                unit: 'reps',
                label: 'Última vez',
                tone: ExomFigureTone.text,
                detail: '× 22,5 kg · RIR 2',
              ),
            ],
          ),
          width: 390,
          brightness: brightness,
        );
        expect(find.byType(ExomKicker), findsNWidgets(2));
        expect(find.text('OBJETIVO'), findsOneWidget);
        expect(find.text('ÚLTIMA VEZ'), findsOneWidget);
        expect(find.text('Objetivo'), findsNothing);

        final loadFinder = find.text('12reps');
        final refFinder = find.text('10reps');
        final load =
            (tester.widget<Text>(loadFinder).textSpan! as TextSpan).style!;
        expect(load.fontSize, ExomType.hero64.fontSize);
        expect(load.height, ExomType.hero64.height);
        expect(load.letterSpacing, ExomType.hero64.letterSpacing);
        expect(load.color, palette.data);

        final ref =
            (tester.widget<Text>(refFinder).textSpan! as TextSpan).style!;
        expect(ref.fontSize, 56);
        expect(ref.height, 0.85);
        expect(ref.letterSpacing, -1.12);
        expect(ref.color, palette.textPrimary);

        final detail = tester.widget<Text>(find.text('× 22,5 kg · RIR 2'));
        expect(detail.style?.fontSize, 14);
        expect(detail.style?.height, 1.4);
        expect(detail.style?.color, palette.textSecondary);

        // Kicker, figure, detail from top to bottom; both kickers share a y.
        expect(
          _topLeft(tester, 'OBJETIVO').dy,
          _topLeft(tester, 'ÚLTIMA VEZ').dy,
        );
        expect(
          tester.getTopLeft(refFinder).dy,
          greaterThan(_topLeft(tester, 'ÚLTIMA VEZ').dy),
        );
        expect(
          _topLeft(tester, '× 22,5 kg · RIR 2').dy,
          greaterThan(tester.getTopLeft(refFinder).dy),
        );
        expect(
          _topLeft(tester, 'ÚLTIMA VEZ').dx,
          greaterThan(_topLeft(tester, 'OBJETIVO').dx),
        );
      });
    }

    // The real baseline of each figure (RenderParagraph.getDistanceToBaseline
    // mapped to global, so a FittedBox scale is included), not rects and not a
    // TextPainter re-layout: on the device the hand-computed offset left the
    // 64 and the 56 figures 3.0 dp (1.0 x) and 2.3 dp (1.6 x) apart.
    for (final scale in const [1.0, 1.6]) {
      testWidgets('labelsAbove: the figures of a row share the real baseline '
          '($scale x)', (tester) async {
        await pumpComponent(
          tester,
          const ExomFigureColumns(
            numbered: false,
            labelsAbove: true,
            items: [
              ExomFigure(
                value: '12',
                unit: 'reps',
                label: 'Objetivo',
                size: ExomFigureSize.s64,
                itemKey: Key('load'),
              ),
              ExomFigure(
                value: '10',
                unit: 'reps',
                label: 'Última vez',
                tone: ExomFigureTone.text,
                detail: '× 22,5 kg · RIR 2',
                itemKey: Key('ref'),
              ),
            ],
          ),
          width: 411,
          textScale: scale,
        );
        double baselineOf(Key cell) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(cell),
              matching: find.byWidgetPredicate(
                (w) => w is RichText && w.text.toPlainText().contains('reps'),
              ),
            ),
          );
          // Same value getDistanceToBaseline gives during layout; it is only
          // callable from a parent's layout, so ask the paragraph for it with
          // the constraints it was laid out with.
          final distance = paragraph.getDryBaseline(
            paragraph.constraints,
            TextBaseline.alphabetic,
          )!;
          return paragraph.localToGlobal(Offset(0, distance)).dy;
        }

        expect(
          (baselineOf(const Key('load')) - baselineOf(const Key('ref'))).abs(),
          lessThan(0.5),
        );
        expect(tester.takeException(), isNull);
      });
    }

    // r5: the same real baseline with the nonlinear text scaler of Android 14+
    // (the 64 and the 56 grow by different factors) and with a first cell
    // that has no figure (value empty, detail only), which has no baseline.
    double realBaseline(WidgetTester tester, Key cell, String marker) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(cell),
          matching: find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains(marker),
          ),
        ),
      );
      final distance = paragraph.getDryBaseline(
        paragraph.constraints,
        TextBaseline.alphabetic,
      )!;
      return paragraph.localToGlobal(Offset(0, distance)).dy;
    }

    testWidgets('labelsAbove: the figures share the real baseline with the '
        'Android nonlinear text scaler (1.6 x)', (tester) async {
      await pumpComponent(
        tester,
        const ExomFigureColumns(
          numbered: false,
          labelsAbove: true,
          items: [
            ExomFigure(
              value: '12',
              unit: 'reps',
              label: 'Objetivo',
              size: ExomFigureSize.s64,
              itemKey: Key('load'),
            ),
            ExomFigure(
              value: '10',
              unit: 'reps',
              label: 'Última vez',
              tone: ExomFigureTone.text,
              detail: '× 22,5 kg · RIR 2',
              itemKey: Key('ref'),
            ),
          ],
        ),
        width: 411,
        textScaler: const AndroidNonlinearTextScaler(1.6),
      );
      expect(
        (realBaseline(tester, const Key('load'), 'reps') -
                realBaseline(tester, const Key('ref'), 'reps'))
            .abs(),
        lessThan(0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('labelsAbove: a first cell without a figure does not move the '
        'shared baseline of the others', (tester) async {
      await pumpComponent(
        tester,
        const ExomFigureColumns(
          numbered: false,
          labelsAbove: true,
          items: [
            ExomFigure(
              value: '',
              label: 'Última vez',
              detail: 'Sin registro',
              itemKey: Key('empty'),
            ),
            ExomFigure(
              value: '12',
              unit: 'reps',
              label: 'Objetivo',
              size: ExomFigureSize.s64,
              itemKey: Key('load'),
            ),
            ExomFigure(
              value: '40',
              unit: 's',
              label: 'Descanso',
              itemKey: Key('rest'),
            ),
          ],
        ),
        width: 411,
      );
      expect(find.text('Sin registro'), findsOneWidget);
      expect(
        (realBaseline(tester, const Key('load'), 'reps') -
                realBaseline(tester, const Key('rest'), 's'))
            .abs(),
        lessThan(0.5),
      );
      // The cell without a figure stays at the top of the row.
      expect(
        tester.getTopLeft(find.text('Sin registro')).dy,
        lessThan(realBaseline(tester, const Key('load'), 'reps')),
      );
      expect(tester.takeException(), isNull);
    });

    // r5: _ScaledBaseline must report the scaled baseline in a dry pass too
    // (getDryBaseline), not the FittedBox child's unscaled one.
    testWidgets('a figure scaled below 1 reports the same dry baseline as its '
        'real baseline after layout', (tester) async {
      await pumpComponent(
        tester,
        const ExomFigureColumns(
          numbered: false,
          labelsAbove: true,
          items: [
            ExomFigure(
              value: '1234,5',
              unit: 'kg',
              label: 'Carga',
              size: ExomFigureSize.s64,
              itemKey: Key('big'),
            ),
            ExomFigure(value: '8', label: 'Reps', itemKey: Key('small')),
          ],
        ),
        width: 300,
      );
      final fitted = tester.renderObject<RenderFittedBox>(
        find.descendant(
          of: find.byKey(const Key('big')),
          matching: find.byType(FittedBox),
        ),
      );
      final natural = fitted.child!;
      // Precondition: the figure is really scaled down.
      expect(fitted.size.width / natural.size.width, lessThan(1.0));
      final scaled = fitted.parent! as RenderBox;
      final dry = scaled.getDryBaseline(
        scaled.constraints,
        TextBaseline.alphabetic,
      )!;
      final real =
          realBaseline(tester, const Key('big'), 'kg') -
          scaled.localToGlobal(Offset.zero).dy;
      expect((dry - real).abs(), lessThan(0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics: detail appended; semanticsLabel replaces it; '
        'itemKey kept', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const ExomFigureColumns(
          numbered: false,
          labelsAbove: true,
          items: [
            ExomFigure(
              value: '12',
              unit: 'reps',
              label: 'Objetivo',
              detail: 'RIR 2',
              itemKey: Key('target'),
            ),
            ExomFigure(
              value: '10',
              unit: 'reps',
              label: 'Última vez',
              detail: '× 22,5 kg',
              semanticsLabel: 'Última vez: 10 × 22,5 kg',
            ),
          ],
        ),
        width: 390,
      );
      expect(find.bySemanticsLabel('Objetivo: 12 reps, RIR 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Última vez: 10 × 22,5 kg'), findsOneWidget);
      expect(find.byKey(const Key('target')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an empty value with a detail paints only label and detail', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const ExomFigureColumns(
          numbered: false,
          labelsAbove: true,
          items: [
            ExomFigure(value: '12', unit: 'reps', label: 'Objetivo'),
            ExomFigure(
              value: '',
              label: 'Última vez',
              detail: 'Sin datos anteriores',
            ),
          ],
        ),
        width: 390,
      );
      expect(find.text('Sin datos anteriores'), findsOneWidget);
      expect(find.byType(FittedBox), findsOneWidget);
    });

    for (final (width, scale) in const [
      (320.0, 1.3),
      (320.0, 1.6),
      (360.0, 1.6),
    ]) {
      testWidgets('labelsAbove does not overflow at $width dp and $scale x', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          const ExomFigureColumns(
            numbered: false,
            labelsAbove: true,
            items: [
              ExomFigure(
                value: '12',
                unit: 'reps',
                label: 'Objetivo · RIR 2',
                size: ExomFigureSize.s64,
              ),
              ExomFigure(
                value: '10',
                unit: 'reps',
                label: 'Última vez',
                tone: ExomFigureTone.text,
                detail: '× 137,79 lb · RIR 2',
              ),
            ],
          ),
          width: width,
          textScale: scale,
        );
        expectNoOverflow(tester);
      });
    }
  });
}
