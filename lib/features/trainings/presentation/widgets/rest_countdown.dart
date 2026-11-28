import 'dart:async';
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

/// Clock read by [RestCountdown] when it gets no `now`. Tests replace it to
/// freeze the figure of a rest; production keeps [DateTime.now].
@visibleForTesting
DateTime Function() restCountdownClock = DateTime.now;

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
/// once a second from when the widget mounted. L5-D48: the bar of the rule
/// ([RestStepRule]) takes its step in the same rebuild, so the figures and
/// the bar change in the same frame.
Duration? untilFigureChange(int remainingMs) {
  if (remainingMs <= 0) return null;
  final shown = (remainingMs + 999) ~/ 1000;
  return Duration(milliseconds: remainingMs - (shown - 1) * 1000);
}

/// Motion of the rest rule «N1 · Barra con tic» (L5-D48, sketch
/// `extension/h-regla-crono-r2.html`): one strong ease-out curve, nothing over
/// 180 ms and no bounce. Reduced motion: no transition and no beat.
abstract final class RestStepMotion {
  /// `cubic-bezier(0.23, 1, 0.32, 1)` of the sketch.
  static const Curve curve = Cubic(0.23, 1, 0.32, 1);

  /// The bar steps down once a second, with the figures.
  static const Duration step = Duration(milliseconds: 140);

  /// «+30 s»: the bar grows to its share of the new total.
  static const Duration rescale = Duration(milliseconds: 180);

  /// «+30 s»: the rebuilt scale fades in.
  static const Duration scaleFade = Duration(milliseconds: 150);

  /// Last seconds: the figure beats 1 → [beatScale] → 1 once a second, from
  /// its bottom start corner, peaking at [beatPeak] of [beat].
  static const Duration beat = Duration(milliseconds: 150);
  static const double beatScale = 1.06;
  static const double beatPeak = 0.35;
  static const int beatLastSeconds = 5;
}

/// Marks of the scale under a [RestStepRule] (sketch N1, `hitos`): from 0 to
/// [totalSeconds] every step of 5, 10, 15, 30, 60, 120 or 300 s, the smallest
/// that leaves at most 5 marks (or a quarter of the total); a mark closer than
/// 12 % of the total to the end gives way to the end mark. 3 to 5 marks from
/// 10 s on (30 s → 0·10·20·30; 90 s → 0·30·60·90).
List<int> restScaleMarks(int totalSeconds) {
  final total = math.max(1, totalSeconds);
  const steps = [5, 10, 15, 30, 60, 120, 300];
  final step = steps.firstWhere(
    (s) => (total / s).ceil() + 1 <= 5,
    orElse: () => (total / 4).ceil(),
  );
  final marks = <int>[];
  for (var v = 0; v < total; v += step) {
    if (v > 0 && (total - v) / total < 0.12) break;
    marks.add(v);
  }
  marks.add(total);
  return marks;
}

/// Rest countdown of the active exercise and of the circuit (L5-E3a, sketch
/// «Descanso» of `e-migradas.html`): «m:ss» at 140 in the data colour with
/// tabular figures (`.x-hero-140`) and, below it, the rule «N1 · Barra con
/// tic» ([RestStepRule], L5-D48). Display only: the persisted `restEndsAt` is
/// the truth and the footer's timer dispatches `FinishRest`; this widget reads
/// the wall clock against [restEndsAt] on each whole second of it
/// ([untilFigureChange], round r3), and the figures, the bar and the beat of
/// the last seconds ([RestFigurePulse]) all come from that one reading.
///
/// Screen readers are not flooded: the node is not a live region; the rest
/// is announced when it starts (or is extended, which re-keys this widget), at
/// 10 s and when it ends.
///
/// Callers key it by [restEndsAt] so each rest (and each «+30 s») starts with
/// fresh state. Inside a [RestCountdownScope] a «+30 s» rescales the bar and
/// its scale to the new total instead of starting over.
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

