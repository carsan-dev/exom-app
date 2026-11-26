import 'dart:async';
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

/// «m:ss» of a remaining duration in whole seconds.
String formatRestClock(int seconds) {
  final safe = math.max(0, seconds);
  return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
}

/// Time until the figures of [remainingMs] change: the whole seconds rounded
/// up, as [formatRestClock] shows them, drop by one exactly when the time left
/// reaches the next whole second of the deadline. Null once nothing is left.
///
/// Round r3 (D1): the figures are refreshed on these boundaries instead of
/// once a second from when the widget mounted, so they change in the same
/// frame as the rule, which reads the same deadline every frame.
Duration? untilFigureChange(int remainingMs) {
  if (remainingMs <= 0) return null;
  final shown = (remainingMs + 999) ~/ 1000;
  return Duration(milliseconds: remainingMs - (shown - 1) * 1000);
}

/// Rest countdown of the active exercise and of the circuit (L5-E3a, sketch
/// «Descanso» of `e-migradas.html`): «m:ss» at 140 in the data colour with
/// tabular figures (`.x-hero-140`) and the 50-mark rule below it ([RestTickRule],
/// `.x-ticks`) with its scale «0 · N s» (`.x-stops`). Display only: the
/// persisted `restEndsAt` is the truth and the footer's timer dispatches
/// `FinishRest`; this widget reads the wall clock against [restEndsAt] on each
/// whole second of it ([untilFigureChange], round r3).
///
/// Screen readers are not flooded: the node is not a live region; the rest
/// is announced when it starts (or is extended, which re-keys this widget), at
/// 10 s and when it ends.
///
/// Callers key it by [restEndsAt] so each rest (and each «+30 s») starts with
/// fresh state.
class RestCountdown extends StatefulWidget {
  const RestCountdown({
    super.key,
    required this.restEndsAt,
    required this.totalSeconds,
    this.now,
  });

  final DateTime restEndsAt;
  final int totalSeconds;

  /// Clock override for tests.
  final DateTime Function()? now;

  @override
  State<RestCountdown> createState() => _RestCountdownState();
}

class _RestCountdownState extends State<RestCountdown> {
  Timer? _ticker;
  late final int _total;
  bool _announcedTen = false;
  bool _announcedEnd = false;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  int get _remainingMs =>
      math.max(0, widget.restEndsAt.difference(_now).inMilliseconds);

  int get _remainingSeconds => (_remainingMs / 1000).ceil();

  @override
  void initState() {
    super.initState();
    // After «+30 s» the remaining time can exceed the prescribed rest: the
    // rule then starts full instead of sitting pinned at 100 %.
    _total = math.max(widget.totalSeconds, _remainingSeconds);
    _announcedTen = _remainingSeconds <= 10;
    _schedule();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _announce(
        l10n.activeExerciseRestRemainingA11y(formatRestClock(_remainingSeconds)),
      );
    });
  }

  /// Next refresh on the next whole second of [RestCountdown.restEndsAt]; a
  /// rest already over is announced a second after mounting, as before.
  void _schedule() {
    _ticker?.cancel();
    _ticker = Timer(
      untilFigureChange(_remainingMs) ?? const Duration(seconds: 1),
      _tick,
    );
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _remainingSeconds;
    final l10n = AppLocalizations.of(context);
    if (remaining <= 0) {
      if (!_announcedEnd) {
        _announcedEnd = true;
        _announce(l10n.activeExerciseRestFinishedA11y);
      }
    } else {
      if (remaining <= 10 && !_announcedTen) {
        _announcedTen = true;
        _announce(l10n.activeExerciseRestTenSecondsA11y);
      }
      // A timer firing a hair early lands here again before the change.
      _schedule();
    }
    setState(() {});
  }

  void _announce(String message) {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final remaining = _remainingSeconds;
    final clock = formatRestClock(remaining);

    return Semantics(
      container: true,
      label: l10n.activeExerciseRestRemainingA11y(clock),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                // Room for the ink of round digits below the tight line box
                // (same allowance as ExomNumeral).
                padding: EdgeInsets.only(
                  bottom: ExomType.hero140.fontSize! * 0.025,
                ),
                child: Text(
                  clock,
                  key: const Key('rest-countdown-clock'),
                  maxLines: 1,
                  softWrap: false,
                  style: ExomType.hero140.copyWith(
                    color: palette.data,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // L5-E3e: drained every frame from the deadline; the figures above
          // change on its whole seconds, in the same frame (round r3).
          RestDrainRule(
            key: const Key('rest-countdown-rule'),
            restEndsAt: widget.restEndsAt,
            totalSeconds: _total,
            now: widget.now,
          ),
          const SizedBox(height: 6),
          RestTickScale(totalSeconds: _total),
        ],
      ),
    );
  }
}

