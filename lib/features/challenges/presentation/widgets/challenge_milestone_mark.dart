import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:flutter/material.dart';

/// Milestone header of the L5 redesign (`.x-mark`, once per screen): the
/// [value] at 140 in the text colour over two full-width bands rotated ±12°.
/// The back band is `panel`; the front one is `raised` with 2 px data-coloured
/// rules on top and bottom (lime in dark, `#4F6B00` in light: never lime ink).
///
/// The bands live only behind the numeral and are clipped to the header. The
/// numeral shrinks to the width (see [ExomNumeral]). Assistive technology reads
/// [semanticsLabel] as one node (the bands are decorative).
class ChallengeMilestoneMark extends StatelessWidget {
  const ChallengeMilestoneMark({
    super.key,
    required this.value,
    required this.semanticsLabel,
  });

  /// Figure already formatted for the locale.
  final String value;
  final String semanticsLabel;

  /// Rotation of the bands (sketch: ±12°).
  static const double bandAngle = 12 * math.pi / 180;

  /// Width of the front band's top and bottom rules.
  static const double bandRule = 2;

  /// Keys of the bands, for tests.
  static const Key backBandKey = ValueKey('challenge-mark-back-band');
  static const Key frontBandKey = ValueKey('challenge-mark-front-band');

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final rule = BorderSide(color: palette.data, width: bandRule);
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) {
                  final width = box.maxWidth;
                  final height = box.maxHeight;
                  Widget band(Key key, double angle, BoxDecoration decoration) =>
                      Positioned(
                        left: -0.3 * width,
                        width: 1.6 * width,
                        top: 0.22 * height,
                        height: 0.56 * height,
                        child: Transform.rotate(
                          angle: angle,
                          child: DecoratedBox(key: key, decoration: decoration),
                        ),
                      );
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      band(
                        backBandKey,
                        bandAngle,
                        BoxDecoration(color: palette.surface),
                      ),
                      band(
                        frontBandKey,
                        -bandAngle,
                        BoxDecoration(
                          color: palette.surfaceElevated,
                          border: Border(top: rule, bottom: rule),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExomNumeral(
                  value: value,
                  size: ExomNumeralSize.hero140,
                  isData: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
