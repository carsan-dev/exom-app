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
/// [lastSegmentGrowth] (segmented only, default 1) paints the last filled
/// segment filled only that share of its width from the start edge, over its
/// outline: the segment that grows when a form step advances (M9). It does
/// not change [value] or the semantics.
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
    this.lastSegmentGrowth = 1,
  }) : assert(segments == null || segments > 0, 'segments must be positive');

  final double value;
  final double thickness;
  final int? segments;
  final double lastSegmentGrowth;

  /// Key of the growing filled part of the last segment, for tests. It only
  /// exists while [lastSegmentGrowth] is below 1.
  static const Key growthKey = ValueKey('exom-rule-segment-growth');

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
    final growth = lastSegmentGrowth.isNaN
        ? 1.0
        : lastSegmentGrowth.clamp(0.0, 1.0).toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: _segmentGap),
          Expanded(
            child: _segment(
              palette,
              filled: i < on,
              growth: i == on - 1 ? growth : 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _segment(
    ExomThemePalette palette, {
    required bool filled,
    required double growth,
  }) {
    final outlined = BoxDecoration(
      border: Border.all(
        color: palette.textSecondary,
        width: ExomRule.hairline,
      ),
    );
    if (!filled || growth >= 1) {
      return DecoratedBox(
        key: ValueKey(
          filled ? 'exom-rule-segment-on' : 'exom-rule-segment-off',
        ),
        decoration: filled ? BoxDecoration(color: palette.data) : outlined,
      );
    }
    return DecoratedBox(
      key: const ValueKey('exom-rule-segment-off'),
      decoration: outlined,
      child: FractionallySizedBox(
        key: growthKey,
        alignment: AlignmentDirectional.centerStart,
        widthFactor: growth,
        heightFactor: 1,
        child: ColoredBox(color: palette.data),
      ),
    );
  }
}
