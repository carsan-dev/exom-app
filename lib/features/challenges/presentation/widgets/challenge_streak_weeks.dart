import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/material.dart';

/// What the weeks grid of the streak shows for a streak of some days
/// (L5-D40): [rows] rows of 7 squares, the first [lit] of them lit, and
/// [earlier] days left out of the grid («+N días anteriores»).
@immutable
class StreakWeeks {
  const StreakWeeks({
    required this.rows,
    required this.lit,
    required this.earlier,
  });

  final int rows;
  final int lit;
  final int earlier;

  /// Squares of the grid, lit or not.
  int get squares => rows * ChallengeStreakWeeks.perRow;
}

/// Grid of a streak of [days] days (L5-D40, sketch `retos-racha.html`
/// «B · Semanas»): one square per day in rows of 7, at most the last
/// [ChallengeStreakWeeks.maxRows] weeks.
///
/// - Up to 28 days: `ceil(d / 7)` rows (at least one) with `d` squares lit.
/// - Over 28 days: 4 rows; the last row lights `d mod 7` squares (all 7 when
///   the remainder is 0) and the three above are full; the rest of the streak
///   is [StreakWeeks.earlier].
/// - No streak (0 or less): one row of 7 dark squares.
StreakWeeks streakWeeksFor(int days) {
  const perRow = ChallengeStreakWeeks.perRow;
  const maxRows = ChallengeStreakWeeks.maxRows;
  const cap = perRow * maxRows;
  if (days <= 0) return const StreakWeeks(rows: 1, lit: 0, earlier: 0);
  if (days <= cap) {
    return StreakWeeks(
      rows: (days + perRow - 1) ~/ perRow,
      lit: days,
      earlier: 0,
    );
  }
  final remainder = days % perRow;
  final lit = (maxRows - 1) * perRow + (remainder == 0 ? perRow : remainder);
  return StreakWeeks(rows: maxRows, lit: lit, earlier: days - lit);
}

/// One-shot permission for the M5 fill of the weeks grid: the first grid that
/// claims it animates; every later one (a pull-to-refresh rebuilds the grid,
/// a reload may change the days) shows its final state at once. The page keeps
/// one gate per opening.
class StreakFillGate {
  bool _claimed = false;

  /// True only the first time.
  bool claim() {
    if (_claimed) return false;
    _claimed = true;
    return true;
  }
}

/// Provides the [StreakFillGate] of a page to the weeks grid below it.
/// Without a scope the grid never animates.
class StreakFillScope extends InheritedWidget {
  const StreakFillScope({super.key, required this.gate, required super.child});

  final StreakFillGate gate;

  static StreakFillGate? maybeGateOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StreakFillScope>()?.gate;

  @override
  bool updateShouldNotify(StreakFillScope oldWidget) => gate != oldWidget.gate;
}

/// Timing of the M5 fill for [lit] squares: each square fades in over
/// [ExomMotion.chipCrossfade], staggered by at most
/// [ExomMotion.milestoneLetterStagger] (40 ms) and never beyond the
/// [ExomMotion.countUp] total (600 ms, the M5 figure count-up). [step] and
/// [fade] are fractions of [total].
({Duration total, double step, double fade}) streakFillTiming(int lit) {
  final fade = ExomMotion.chipCrossfade.inMicroseconds;
  final max = ExomMotion.countUp.inMicroseconds;
  final stagger = ExomMotion.milestoneLetterStagger.inMicroseconds;
  final gaps = math.max(0, lit - 1);
  final step = gaps == 0 ? 0 : math.min(stagger, (max - fade) ~/ gaps);
  final total = gaps * step + fade;
  return (
    total: Duration(microseconds: total),
    step: step / total,
    fade: fade / total,
  );
}

