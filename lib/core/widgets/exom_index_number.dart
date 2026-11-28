import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:flutter/material.dart';

/// Index numeral «01», «02»… of the L5 redesign (`.x-no`): Barlow Condensed 800,
/// 20 px, no tracking, tabular figures, in the data colour. Two digits at least;
/// longer numbers keep all their digits.
class ExomIndexNumber extends StatelessWidget {
  const ExomIndexNumber(this.n, {super.key});

  final int n;

  /// `.x-no` is 1.25 em of the 16 px base and has no [ExomType] token: it is the
  /// section style with its size, height and tracking taken from the sketch.
  static TextStyle style(Color color) => ExomType.section.copyWith(
    fontSize: 20,
    height: 1,
    letterSpacing: 0,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Index as painted: at least two digits.
  static String format(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Text(format(n), style: style(context.exomPalette.data));
  }
}