/// Scale under a [RestTickRule] (`.x-stops`): «0» at the start and «N s» at
/// the end, in the secondary colour. Shared by the rest countdowns and the
/// timer of a timed set (L5-E3e); its callers keep it out of the semantics.
class RestTickScale extends StatelessWidget {
  const RestTickScale({super.key, required this.totalSeconds});

  /// Seconds at the full end of the rule.
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final stopStyle = ExomType.kicker.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: palette.textSecondary,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(numbers.format(0), style: stopStyle),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            '${numbers.format(totalSeconds)} ${l10n.activeExerciseUnitSeconds}',
            textAlign: TextAlign.end,
            style: stopStyle,
          ),
        ),
      ],
    );
  }
}

/// One mark of a [RestTickLayout]: the slice of time `[startMs, endMs)` it
/// stands for and whether it closes a whole step (tall mark).
class RestTickMark {
  const RestTickMark({
    required this.startMs,
    required this.endMs,
    required this.tall,
  });

  final int startMs;
  final int endMs;
  final bool tall;
}

/// Time-based marks of a [RestTickRule] (L5-E3e, «marcas por segundo»).
///
/// Tall marks sit exactly on the multiples of [stepSeconds], the smallest of
/// [steps] that leaves at most [maxSteps] steps in the duration. Short marks
/// split each step into [subdivisions] equal parts (2 to 5): the count whose
/// total is closest to [targetMarks] without passing [maxMarks] (ties go to
/// fewer marks). A duration off the step ends with a short section; its last
/// mark (the end of the rule) is tall. When that section is a single slice,
/// the mark of the last whole step before it is short, so two tall marks are
/// never adjacent (round r5); the end mark keeps framing the rule and every
/// other tall mark stays on an exact multiple of the step.
///
/// The first mark is a tall boundary marker at t = 0 that stands for no time
/// (`startMs == endMs == 0`), so a tall mark frames each end of the rule
/// (round r3) while the first slice keeps its normal height and two tall marks
/// are never adjacent (round r4). It counts towards [maxMarks].
class RestTickLayout {
  const RestTickLayout._(this.stepSeconds, this.subdivisions, this.marks);

  static const List<int> steps = [
    1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600, 7200, 14400,
  ];
  static const int maxSteps = 20;
  static const int targetMarks = 50;
  static const int maxMarks = 60;

  final int stepSeconds;
  final int subdivisions;
  final List<RestTickMark> marks;

  static final Map<int, RestTickLayout> _cache = {};

  factory RestTickLayout.forSeconds(int seconds) {
    final total = math.max(1, seconds);
    return _cache.putIfAbsent(total, () => _build(total));
  }

