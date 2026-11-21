import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 50-mark rule of the main goal (`.x-ticks`): [count] marks 2 dp apart and
/// [height] high, bottom aligned. The first `floor(value × count)` are full
/// height in the data colour; of the rest, every fifth is taller (72 %) in the
/// secondary colour and the others are half height in the rule colour.
///
/// [value] is a fraction, clamped to 0..1. Assistive technology gets one node
/// with [semanticsLabel] and the locale percentage as its value.
class ChallengeTickRule extends StatelessWidget {
  const ChallengeTickRule({
    super.key,
    required this.value,
    required this.semanticsLabel,
  });

  final double value;
  final String semanticsLabel;

  static const int count = 50;
  static const double height = 32;
  static const double gap = 2;

  /// Keys of the marks, for tests.
  static const Key onKey = ValueKey('challenge-tick-on');
  static const Key offKey = ValueKey('challenge-tick-off');
  static const Key majorKey = ValueKey('challenge-tick-major');

  double get _fraction => value.isNaN ? 0 : value.clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final fraction = _fraction;
    final on = (fraction * count + 1e-9).floor();
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(fraction);
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: percent,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _mark(
                    i < on
                        ? (onKey, 1.0, palette.data)
                        : (i + 1) % 5 == 0
                        ? (majorKey, 0.72, palette.textSecondary)
                        : (offKey, 0.5, palette.borderSoft),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mark((Key, double, Color) spec) {
    final (key, share, color) = spec;
    return SizedBox(
      width: double.infinity,
      height: height * share,
      child: ColoredBox(key: key, color: color),
    );
  }
}
