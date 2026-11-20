import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:flutter/material.dart';

/// Size of an [ExomNumeral]: `.x-hero-96/-120/-140` of the sketch (64 is the
/// reduced protagonist).
enum ExomNumeralSize { hero64, hero96, hero120, hero140 }

/// Spans of a figure followed by its unit (`.x-u`: 0.4 em, no tracking).
///
/// The figure's negative tracking is also applied after its last glyph and
/// swallows the sketch's `margin-left: .06em` of the unit, so the unit would
/// touch the digit. The last glyph of the figure therefore gets its own span
/// whose tracking is the positive gap (0.06 em of the unit, at least 2 logical
/// px): the trailing tracking replaces the negative one and the gap shows. One
/// run of text, so the baseline is shared and the unit keeps scaling with the
/// figure inside a `FittedBox`.
List<InlineSpan> exomFigureSpans({
  required String value,
  required double fontSize,
  String? unit,
}) {
  if (unit == null || value.isEmpty) return [TextSpan(text: value)];
  final unitSize = fontSize * 0.4;
  final gap = math.max(2.0, unitSize * 0.06);
  final cut = String.fromCharCodes(value.runes.take(value.runes.length - 1));
  final last = value.substring(cut.length);
  return [
    if (cut.isNotEmpty) TextSpan(text: cut),
    TextSpan(
      text: last,
      style: TextStyle(letterSpacing: gap),
    ),
    TextSpan(
      text: unit,
      style: TextStyle(fontSize: unitSize, letterSpacing: 0),
    ),
  ];
}

/// Protagonist numeral of the L5 redesign (`.x-hero`, `.x-hero-n`, `.x-plain`,
/// `.x-u`): Barlow Condensed 800 with the tight height and tracking of
/// [ExomType.hero96] and friends.
///
/// [value] arrives already formatted for the active locale (L5-D5): this widget
/// never formats or parses it. It is data-coloured by default; with
/// `isData: false` (system operation, `.x-plain`) it takes the text colour.
/// [unit] is painted small beside the value (`.x-u`: 0.4 em, no tracking).
/// [side] sits next to the numeral, bottom aligned, and wraps below it when
/// there is no room.
///
/// The numeral shrinks with `FittedBox(scaleDown)` to the available width
/// instead of wrapping or clipping. Assistive technology reads «value unit» as
/// one node.
class ExomNumeral extends StatelessWidget {
  const ExomNumeral({
    super.key,
    required this.value,
    this.unit,
    this.size = ExomNumeralSize.hero96,
    this.isData = true,
    this.side,
  });

  /// With the sketch line height (.78) the round digits (0, 3, 6, 8, 9) overshoot
  /// the bottom of the line box by up to ~1.8 % of the font size. The box gets
  /// that much room below so the ink never leaves it (nothing is clipped even if
  /// a parent clips to the numeral's bounds). [ExomType] is untouched.
  static const double _inkOvershoot = 0.025;

  /// Key of the numeral text, for tests.
  static const Key valueKey = ValueKey('exom-numeral-value');

  /// Text already formatted for the locale, e.g. «68,4» or «68.4».
  final String value;
  final String? unit;
  final ExomNumeralSize size;

  /// `true`: data colour; `false`: text colour (system operation).
  final bool isData;
  final Widget? side;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final base = switch (size) {
      ExomNumeralSize.hero64 => ExomType.hero64,
      ExomNumeralSize.hero96 => ExomType.hero96,
      ExomNumeralSize.hero120 => ExomType.hero120,
      ExomNumeralSize.hero140 => ExomType.hero140,
    };
    final fontSize = base.fontSize!;
    final style = base.copyWith(
      color: isData ? palette.data : palette.textPrimary,
    );
    final unitText = unit;
    final numeral = Semantics(
      label: unitText == null ? value : '$value $unitText',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.bottomStart,
        child: Padding(
          padding: EdgeInsets.only(bottom: fontSize * _inkOvershoot),
          child: Text.rich(
            TextSpan(
              children: exomFigureSpans(
                value: value,
                unit: unitText,
                fontSize: fontSize,
              ),
            ),
            key: valueKey,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: style,
          ),
        ),
      ),
    );
    final sideWidget = side;
    if (sideWidget == null) return numeral;
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        numeral,
        Padding(
          padding: const EdgeInsets.only(bottom: ExomSpacing.xs),
          child: sideWidget,
        ),
      ],
    );
  }
}