  static RestTickLayout _build(int total) {
    final step = steps.firstWhere(
      (s) => (total / s).ceil() <= maxSteps,
      orElse: () => (total / maxSteps).ceil(),
    );
    final totalMs = total * 1000;
    final stepMs = step * 1000;
    List<RestTickMark> layout(int parts) {
      final marks = <RestTickMark>[
        const RestTickMark(startMs: 0, endMs: 0, tall: true),
      ];
      for (var start = 0; start < totalMs; start += stepMs) {
        final end = math.min(start + stepMs, totalMs);
        for (var i = 0; i < parts; i++) {
          final from = start + i * stepMs ~/ parts;
          if (from >= end) break;
          final to = math.min(start + (i + 1) * stepMs ~/ parts, end);
          marks.add(
            RestTickMark(
              startMs: from,
              endMs: to,
              // Whole steps and the end of the rule are tall.
              tall: to == end && (to % stepMs == 0 || to == totalMs),
            ),
          );
        }
      }
      // A short end section of one slice leaves the last whole step tall
      // right before the tall end mark: that whole step gives way (round r5).
      final before = marks.length - 2;
      if (before > 0 && marks[before].tall && marks[before].endMs > 0) {
        final mark = marks[before];
        marks[before] = RestTickMark(
          startMs: mark.startMs,
          endMs: mark.endMs,
          tall: false,
        );
      }
      return marks;
    }

    var best = layout(2);
    var parts = 2;
    for (final candidate in const [3, 4, 5]) {
      final marks = layout(candidate);
      if (marks.length > maxMarks) continue;
      if ((marks.length - targetMarks).abs() <
          (best.length - targetMarks).abs()) {
        best = marks;
        parts = candidate;
      }
    }
    return RestTickLayout._(step, parts, List.unmodifiable(best));
  }
}

/// Rule of a rest (`.x-ticks`): marks 2 dp apart, 32 high and bottom aligned.
///
/// With [totalSeconds] the marks are time based ([RestTickLayout], L5-E3e):
/// each mark is as wide as the time it stands for, tall marks (72 %) open the
/// rule (a marker without time, round r4) and close each whole step of seconds
/// and the others are half height;
/// unlit, both are in the rule colour (round r3). Without it, the former 50
/// even marks with every fifth tall. The marks of the time left ([value] of the whole) are full
/// height in the data colour; the mark at the edge fills from the bottom with
/// the share of it that is left, so the edge falls inside the mark of the real
/// time and the rule drains continuously (principle 5). Decorative: the
/// countdown above carries the semantics.
class RestTickRule extends StatelessWidget {
  const RestTickRule({super.key, required this.value, this.totalSeconds});

  /// Remaining share of the rest, clamped to 0..1.
  final double value;

  /// Length of the rule in seconds; null keeps 50 even marks.
  final int? totalSeconds;

  static const int count = 50;
  static const double height = 32;
  static const double gap = 2;

  static final List<RestTickMark> _even = List.unmodifiable([
    for (var i = 0; i < count; i++)
      RestTickMark(startMs: i, endMs: i + 1, tall: (i + 1) % 5 == 0),
  ]);

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final share = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final seconds = totalSeconds;
    final marks = seconds == null || seconds <= 0
        ? _even
        : RestTickLayout.forSeconds(seconds).marks;
    final left = share * marks.last.endMs;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < marks.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(
                flex: _flex(marks, i),
                child: _mark(marks[i], left, palette),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Width share of mark [i]: the time it stands for. The boundary marker at
  /// 0 has no time and takes the width of the slice next to it, so the marks
  /// stay evenly spaced.
  static int _flex(List<RestTickMark> marks, int i) {
    final length = marks[i].endMs - marks[i].startMs;
    if (length > 0) return length;
    return i + 1 < marks.length
        ? math.max(1, marks[i + 1].endMs - marks[i + 1].startMs)
        : 1;
  }

  Widget _mark(RestTickMark mark, double left, ExomThemePalette palette) {
    final length = mark.endMs - mark.startMs;
    // The boundary marker at 0 (round r4) has no slice to drain: like the
    // instant it stands for, it stays lit while any time is left and goes off
    // when the time is up, in the same frame as «0:00».
    final lit = length <= 0
        ? (left > mark.startMs ? 1.0 : 0.0)
        : ((left - mark.startMs) / length).clamp(0.0, 1.0).toDouble();
    // Whole marks within float noise count as full.
    final full = lit > 1 - 1e-9;
    return Stack(
      key: const ValueKey('rest-countdown-mark'),
      alignment: Alignment.bottomCenter,
      children: [
        // Round r3 (D2): unlit tall and short marks share the rule colour, so
        // the data colour draining over a tall mark stays visible; only the
        // height tells them apart.
        if (!full) _bar(mark.tall ? 0.72 : 0.5, palette.borderSoft),
        if (full)
          _bar(1, palette.data)
        else if (lit > 1e-9)
          _bar(lit, palette.data),
      ],
    );
  }

  Widget _bar(double share, Color color) => SizedBox(
    width: double.infinity,
    height: height * share,
    child: ColoredBox(color: color),
  );
}

/// [RestTickRule] repainted every frame while [running] (L5-E3e, «tirón por
/// segundo»): a [Ticker] rebuilds it with [value] of the frame, so it drains
/// continuously instead of chaining one-second tweens. The ticker follows
/// [TickerMode] (no frames while the route is hidden) and stops on dispose.
/// Reduced motion: no ticker; the rule only changes when its parent rebuilds.
///
/// [LiveTickRule.builder] builds more than the bare rule from the same frame
/// (the timer of a timed set derives its phase, marks and scale there).
/// Either way the frame-driven subtree sits behind a [RepaintBoundary], so a
/// frame repaints only the rule and not the layer of the route.
class LiveTickRule extends StatefulWidget {
  LiveTickRule({
    super.key,
    required double Function(Duration elapsed) value,
    int? totalSeconds,
    this.running = true,
  }) : builder = ((_, elapsed) =>
           RestTickRule(value: value(elapsed), totalSeconds: totalSeconds));

