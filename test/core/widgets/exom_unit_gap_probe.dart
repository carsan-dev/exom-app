// Geometric probe of the gap between a figure and its unit (the sketch's
// `.x-u { margin-left: .06em }`). Not a test file: it has no `main`.
//
// Glyph boxes include the (negative) tracking of the last digit, so they
// cannot show whether the ink touches. The probe paints the widget twice, with
// and without the unit, and compares real pixels: the gap is the distance
// between the right edge of the figure ink and the left edge of the ink that
// only exists when the unit is present.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

/// Bright pixels (over black) of [region] inside [key]'s boundary.
Future<Set<(int, int)>> _ink(
  WidgetTester tester,
  GlobalKey key,
  Rect region,
) async {
  final result = await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final data = (await image.toByteData())!;
    final found = <(int, int)>{};
    for (
      var y = region.top.floor();
      y < region.bottom.ceil() && y < image.height;
      y++
    ) {
      for (
        var x = region.left.floor();
        x < region.right.ceil() && x < image.width;
        x++
      ) {
        final i = (y * image.width + x) * 4;
        final bright = [
          data.getUint8(i),
          data.getUint8(i + 1),
          data.getUint8(i + 2),
        ].reduce((a, b) => a > b ? a : b);
        if (bright > 90) found.add((x, y));
      }
    }
    image.dispose();
    return found;
  });
  return result!;
}

/// Measures, in logical pixels, the horizontal gap between the figure and the
/// unit painted by the widget [build] returns (called with `withUnit`).
/// The widget must contain exactly one [FittedBox] around the figure.
Future<double> measureUnitGap(
  WidgetTester tester,
  Widget Function(bool withUnit) build, {
  double width = 1400,
  double textScale = 1.0,
}) async {
  final key = GlobalKey();
  Widget framed(bool withUnit) => Align(
    alignment: Alignment.topLeft,
    child: RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: build(withUnit),
        ),
      ),
    ),
  );

  await pumpComponent(
    tester,
    framed(true),
    width: width,
    height: 900,
    textScale: textScale,
  );
  final origin = tester.getTopLeft(find.byKey(key));
  final box = tester.getRect(find.byType(FittedBox).first).shift(-origin);
  final withUnit = await _ink(tester, key, box);

  await pumpComponent(
    tester,
    framed(false),
    width: width,
    height: 900,
    textScale: textScale,
  );
  final without = await _ink(tester, key, box);

  final onlyUnit = withUnit.difference(without);
  expect(onlyUnit, isNotEmpty, reason: 'the unit left no ink of its own');
  final unitLeft = onlyUnit.map((p) => p.$1).reduce((a, b) => a < b ? a : b);
  final figureRight = without.map((p) => p.$1).reduce((a, b) => a > b ? a : b);
  // Right edge of the last figure pixel to the left edge of the first unit
  // pixel: empty columns in between.
  return (unitLeft - figureRight - 1).toDouble();
}
