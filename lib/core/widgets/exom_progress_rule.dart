import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Progress rule of the L5 redesign, in the data colour (`.x-rule`,
/// `.x-rule-4`, `.x-segs`).
///
/// Continuous (default): a [thickness] high track in the rule colour
/// (`borderSoft`) with the [value] share filled in `palette.data` from the
/// start edge. With [segments]: that many equal segments 3 dp apart; the
/// first `floor(value × segments)` are filled in data, the rest are outlined
/// (1 px, secondary colour).
///
/// [value] is a fraction, clamped to 0..1. It needs a bounded width.
/// Semantics: one node whose value is the locale percentage («78 %»); the
/// caller adds a label around it when the context needs one.
class ExomProgressRule extends StatelessWidget {
  const ExomProgressRule({
    super.key,
    required this.value,
    this.thickness = ExomRule.data,
    this.segments,
  }) : assert(segments == null || segments > 0, 'segments must be positive');

  final double value;
  final double thickness;
  final int? segments;

  /// Key of the filled part of the continuous rule, for tests.
  static const Key fillKey = ValueKey('exom-rule-fill');

  /// Key of the track of the continuous rule, for tests.
  static const Key trackKey = ValueKey('exom-rule-track');

  static const double _segmentGap = 3;

  double get _fraction => value.isNaN ? 0 : value.clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final fraction = _fraction;
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(fraction);
    final count = segments;
    return Semantics(
      container: true,
      value: percent,
      child: SizedBox(
        width: double.infinity,
        height: thickness,
        child: count == null
            ? _continuous(palette, fraction)
            : _segmented(palette, fraction, count),
      ),
    );
  }

  Widget _continuous(ExomThemePalette palette, double fraction) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(key: trackKey, color: palette.borderSoft),
          ),
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: constraints.maxWidth * fraction,
            child: KeyedSubtree(
              key: fillKey,
              child: ColoredBox(color: palette.data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmented(ExomThemePalette palette, double fraction, int count) {
    final on = (fraction * count + 1e-9).floor();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: _segmentGap),
          Expanded(
            child: DecoratedBox(
              key: ValueKey(
                i < on ? 'exom-rule-segment-on' : 'exom-rule-segment-off',
              ),
              decoration: i < on
                  ? BoxDecoration(color: palette.data)
                  : BoxDecoration(
                      border: Border.all(
                        color: palette.textSecondary,
                        width: ExomRule.hairline,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
