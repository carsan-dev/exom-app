import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';
import 'exom_unit_gap_probe.dart';

Widget _numeral() => ExomNumeral(
  value: '68,4',
  unit: 'kg',
  size: ExomNumeralSize.hero140,
  side: Builder(
    builder: (context) =>
        Text('-3,0 kg', style: Theme.of(context).textTheme.bodyLarge),
  ),
);

RenderParagraph _valueParagraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(ExomNumeral.valueKey),
        matching: find.byType(RichText),
      ),
    );

void main() {
  registerTextComponentMatrix('ExomNumeral', _numeral);

  testWidgets('each size maps to its ExomType style', (tester) async {
    final expected = {
      ExomNumeralSize.hero64: ExomType.hero64,
      ExomNumeralSize.hero96: ExomType.hero96,
      ExomNumeralSize.hero120: ExomType.hero120,
      ExomNumeralSize.hero140: ExomType.hero140,
    };
    for (final entry in expected.entries) {
      await pumpComponent(
        tester,
        ExomNumeral(value: '12', size: entry.key),
        width: 600,
      );
      final text = tester.widget<Text>(find.byKey(ExomNumeral.valueKey));
      expect(text.style?.fontSize, entry.value.fontSize);
      expect(text.style?.height, entry.value.height);
      expect(text.style?.fontWeight, FontWeight.w800);
    }
  });

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('data colour by default, text colour when not data '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        const ExomNumeral(value: '12', unit: 'kg'),
        brightness: brightness,
      );
      expect(
        tester.widget<Text>(find.byKey(ExomNumeral.valueKey)).style?.color,
        palette.data,
      );
      await pumpComponent(
        tester,
        const ExomNumeral(value: '12', unit: 'kg', isData: false),
        brightness: brightness,
      );
      expect(
        tester.widget<Text>(find.byKey(ExomNumeral.valueKey)).style?.color,
        palette.textPrimary,
      );
    });
  }

  testWidgets('paints es and en values exactly as received', (tester) async {
    final es = NumberFormat('0.0', 'es').format(68.4);
    final en = NumberFormat('0.0', 'en').format(68.4);
    expect(es, '68,4');
    expect(en, '68.4');
    await pumpComponent(tester, ExomNumeral(value: es));
    expect(_valueParagraph(tester).text.toPlainText(), '68,4');
    await pumpComponent(tester, ExomNumeral(value: en));
    expect(_valueParagraph(tester).text.toPlainText(), '68.4');
  });

  testWidgets('unit is smaller, untracked and part of the text', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const ExomNumeral(
        value: '68,4',
        unit: 'kg',
        size: ExomNumeralSize.hero96,
      ),
    );
    final spans = <TextSpan>[];
    _valueParagraph(tester).text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    final unit = spans.firstWhere((s) => s.text == 'kg');
    expect(unit.style?.fontSize, closeTo(96 * 0.4, 0.001));
    expect(unit.style?.letterSpacing, 0);
    expect(_valueParagraph(tester).text.toPlainText(), contains('68,4'));
  });

  testWidgets('semantics reads value and unit, side keeps its own node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _numeral(), width: 600);
    expect(find.bySemanticsLabel('68,4 kg'), findsOneWidget);
    expect(find.bySemanticsLabel('-3,0 kg'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semantics without unit reads only the value', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, const ExomNumeral(value: '12'));
    expect(find.bySemanticsLabel('12'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('wide numeral scales down to the available width', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const ExomNumeral(
        value: '1234,5',
        unit: 'kcal',
        size: ExomNumeralSize.hero140,
      ),
      width: 320,
      textScale: 1.6,
    );
    expectNoOverflow(tester);
    expect(find.byType(FittedBox), findsOneWidget);
    expect(
      tester.getSize(find.byType(ExomNumeral)).width,
      lessThanOrEqualTo(320),
    );
  });

  for (final size in ExomNumeralSize.values) {
    testWidgets('glyph ink stays inside the numeral box (${size.name})', (
      tester,
    ) async {
      final key = GlobalKey();
      await pumpComponent(
        tester,
        Center(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF000000),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: ExomNumeral(value: '08', size: size, isData: false),
              ),
            ),
          ),
        ),
        width: 600,
        height: 600,
      );
      final box = tester.getRect(find.byType(ExomNumeral));
      final outer = tester.getRect(find.byKey(key));
      final bounds = await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = (await image.toByteData())!;
        var top = image.height;
        var bottom = -1;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final i = (y * image.width + x) * 4;
            if (data.getUint8(i) > 90) {
              if (y < top) top = y;
              if (y > bottom) bottom = y;
            }
          }
        }
        image.dispose();
        return (top: top, bottom: bottom);
      });
      expect(bounds!.bottom, greaterThan(bounds.top));
      final inkTop = outer.top + bounds.top;
      final inkBottom = outer.top + bounds.bottom + 1;
      // The glyph is not cut: the numeral box contains all of its ink.
      expect(inkTop, greaterThanOrEqualTo(box.top - 0.5));
      expect(inkBottom, lessThanOrEqualTo(box.bottom + 0.5));
    });
  }

  for (final size in ExomNumeralSize.values) {
    for (final scale in const [1.0, 1.6]) {
      testWidgets('figure and unit do not touch (${size.name}, $scale x)', (
        tester,
      ) async {
        final gap = await measureUnitGap(
          tester,
          (withUnit) => ExomNumeral(
            value: '68,4',
            unit: withUnit ? 'kg' : null,
            size: size,
            isData: false,
          ),
          textScale: scale,
        );
        expect(gap, greaterThan(0));
      });
    }
  }

  testWidgets('unit gap keeps one baseline, the value and the semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _numeral(), width: 900);
    final paragraph = _valueParagraph(tester);
    expect(paragraph.text.toPlainText(), '68,4kg');
    // One line: figure and unit share the baseline.
    expect(
      paragraph.size.height,
      lessThan(ExomType.hero140.fontSize! * ExomType.hero140.height! * 1.5),
    );
    expect(find.bySemanticsLabel('68,4 kg'), findsOneWidget);
    expect(find.bySemanticsLabel('-3,0 kg'), findsOneWidget);
    handle.dispose();
  });
}