class _RestCountdownState extends State<RestCountdown>
    with WidgetsBindingObserver {
  Timer? _ticker;
  late final int _total;
  double? _extendedFrom;
  bool _announcedTen = false;
  bool _announcedEnd = false;

  DateTime get _now => (widget.now ?? restCountdownClock)();

  int get _remainingMs =>
      math.max(0, widget.restEndsAt.difference(_now).inMilliseconds);

  int get _remainingSeconds => (_remainingMs / 1000).ceil();

  @override
  void initState() {
    super.initState();
    _total = _resolveTotal();
    _announcedTen = _remainingSeconds <= 10;
    _schedule();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _announce(
        l10n.activeExerciseRestRemainingA11y(
          formatRestClock(_remainingSeconds),
        ),
      );
    });
  }

  /// Length of the rule. A countdown that replaces one of the same scope
  /// whose rest was still running is a «+30 s» only when it is the same rest
  /// ([RestCountdownScope.restId], round r2): the total grows by the time
  /// added and the bar grows from what the previous one showed (L5-D48).
  /// Otherwise, as before: after «+30 s» the remaining time can exceed the
  /// prescribed rest, and the rule then starts full instead of sitting pinned
  /// at 100 %.
  int _resolveTotal() {
    final scope = context.findAncestorStateOfType<_RestCountdownScopeState>();
    final remaining = _remainingSeconds;
    final now = _now;
    final sameRest = scope != null && scope._restId == scope.widget.restId;
    final previousEnd = sameRest ? scope._endsAt : null;
    final previousTotal = sameRest ? scope._total : 0;
    int total;
    if (previousEnd != null &&
        previousTotal > 0 &&
        widget.restEndsAt.isAfter(previousEnd) &&
        previousEnd.isAfter(now)) {
      final added =
          (widget.restEndsAt.difference(previousEnd).inMilliseconds / 1000)
              .ceil();
      total = math.max(previousTotal + added, remaining);
      final shownBefore = (previousEnd.difference(now).inMilliseconds / 1000)
          .ceil();
      _extendedFrom = (shownBefore / previousTotal).clamp(0.0, 1.0).toDouble();
    } else {
      total = math.max(widget.totalSeconds, remaining);
    }
    scope
      ?.._restId = scope.widget.restId
      .._endsAt = widget.restEndsAt
      .._total = total;
    return total;
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

  /// Back from the background (round r2): the timers may not have run while
  /// the app slept, so the figures and the bar read the clock at once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          CountdownFigure(
            seconds: remaining,
            figureKey: const Key('rest-countdown-clock'),
          ),
          const SizedBox(height: RestStepRule.gapAbove),
          // L5-D48: one step a second, in the rebuild of the figures.
          RestStepRule(
            key: const Key('rest-countdown-rule'),
            remainingSeconds: remaining,
            totalSeconds: _total,
            extendedFrom: _extendedFrom,
          ),
        ],
      ),
    );
  }
}

/// Keeps what a [RestCountdown] below it showed, so the countdown that
/// replaces it after a «+30 s» (callers key it by its deadline) rescales the
/// bar to the new total instead of starting over (L5-D48). Place it above the
/// keyed countdown, where it survives the change of key; it lives as long as
/// the rest view and holds no other state.
class RestCountdownScope extends StatefulWidget {
  const RestCountdownScope({
    super.key,
    required this.restId,
    required this.child,
  });

  /// Identity of the rest shown below: equal (`==`) while it is the same rest,
  /// with or without «+30 s», and different for any other rest (another set,
  /// exercise, round or circuit).
  final Object restId;

  final Widget child;

  @override
  State<RestCountdownScope> createState() => _RestCountdownScopeState();
}

class _RestCountdownScopeState extends State<RestCountdownScope> {
  /// Rest that [_endsAt] and [_total] belong to.
  Object? _restId;
  DateTime? _endsAt;
  int _total = 0;

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Big «m:ss» figure of a countdown: the clock of a rest ([RestCountdown]) and
/// of the current phase of a timed set ([ExecutionTimer]). [ExomType.hero140]
/// in the data colour with tabular figures, shrunk to the width by a
/// [FittedBox] (large text never overflows), beating over the last seconds
/// through [RestFigurePulse] while [pulse] is on. Semantics are left to the
/// caller, which knows what already announces the time.
class CountdownFigure extends StatelessWidget {
  const CountdownFigure({
    super.key,
    required this.seconds,
    this.pulse = true,
    this.figureKey,
  });

  /// Whole seconds left, shown with [formatRestClock].
  final int seconds;

  /// Off (e.g. a paused timer): the figure stays still, without a beat.
  final bool pulse;

  /// Key of the [Text] with the figures, for tests and debugging.
  final Key? figureKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: RestFigurePulse(
          seconds: seconds,
          enabled: pulse,
          child: Padding(
            // Room for the ink of round digits below the tight line box
            // (same allowance as ExomNumeral).
            padding: EdgeInsets.only(
              bottom: ExomType.hero140.fontSize! * 0.025,
            ),
            child: Text(
              formatRestClock(seconds),
              key: figureKey,
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
    );
  }
}

/// Beat of the figures over the last [RestStepMotion.beatLastSeconds]
/// seconds (L5-D48): each time [seconds] drops to 5..1 the child scales
/// 1 → 1.06 → 1 in 150 ms from its bottom start corner. Paint only: the layout
/// does not move during the beat. The box keeps room for the beat at its top
/// and end (round r2), so the grown figure stays inside it, also when a
/// [FittedBox] shrinks it to the width, and never covers its neighbours.
/// Reduced motion or a hidden route (TickerMode off): no beat.
class RestFigurePulse extends StatefulWidget {
  const RestFigurePulse({
    super.key,
    required this.seconds,
    this.enabled = true,
    required this.child,
  });

