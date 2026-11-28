import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_streak_weeks.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Streak milestone of «Retos» (L5-D40, sketch `retos-racha.html`
/// «B · Semanas»; it replaces the bands at ±12° of `b-cuenta.html` «B4»).
///
/// The [value] at 140 in the text colour on a plain band (`.x-band`) and, at
/// the end of the content, the weeks grid of the [days] of the streak
/// ([ChallengeStreakWeeks]) with its bottom on the numeral's alphabetic
/// baseline. When the numeral and the grid do not fit in one row (large text,
/// narrow screens, long streaks) the grid drops below the numeral, still at the
/// end. Days left out of the grid (over 4 weeks) are summed up below it,
/// at the end, with «+N días anteriores» in secondary text.
///
/// Assistive technology reads [semanticsLabel] for the numeral and the
/// «+N días anteriores» text; the grid is decorative.
class ChallengeMilestoneMark extends StatelessWidget {
  const ChallengeMilestoneMark({
    super.key,
    required this.value,
    required this.days,
    required this.semanticsLabel,
  });

  /// Figure already formatted for the locale.
  final String value;

  /// Days of the current streak, for the grid.
  final int days;
  final String semanticsLabel;

  /// Gap between the numeral and the grid in one row (sketch `column-gap`).
  static const double columnGap = 20;

  /// Gap between the numeral and the grid when the grid drops below it.
  static const double runGap = 10;

  /// Gap between the grid and «+N días anteriores» (sketch `.r-more`).
  static const double moreGap = 6;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final earlier = streakWeeksFor(days).earlier;
    return ExomBand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _NumeralWithWeeks(
              numeral: Semantics(
                label: semanticsLabel,
                excludeSemantics: true,
                child: ExomNumeral(
                  value: value,
                  size: ExomNumeralSize.hero140,
                  isData: false,
                ),
              ),
              weeks: ChallengeStreakWeeks(days: days),
            ),
            if (earlier > 0) ...[
              const SizedBox(height: moreGap),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  AppLocalizations.of(
                    context,
                  ).challengesStreakEarlierDays(earlier),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 13,
                    height: 1.35,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Numeral at the start and weeks grid at the end, the grid's bottom on the
/// numeral's alphabetic baseline; the grid goes below the numeral when both do
/// not fit in one row at the numeral's natural width.
class _NumeralWithWeeks extends MultiChildRenderObjectWidget {
  _NumeralWithWeeks({required Widget numeral, required Widget weeks})
    : super(children: [numeral, weeks]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNumeralWithWeeks(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNumeralWithWeeks renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _NumeralWithWeeksParentData extends ContainerBoxParentData<RenderBox> {}

/// Positions and size of one layout pass.
typedef _Arrangement = ({Size size, Offset numeral, Offset weeks});

class _RenderNumeralWithWeeks extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _NumeralWithWeeksParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _NumeralWithWeeksParentData
        > {
  _RenderNumeralWithWeeks({required TextDirection textDirection})
    : _textDirection = textDirection;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _numeral => firstChild!;
  RenderBox get _weeks => childAfter(firstChild!)!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _NumeralWithWeeksParentData) {
      child.parentData = _NumeralWithWeeksParentData();
    }
  }

  _Arrangement _arrange(
    BoxConstraints constraints, {
    required ChildLayouter layoutChild,
    required double? Function(RenderBox child, BoxConstraints constraints)
    baselineOf,
  }) {
    final weeksSize = layoutChild(_weeks, const BoxConstraints());
    final natural = _numeral.getMaxIntrinsicWidth(double.infinity);
    final bounded = constraints.hasBoundedWidth;
    final width = bounded
        ? constraints.maxWidth
        : natural + ChallengeMilestoneMark.columnGap + weeksSize.width;
    final besideWidth =
        width - weeksSize.width - ChallengeMilestoneMark.columnGap;
    final rtl = _textDirection == TextDirection.rtl;

    if (natural <= besideWidth) {
      final numeralConstraints = BoxConstraints(maxWidth: besideWidth);
      final numeralSize = layoutChild(_numeral, numeralConstraints);
      final baseline =
          baselineOf(_numeral, numeralConstraints) ?? numeralSize.height;
      // The grid's bottom sits on the baseline; if the grid is taller than the
      // numeral above its baseline, both move down so nothing goes above 0.
      final shift = math.max(0.0, weeksSize.height - baseline);
      final weeksTop = shift + baseline - weeksSize.height;
      final height = math.max(
        shift + numeralSize.height,
        weeksTop + weeksSize.height,
      );
      return (
        size: constraints.constrain(Size(width, height)),
        numeral: Offset(rtl ? width - numeralSize.width : 0, shift),
        weeks: Offset(rtl ? 0 : width - weeksSize.width, weeksTop),
      );
    }

    final numeralSize = layoutChild(_numeral, BoxConstraints(maxWidth: width));
    final weeksTop = numeralSize.height + ChallengeMilestoneMark.runGap;
    return (
      size: constraints.constrain(Size(width, weeksTop + weeksSize.height)),
      numeral: Offset(rtl ? width - numeralSize.width : 0, 0),
      weeks: Offset(rtl ? 0 : width - weeksSize.width, weeksTop),
    );
  }

  @override
  void performLayout() {
    final arrangement = _arrange(
      constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
      baselineOf: (child, _) =>
          child.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true),
    );
    size = arrangement.size;
    (_numeral.parentData! as _NumeralWithWeeksParentData).offset =
        arrangement.numeral;
    (_weeks.parentData! as _NumeralWithWeeksParentData).offset =
        arrangement.weeks;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _arrange(
    constraints,
    layoutChild: ChildLayoutHelper.dryLayoutChild,
    baselineOf: (child, childConstraints) =>
        child.getDryBaseline(childConstraints, TextBaseline.alphabetic),
  ).size;

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _numeral.getMinIntrinsicWidth(double.infinity),
    _weeks.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _numeral.getMaxIntrinsicWidth(double.infinity) +
      ChallengeMilestoneMark.columnGap +
      _weeks.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
