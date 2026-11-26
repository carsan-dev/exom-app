import 'dart:async';
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

/// «m:ss» of a remaining duration in whole seconds.
String formatRestClock(int seconds) {
  final safe = math.max(0, seconds);
  return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
}

/// Rest countdown of the active exercise and of the circuit (L5-E3a, sketch
/// «Descanso» of `e-migradas.html`): «m:ss» at 140 in the data colour with
/// tabular figures (`.x-hero-140`) and the 50-mark rule below it ([RestTickRule],
/// `.x-ticks`) with its scale «0 · N s» (`.x-stops`). Display only: the
/// persisted `restEndsAt` is the truth and the footer's timer dispatches
/// `FinishRest`; this widget reads the wall clock against [restEndsAt] once a
/// second.
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
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _announce(
        l10n.activeExerciseRestRemainingA11y(formatRestClock(_remainingSeconds)),
      );
    });
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
      _ticker?.cancel();
    } else if (remaining <= 10 && !_announcedTen) {
      _announcedTen = true;
      _announce(l10n.activeExerciseRestTenSecondsA11y);
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
    final motion = ExomMotion.of(context);
    final remaining = _remainingSeconds;
    final clock = formatRestClock(remaining);
    // Continuous linear drain (principle 5): aim at the next whole second and
    // let the rule travel there in one second. Reduced motion: one step per
    // second. Whole seconds keep the frame deterministic for a given clock.
    final ahead = motion.isReduced ? remaining : math.max(0, remaining - 1);
    final fraction = _total <= 0
        ? 0.0
        : (ahead / _total).clamp(0.0, 1.0).toDouble();
    final numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final stopStyle = ExomType.kicker.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: palette.textSecondary,
    );

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
          TweenAnimationBuilder<double>(
            key: const Key('rest-countdown-rule'),
            tween: Tween<double>(end: fraction),
            duration: motion.isReduced
                ? Duration.zero
                : const Duration(seconds: 1),
            curve: Curves.linear,
            builder: (context, value, _) => RestTickRule(value: value),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(numbers.format(0), style: stopStyle),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${numbers.format(_total)} ${l10n.activeExerciseUnitSeconds}',
                  textAlign: TextAlign.end,
                  style: stopStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rule of 50 marks of a rest (`.x-ticks`): marks 2 dp apart, 32 high and
/// bottom aligned. The first `value × 50` marks are full height in the data
/// colour; of the rest, every fifth is taller (72 %) in the secondary colour
/// and the others are half height in the rule colour. The mark at the edge
/// fills from the bottom with the fraction of a mark that is left, so the
/// rule drains continuously (principle 5) instead of jumping a mark at a
/// time. Decorative: the countdown above carries the semantics.
class RestTickRule extends StatelessWidget {
  const RestTickRule({super.key, required this.value});

  /// Remaining share of the rest, clamped to 0..1.
  final double value;

  static const int count = 50;
  static const double height = 32;
  static const double gap = 2;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final filled = (value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble()) * count;
    final whole = (filled + 1e-9).floor();
    final partial = filled - whole;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(
                child: Stack(
                  key: const ValueKey('rest-countdown-mark'),
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (i >= whole)
                      _bar(
                        (i + 1) % 5 == 0 ? 0.72 : 0.5,
                        (i + 1) % 5 == 0
                            ? palette.textSecondary
                            : palette.borderSoft,
                      ),
                    if (i < whole)
                      _bar(1, palette.data)
                    else if (i == whole && partial > 0)
                      _bar(partial, palette.data),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(double share, Color color) => SizedBox(
    width: double.infinity,
    height: height * share,
    child: ColoredBox(color: color),
  );
}
