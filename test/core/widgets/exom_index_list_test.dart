import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

void _noop() {}

ExomThemePalette _palette(Brightness b) =>
    themeFor(b).extension<ExomThemePalette>()!;

Widget _list({List<String>? taps}) => ExomIndexList(
  items: [
    ExomIndexItem(
      title: 'Actualizar peso y medidas',
      onTap: () => taps?.add('peso'),
    ),
    ExomIndexItem(
      title: 'Fotos de progreso',
      icon: Icons.arrow_forward,
      onTap: () => taps?.add('fotos'),
    ),
    const ExomIndexItem(title: 'Historial de revisiones', status: '3 nuevas'),
  ],
);

/// Lines of [paragraph] as [start, end) ranges over its plain text, trailing
/// spaces excluded.
List<(int, int)> _lines(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText();
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: paragraph.size.width);
  final lines = <(int, int)>[];
  var i = 0;
  while (i < text.length) {
    final b = painter.getLineBoundary(TextPosition(offset: i));
    if (b.end <= i) break;
    var end = b.end;
    while (end > b.start && text[end - 1] == ' ') {
      end--;
    }
    lines.add((b.start, end));
    i = b.end;
  }
  painter.dispose();
  return lines;
}

void main() {
  registerTextComponentMatrix('ExomIndexList', _list);

  testWidgets('tap targets meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _list(), width: 320);
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('numbers 01.. in the data colour, titles in section style '
        'upper case (${brightness.name})', (tester) async {
      final palette = _palette(brightness);
      await pumpComponent(tester, _list(), brightness: brightness);
      for (final n in ['01', '02', '03']) {
        final text = tester.widget<Text>(find.text(n));
        expect(text.style?.color, palette.data);
        expect(
          text.style?.fontFeatures,
          ExomIndexNumber.style(palette.data).fontFeatures,
        );
      }
      final title = tester.widget<Text>(find.text('FOTOS DE PROGRESO'));
      expect(title.style?.fontFamily, ExomType.section.fontFamily);
      expect(title.style?.fontSize, ExomType.section.fontSize);
      expect(title.style?.fontWeight, FontWeight.w800);
      expect(title.style?.color, palette.textPrimary);
      final status = tester.widget<Text>(find.text('3 nuevas'));
      expect(status.style?.fontWeight, FontWeight.w600);
      expect(status.style?.fontSize, 14);
    });
  }

  testWidgets('each entry is at least 60 tall with a top rule; list closes '
      'with a bottom rule', (tester) async {
    final palette = _palette(Brightness.dark);
    await pumpComponent(tester, _list());
    final entries = find.byKey(const Key('exom-index-entry'));
    expect(entries, findsNWidgets(3));
    for (final e in entries.evaluate()) {
      expect(e.size!.height, greaterThanOrEqualTo(60));
    }
    final list = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(ExomIndexList),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final border = (list.decoration as BoxDecoration).border! as Border;
    expect(border.bottom, BorderSide(color: palette.borderSoft, width: 1));
  });

  testWidgets('a long status wraps at 320 dp, 1.6x: no overflow, nothing cut', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const SingleChildScrollView(
        child: ExomIndexList(
          items: [
            ExomIndexItem(
              title: 'Fotos de progreso',
              status: 'Tienes tres fotos nuevas de tu última revisión',
              onTap: _noop,
            ),
          ],
        ),
      ),
      width: 320,
      textScale: 1.6,
    );
    expectNoOverflow(tester);
    expectNoEllipsis(tester);
    final status = tester.getRect(
      find.text('Tienes tres fotos nuevas de tu última revisión'),
    );
    expect(status.right, lessThanOrEqualTo(320));
    expect(status.left, greaterThanOrEqualTo(0));
  });

  testWidgets('trailing icon: given icon, chevron when tappable, none else', (
    tester,
  ) async {
    await pumpComponent(tester, _list());
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('taps reach the item; semantics read the original title', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final taps = <String>[];
    await pumpComponent(tester, _list(taps: taps));
    await tester.tap(find.text('FOTOS DE PROGRESO'));
    await tester.tap(find.text('ACTUALIZAR PESO Y MEDIDAS'));
    expect(taps, ['fotos', 'peso']);
    expect(find.bySemanticsLabel(RegExp('Fotos de progreso')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('FOTOS DE PROGRESO')), findsNothing);
    final node = tester.getSemantics(find.text('FOTOS DE PROGRESO'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.label, contains('02'));
    handle.dispose();
  });

  group('title has priority over the status: no word is split', () {
    const status = 'Tienes tres fotos nuevas de tu última revisión';
    const titles = ['Medidas', 'Fotos de progreso', 'Historial de pesos'];
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.3, 1.6, 2.0]) {
        for (final title in titles) {
          testWidgets('"$title" at $width dp, $scale x', (tester) async {
            await pumpComponent(
              tester,
              SingleChildScrollView(
                child: ExomIndexList(
                  items: [
                    ExomIndexItem(title: title, status: status, onTap: _noop),
                    ExomIndexItem(
                      title: title,
                      status: '3 nuevas',
                      onTap: _noop,
                    ),
                  ],
                ),
              ),
              width: width,
              textScale: scale,
            );
            expectNoOverflow(tester);
            expectNoEllipsis(tester);
            final upper = title.toUpperCase();
            for (final e in find.text(upper).evaluate()) {
              final p = e.renderObject! as RenderParagraph;
              final text = p.text.toPlainText();
              for (final (start, end) in _lines(p)) {
                expect(
                  start == 0 || text[start - 1] == ' ',
                  isTrue,
                  reason: 'line starts mid-word in "$text"',
                );
                expect(
                  end == text.length || text[end] == ' ',
                  isTrue,
                  reason: 'line ends mid-word in "$text"',
                );
              }
            }
          });
        }
      }
    }

    testWidgets('1.0 x with a short title keeps the status on the same row', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const ExomIndexList(
          items: [
            ExomIndexItem(title: 'Fotos', status: '3 nuevas', onTap: _noop),
          ],
        ),
      );
      final title = tester.getRect(find.text('FOTOS'));
      final status = tester.getRect(find.text('3 nuevas'));
      expect(status.top, lessThan(title.bottom));
      expect(status.left, greaterThan(title.right));
    });

    testWidgets('when it does not fit the status drops below the title', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const ExomIndexList(
          items: [
            ExomIndexItem(
              title: 'Fotos de progreso',
              status: '3 nuevas',
              onTap: _noop,
            ),
          ],
        ),
        width: 390,
        textScale: 1.6,
      );
      final title = tester.getRect(find.text('FOTOS DE PROGRESO'));
      final status = tester.getRect(find.text('3 nuevas'));
      expect(status.top, greaterThanOrEqualTo(title.bottom));
      expect(status.left, title.left);
    });
  });
}