  /// Whole seconds the figures show.
  final int seconds;

  /// Off: no beat, as with reduced motion (a paused timer stays still).
  final bool enabled;
  final Widget child;

  @override
  State<RestFigurePulse> createState() => _RestFigurePulseState();
}

class _RestFigurePulseState extends State<RestFigurePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RestStepMotion.beat,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: RestStepMotion.beatScale,
      ).chain(CurveTween(curve: RestStepMotion.curve)),
      weight: RestStepMotion.beatPeak,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: RestStepMotion.beatScale,
        end: 1,
      ).chain(CurveTween(curve: RestStepMotion.curve)),
      weight: 1 - RestStepMotion.beatPeak,
    ),
  ]).animate(_controller);
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still =
        ExomMotion.of(context).isReduced ||
        !TickerMode.valuesOf(context).enabled;
    if (_still) _controller.value = 0;
  }

  @override
  void didUpdateWidget(RestFigurePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    final seconds = widget.seconds;
    if (!widget.enabled) {
      _controller.value = 0;
      return;
    }
    if (!_still &&
        seconds < oldWidget.seconds &&
        seconds >= 1 &&
        seconds <= RestStepMotion.beatLastSeconds) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.bottomStart,
    widthFactor: RestStepMotion.beatScale,
    heightFactor: RestStepMotion.beatScale,
    child: ScaleTransition(
      key: const Key('rest-figure-pulse'),
      scale: _scale,
      alignment: AlignmentDirectional.bottomStart.resolve(
        Directionality.of(context),
      ),
      child: widget.child,
    ),
  );
}

/// Rule «N1 · Barra con tic» of a rest and of the timer of a timed set
/// (L5-D48, sketch `extension/h-regla-crono-r2.html`): one solid bar
/// [barHeight] high and full width in the data colour over a track in the
/// rule tone, its length the whole seconds left over the total, and under it
/// a scale of 3 to 5 labelled marks ([restScaleMarks]).
///
/// The bar steps when [remainingSeconds] changes, which its callers do on
/// the whole seconds of their deadline, in the rebuild of the figures: a
/// [RestStepMotion.step] tween on [RestStepMotion.curve], so no ticker runs
/// between two seconds. A new [totalSeconds] rescales it in
/// [RestStepMotion.rescale] and fades the new scale in; [extendedFrom] does
/// the same on the first frame, from the share the previous countdown showed
/// («+30 s», [RestCountdownScope]). Reduced motion, a hidden route
/// (TickerMode off) and the first change after the app comes back from the
/// background: the change jumps (round r2). The scale is rebuilt only when
/// [totalSeconds] changes, not on every rebuild of the caller (the timer of a
/// timed set refreshes every 200 ms). Decorative: the figures carry the
/// semantics.
class RestStepRule extends StatefulWidget {
  const RestStepRule({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.extendedFrom,
  });

  /// Whole seconds left, as the figures show them.
  final int remainingSeconds;

  /// Seconds at the full end of the bar.
  final int totalSeconds;

  /// Share of the bar before a «+30 s»: the first frame grows from it.
  final double? extendedFrom;

  /// Space between the figures and the bar (`.r1-bar` margin-top).
  static const double gapAbove = 20;
  static const double barHeight = 8;

  /// Space between the bar and the ticks of the scale.
  static const double scaleGap = 4;
  static const double tickWidth = 2;
  static const double tickHeight = 6;

  /// Top of the labels, under the ticks.
  static const double labelTop = 10;

  /// A middle label closer than this to a neighbour is left out (its tick
  /// stays), so large text never piles labels up.
  static const double minLabelGap = 8;

  /// Share of the total the bar stands for, clamped to 0..1.
  double get value {
    if (totalSeconds <= 0) return 0;
    return (remainingSeconds / totalSeconds).clamp(0.0, 1.0).toDouble();
  }

  @override
  State<RestStepRule> createState() => _RestStepRuleState();
}

