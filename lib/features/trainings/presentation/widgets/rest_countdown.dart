import 'dart:async';
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// «m:ss» of a remaining duration in whole seconds.
String formatRestClock(int seconds) {
  final safe = math.max(0, seconds);
  return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
}

/// Rest countdown of the active exercise (sketch «A · Descanso»): big «m:ss»
/// in the display face with tabular figures and a thin progress rule in the
/// text colour (never lime). Display only: the persisted `restEndsAt` is the
/// truth and the footer's timer dispatches `FinishRest`; this widget reads
/// the wall clock against [restEndsAt] once a second.
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
    // let the bar travel there in one second. Reduced motion: one step per
    // second. Whole seconds keep the frame deterministic for a given clock.
    final ahead = motion.isReduced ? remaining : math.max(0, remaining - 1);
    final fraction = _total <= 0
        ? 0.0
        : (ahead / _total).clamp(0.0, 1.0).toDouble();

    return Semantics(
      container: true,
      label: l10n.activeExerciseRestRemainingA11y(clock),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                clock,
                key: const Key('rest-countdown-clock'),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppTheme.displayFontFamily,
                  fontSize: 96,
                  fontWeight: FontWeight.w800,
                  height: 0.95,
                  letterSpacing: -1.92,
                  color: palette.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(color: palette.borderSoft),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  key: const Key('rest-countdown-rule'),
                  duration: motion.isReduced
                      ? Duration.zero
                      : const Duration(seconds: 1),
                  curve: Curves.linear,
                  widthFactor: fraction,
                  heightFactor: 1,
                  child: ColoredBox(color: palette.textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