  const LiveTickRule.builder({
    super.key,
    required this.builder,
    this.running = true,
  });

  /// Subtree of this frame; [elapsed] is the ticker's time since it started
  /// (zero before the first frame and with reduced motion).
  final Widget Function(BuildContext context, Duration elapsed) builder;
  final bool running;

  @override
  State<LiveTickRule> createState() => _LiveTickRuleState();
}

class _LiveTickRuleState extends State<LiveTickRule>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _elapsed = Duration.zero;
  bool _reduced = false;

  void _onTick(Duration elapsed) {
    setState(() => _elapsed = elapsed);
  }

  void _sync() {
    final tick = widget.running && !_reduced;
    if (tick && !_ticker.isActive) {
      _elapsed = Duration.zero;
      _ticker.start();
    } else if (!tick && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ExomMotion.of(context).isReduced;
    _sync();
  }

  @override
  void didUpdateWidget(LiveTickRule oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: widget.builder(context, _elapsed));
}

/// Rule of a rest drained every frame from its deadline [restEndsAt].
///
/// Round r2: each frame reads the wall clock, so the rule is the real
/// remaining time over the total. It ends empty exactly at the deadline, a
/// clock change of any size (NTP, a long sleep) shows on the next frame, and a
/// restarted or muted ticker resumes at the right value without animating
/// back. It never rises while the clock runs forward; a real jump of the wall
/// clock backwards does make it rise to the new remaining time, which is
/// accepted (the deadline is the source of truth, as for the figures).
/// Reduced motion: the whole remaining seconds, one step per second when the
/// parent rebuilds.
class RestDrainRule extends StatelessWidget {
  const RestDrainRule({
    super.key,
    required this.restEndsAt,
    required this.totalSeconds,
    this.now,
  });

  final DateTime restEndsAt;
  final int totalSeconds;

  /// Clock override for tests.
  final DateTime Function()? now;

  /// Clock for rules without [now] (golden scenes whose pages build the rest
  /// without a clock); null uses [DateTime.now].
  @visibleForTesting
  static DateTime Function()? debugNow;

  int get _wallMs => math.max(
    0,
    restEndsAt
        .difference(
          now?.call() ?? RestDrainRule.debugNow?.call() ?? DateTime.now(),
        )
        .inMilliseconds,
  );

  double _value({required bool reduced}) {
    final totalMs = totalSeconds * 1000;
    if (totalMs <= 0) return 0;
    final wall = _wallMs;
    final left = reduced ? (wall / 1000).ceil() * 1000 : wall;
    return (left / totalMs).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ExomMotion.of(context).isReduced;
    return LiveTickRule(
      totalSeconds: totalSeconds,
      running: _wallMs > 0,
      value: (_) => _value(reduced: reduced),
    );
  }
}