class _RestStepRuleState extends State<RestStepRule>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _step = AnimationController(
    vsync: this,
    value: 1,
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: RestStepMotion.scaleFade,
    value: 1,
  );
  late final CurvedAnimation _fadeIn = CurvedAnimation(
    parent: _fade,
    curve: RestStepMotion.curve,
  );
  late double _from;
  late double _to;
  bool _reduced = false;
  bool _muted = false;
  bool _started = false;

  /// The app went to the background: the next change is a catch-up, not a
  /// step, and jumps.
  bool _away = false;

  /// [_RestStepScale] of [_scaleTotal], kept between rebuilds.
  Widget? _scale;
  int? _scaleTotal;

  bool get _still => _reduced || _muted;

  double get _shown =>
      _from + (_to - _from) * RestStepMotion.curve.transform(_step.value);

  @override
  void initState() {
    super.initState();
    _to = widget.value;
    _from = widget.extendedFrom ?? _to;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ExomMotion.of(context).isReduced;
    _muted = !TickerMode.valuesOf(context).enabled;
    if (!_started) {
      _started = true;
      if (!_still && widget.extendedFrom != null) {
        _step.duration = RestStepMotion.rescale;
        _step.forward(from: 0);
        _fade.forward(from: 0);
      }
    }
    if (_still) _settle();
  }

  @override
  void didUpdateWidget(RestStepRule oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rescale = oldWidget.totalSeconds != widget.totalSeconds;
    final value = widget.value;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final jump =
        _still ||
        _away ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed);
    if (value != _to) {
      _from = _shown;
      _to = value;
      if (jump) {
        _settle();
      } else {
        _step.duration = rescale ? RestStepMotion.rescale : RestStepMotion.step;
        _step.forward(from: 0);
      }
      _away = false;
    }
    if (rescale && !jump) _fade.forward(from: 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _away = true;
    _settle();
  }

  /// Ends any running change at its final value.
  void _settle() {
    _step
      ..stop()
      ..value = 1;
    _fade
      ..stop()
      ..value = 1;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeIn.dispose();
    _step.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: SizedBox(
              height: RestStepRule.barHeight,
              child: ColoredBox(
                key: const Key('rest-step-track'),
                color: palette.borderSoft,
                child: AnimatedBuilder(
                  animation: _step,
                  builder: (context, _) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      key: const Key('rest-step-bar'),
                      widthFactor: _shown.clamp(0.0, 1.0).toDouble(),
                      heightFactor: 1,
                      child: ColoredBox(color: palette.data),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: RestStepRule.scaleGap),
          FadeTransition(
            key: const Key('rest-step-scale'),
            opacity: _fadeIn,
            // The same instance while the total holds, so the caller's
            // rebuilds skip it (its own dependencies still rebuild it).
            child: _scaleTotal == widget.totalSeconds
                ? _scale!
                : _scale = _RestStepScale(
                    totalSeconds: _scaleTotal = widget.totalSeconds,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Scale of a [RestStepRule] (`.r1-scale`): a short tick and a label at 13 in
/// the secondary colour on each of [restScaleMarks]; the first sits at the
/// start, the last («N s») at the end and the others centred on their time.
class _RestStepScale extends StatelessWidget {
  const _RestStepScale({required this.totalSeconds});

  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final style = ExomType.kicker.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: palette.textSecondary,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final total = math.max(1, totalSeconds);
    final marks = restScaleMarks(total);
    final last = marks.length - 1;
    final labels = [
      for (var i = 0; i <= last; i++)
        i == last
            ? '${numbers.format(marks[i])} ${l10n.activeExerciseUnitSeconds}'
            : numbers.format(marks[i]),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final widths = <double>[];
        var lineHeight = 0.0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          widths.add(painter.width);
          lineHeight = math.max(lineHeight, painter.height);
          painter.dispose();
        }
        double at(int i) => marks[i] / total * width;
        double tickStart(int i) => i == 0
            ? 0
            : i == last
            ? width - RestStepRule.tickWidth
            : at(i) - RestStepRule.tickWidth / 2;
        double labelStart(int i) => i == 0
            ? 0
            : i == last
            ? width - widths[i]
            : at(i) - widths[i] / 2;
        final shown = List<bool>.filled(labels.length, true);
        var previousEnd = widths.first;
        final lastStart = labelStart(last);
        for (var i = 1; i < last; i++) {
          final start = labelStart(i);
          final end = start + widths[i];
          if (start < previousEnd + RestStepRule.minLabelGap ||
              end > lastStart - RestStepRule.minLabelGap) {
            shown[i] = false;
          } else {
            previousEnd = end;
          }
        }
        return SizedBox(
          height: RestStepRule.labelTop + lineHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i <= last; i++)
                PositionedDirectional(
                  start: tickStart(i),
                  top: 0,
                  width: RestStepRule.tickWidth,
                  height: RestStepRule.tickHeight,
                  child: ColoredBox(
                    key: const ValueKey('rest-step-tick'),
                    color: palette.textSecondary,
                  ),
                ),
              for (var i = 0; i <= last; i++)
                if (shown[i])
                  PositionedDirectional(
                    start: labelStart(i),
                    top: RestStepRule.labelTop,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      softWrap: false,
                      style: style,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
