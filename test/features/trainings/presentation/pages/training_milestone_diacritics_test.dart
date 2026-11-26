// L5-E6a «Sesión hecha»: the diacritics of an upper-case line must not reach
// the line above. The owner reported «FB1 VÍDEO A.» with the acute of the Í
// touching the baseline of «SESIÓN HECHA.»: the headline line height (.86 of
// the sketch) is shorter than the top of a capital diacritic in Barlow
// Condensed 800.
//
// Font facts (assets/fonts/barlow-condensed-800.ttf, 1000 units per em,
// measured with fontTools): capitals end at the baseline and are 700 units
// tall; the acute capitals (Á É Í Ó Ú) reach 883, Ñ 899 and Ü 920.
//
// Two checks:
// * real ink: the headline is painted with the bundled fonts and the rows of
//   the first line (text colour) and of the name (data colour) are compared;
//   at least one clean row must separate them.
// * layout: when the name wraps, every line of the name leaves room above its
//   capitals for a dieresis (920 units) plus .03 em of air before the baseline
//   above (the same air as the ExomType two-line headlines at .95).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;
import 'training_milestone_test.dart' show pumpMilestone;

/// Top of the tallest Spanish capital diacritic (Ü) in em.
const double _dieresisTop = 0.92;

/// Air between that diacritic and the baseline above, in em.
const double _air = 0.03;

class _Frame {
  _Frame(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final ByteData rgba;

  int channel(int x, int y, int c) => rgba.getUint8((y * width + x) * 4 + c);
}

Future<_Frame> _capture(WidgetTester tester) async {
  final element = find.byType(MaterialApp).evaluate().single;
  final frame = await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = _Frame(image.width, image.height, bytes);
    image.dispose();
    return result;
  });
  return frame!;
}

int _byte(double channel) => (channel * 255).round();

Future<void> _expectClearRow(
  WidgetTester tester, {
  required String name,
  required String firstLine,
  required String secondLine,
}) async {
  await loadRedesignFonts();
  await initializeDateFormatting('es');
  await pumpMilestone(tester, trainingName: name);

  final first = tester.getRect(find.text(firstLine));
  final second = tester.getRect(find.text(secondLine));
  final frame = await _capture(tester);

  // Dark palette: the first line is near white (high blue), the name is lime
  // (green far above blue). Each class needs at least half of its contrast
  // against the page, so faint anti-aliasing does not count.
  const text = AppColors.textPrimary;
  const data = AppColors.primary;
  const page = AppColors.background;
  final textBlue = (_byte(text.b) + _byte(page.b)) / 2;
  final dataSpread = (_byte(data.g) - _byte(data.b)) / 2;

  final left = first.left.floor();
  final right = first.right.ceil().clamp(0, frame.width);
  // The data rule sits 20 px above the headline; the acute of the first line
  // overhangs its box by a few pixels.
  final top = (first.top - 12).floor().clamp(0, frame.height);
  final bottom = second.bottom.ceil().clamp(0, frame.height);
  int? lastTextRow;
  int? firstDataRow;
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final r = frame.channel(x, y, 0);
      final g = frame.channel(x, y, 1);
      final b = frame.channel(x, y, 2);
      if (b > textBlue && r > textBlue) lastTextRow = y;
      if (g - b > dataSpread && b < textBlue) firstDataRow ??= y;
    }
  }
  expect(lastTextRow, isNotNull, reason: 'first line painted');
  expect(firstDataRow, isNotNull, reason: 'name painted');
  expect(
    firstDataRow! - lastTextRow!,
    greaterThanOrEqualTo(2),
    reason:
        'the top of «$secondLine» (row $firstDataRow) must leave a clean row '
        'below «$firstLine» (last row $lastTextRow)',
  );
}

void main() {
  testWidgets('the acute of «VÍDEO» stays below «SESIÓN HECHA.»', (
    tester,
  ) async {
    await _expectClearRow(
      tester,
      name: 'FB1 Vídeo A',
      firstLine: 'SESIÓN HECHA.',
      secondLine: 'FB1 VÍDEO A.',
    );
  });

  testWidgets('the tilde of «AÑO» stays below «SESIÓN HECHA.»', (
    tester,
  ) async {
    await _expectClearRow(
      tester,
      name: 'Año',
      firstLine: 'SESIÓN HECHA.',
      secondLine: 'AÑO.',
    );
  });

  testWidgets('the dieresis of «PINGÜINO» stays below «SESIÓN HECHA.»', (
    tester,
  ) async {
    await _expectClearRow(
      tester,
      name: 'Pingüino',
      firstLine: 'SESIÓN HECHA.',
      secondLine: 'PINGÜINO.',
    );
  });

  testWidgets('a wrapped name leaves room for Ü and Ñ above each line', (
    tester,
  ) async {
    await loadRedesignFonts();
    await initializeDateFormatting('es');
    const name = 'Pierna pingüino del año';
    await pumpMilestone(tester, trainingName: name);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('${name.toUpperCase()}.'),
    );
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      strutStyle: paragraph.strutStyle,
      textHeightBehavior: paragraph.textHeightBehavior,
    )..layout(maxWidth: paragraph.size.width);
    addTearDown(painter.dispose);
    final lines = painter.computeLineMetrics();
    expect(lines.length, greaterThan(1), reason: 'the name wraps');
    final size = paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
    for (var i = 1; i < lines.length; i++) {
      final step = lines[i].baseline - lines[i - 1].baseline;
      // The engine rounds each line height to whole pixels: half a pixel of
      // tolerance.
      expect(
        step,
        greaterThanOrEqualTo((_dieresisTop + _air) * size - 0.5),
        reason: 'line $i of the name: baseline step $step at $size px',
      );
    }
  });
}