/// Weeks grid of the streak (L5-D40): straight [square] dp squares [gap] dp
/// apart in rows of [perRow], filled from the top; lit squares in the data
/// colour of the theme (the goal rule's token: never lime ink in light) and the
/// others in the rule tone; the whole grid at [opacity].
///
/// Motion (M5, owner's request in round 4): the first grid built under a
/// [StreakFillScope] whose gate it can claim fills its lit squares in reading
/// order, each one fading from the rule tone to the data colour while it grows
/// from [fillScale] to 1, staggered ([streakFillTiming], ease-out, at most
/// 600 ms), with one controller for the whole grid. Dark squares do not move.
/// Reduced motion, no scope, a claimed gate or a change of [days]: the final
/// state directly.
///
/// Decorative: excluded from semantics (the numeral and «Días seguidos» already
/// say the streak).
class ChallengeStreakWeeks extends StatefulWidget {
  const ChallengeStreakWeeks({super.key, required this.days});

  final int days;

  static const int perRow = 7;
  static const int maxRows = 4;
  static const double square = 18;
  static const double gap = 4;
  static const double opacity = 0.5;

  /// Starting scale of a lit square while it fills.
  static const double fillScale = 0.85;

  /// Keys for tests: the grid and its lit and dark squares.
  static const Key gridKey = ValueKey('challenge-weeks-grid');
  static const Key onKey = ValueKey('challenge-weeks-on');
  static const Key offKey = ValueKey('challenge-weeks-off');

  @override
  State<ChallengeStreakWeeks> createState() => _ChallengeStreakWeeksState();
}

class _ChallengeStreakWeeksState extends State<ChallengeStreakWeeks>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  List<Animation<double>> _fills = const [];
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    _resolved = true;
    final gate = StreakFillScope.maybeGateOf(context);
    if (gate == null || !gate.claim()) return;
    final lit = streakWeeksFor(widget.days).lit;
    if (ExomMotion.of(context).isReduced || lit == 0) return;
    final timing = streakFillTiming(lit);
    final controller = AnimationController(vsync: this, duration: timing.total);
    _controller = controller;
    _fills = [
      for (var i = 0; i < lit; i++)
        CurvedAnimation(
          parent: controller,
          curve: Interval(
            math.min(1.0, i * timing.step),
            math.min(1.0, i * timing.step + timing.fade),
            curve: ExomMotion.countUpCurve,
          ),
        ),
    ];
    controller.forward();
  }

  @override
  void didUpdateWidget(ChallengeStreakWeeks oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the first appearance fills; new data shows its final state.
    if (oldWidget.days != widget.days) _stop();
  }

  void _stop() {
    _controller?.dispose();
    _controller = null;
    _fills = const [];
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final weeks = streakWeeksFor(widget.days);
    const perRow = ChallengeStreakWeeks.perRow;
    const gap = ChallengeStreakWeeks.gap;
    return ExcludeSemantics(
      child: Opacity(
        opacity: ChallengeStreakWeeks.opacity,
        child: Column(
          key: ChallengeStreakWeeks.gridKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < weeks.rows; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var column = 0; column < perRow; column++) ...[
                    if (column > 0) const SizedBox(width: gap),
                    _square(row * perRow + column, weeks.lit, palette),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _square(int index, int lit, ExomThemePalette palette) {
    const size = ChallengeStreakWeeks.square;
    if (index >= lit) {
      return SizedBox.square(
        dimension: size,
        child: ColoredBox(
          key: ChallengeStreakWeeks.offKey,
          color: palette.borderSoft,
        ),
      );
    }
    final on = ColoredBox(key: ChallengeStreakWeeks.onKey, color: palette.data);
    if (index >= _fills.length) {
      return SizedBox.square(dimension: size, child: on);
    }
    final fill = _fills[index];
    return SizedBox.square(
      dimension: size,
      // The square starts in the rule tone and the data colour fades over it.
      child: ColoredBox(
        color: palette.borderSoft,
        child: FadeTransition(
          opacity: fill,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: ChallengeStreakWeeks.fillScale,
              end: 1,
            ).animate(fill),
            child: on,
          ),
        ),
      ),
    );
  }
}
