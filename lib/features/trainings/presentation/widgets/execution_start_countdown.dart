import 'dart:async';
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Fade of each figure of the countdown (sketch `f5-demo`: 180 ms).
const Duration _figureFade = Duration(milliseconds: 180);

/// The figure change is sequential, never a cross-fade: the default
/// [AnimatedSwitcher] fades the old and the new figure at once in the same
/// stack, so mid-change both 140 px digits drew at about half opacity on top
/// of each other, a lime block behind the figure. The old figure leaves in the
/// first 40 % of [_figureFade] (72 ms) and the new one enters in the remaining
/// 60 % (108 ms), both easing out.
///
/// The outgoing curve runs on a reversing animation (1 -> 0), so its visible
/// part is the top of the range and its curve is flipped to ease out in time.
const Curve _figureIn = Interval(0.4, 1, curve: Curves.easeOut);
const Curve _figureOut = Interval(0.6, 1, curve: FlippedCurve(Curves.easeOut));

/// Five-second start countdown of a timed exercise (L5-F5, sketch
/// `f-resto.html` frames f5-cuenta, f5-demo and f5-160).
///
/// Timing: a wall-clock deadline fixed in [State.initState] and a 50 ms
/// [Timer] decide when it closes; no AnimationController takes part, so
/// reduced motion or Android's «Remove animations» cannot change its length.
/// It pops `true` at the deadline and `false` on «Cancelar», when the app
/// leaves the foreground or when [isValid] turns false; back pops `null`.
/// The caller awaits route.completed before starting the canonical timer.
class ExecutionStartCountdown extends StatefulWidget {
  const ExecutionStartCountdown({super.key, required this.isValid, this.now});
  final bool Function() isValid;
  final DateTime Function()? now;

  @override
  State<ExecutionStartCountdown> createState() =>
      _ExecutionStartCountdownState();
}

class _ExecutionStartCountdownState extends State<ExecutionStartCountdown>
    with WidgetsBindingObserver {
  late final DateTime _deadline;
  Timer? _tick;
  ModalRoute<Object?>? _route;
  int _remaining = 5000;
  bool _closed = false;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _deadline = _now.add(const Duration(seconds: 5));
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _closed) return;
      if (!widget.isValid()) return _close(false);
      final remaining = _deadline
          .difference(_now)
          .inMilliseconds
          .clamp(0, 5000);
      if (remaining == 0) return _close(true);
      setState(() => _remaining = remaining);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of<Object?>(context);
  }

  void _stop() {
    _closed = true;
    _tick?.cancel();
  }

  void _close(bool start) {
    if (_closed) return;
    final route = _route;
    _stop();
    // Back starts the reverse transition before this widget is disposed.
    // Never let a late deadline or lifecycle callback pop the workout below it.
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      route.navigator?.pop(start);
    } else {
      // A covered preparation is interrupted, never a successful start.
      route.navigator?.removeRoute(route, false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _close(false);
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final seconds = (_remaining / 1000).ceil();
    final reducedMotion = ExomMotion.of(context).isReduced;
    final figureStyle = ExomType.hero140.copyWith(
      color: palette.data,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final figureSize = figureStyle.fontSize!;
    final unitSize = figureSize * 0.4;
    return PopScope<bool>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _stop();
      },
      // Flat dialog of the sketch (`.f-dlg`): panel fill, 1 px rule, radius 4,
      // no shadow; it scrolls when the text grows.
      child: Dialog(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ExomRadius.control),
          side: BorderSide(color: palette.borderSoft, width: ExomRule.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                label: l10n.executionPrepareTitle,
                excludeSemantics: true,
                child: Text(
                  l10n.executionPrepareTitle.toUpperCase(),
                  style: ExomType.headline2Section.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.executionPrepareBody,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 16,
                  height: 1.45,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                label: l10n.executionPrepareCountdown(seconds),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The figure is the protagonist (`.x-hero-140`): it
                      // shrinks to the dialog width instead of wrapping.
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.bottomStart,
                          child: Padding(
                            // Room for the ink of round digits below the
                            // tight line box (same allowance as ExomNumeral).
                            padding: EdgeInsets.only(
                              bottom: figureSize * 0.025,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                // Display only: the figure changes over
                                // 180 ms (cut with reduced motion); the
                                // deadline never waits for it. Out, then
                                // in: two lime digits never overlap.
                                AnimatedSwitcher(
                                  duration: reducedMotion
                                      ? Duration.zero
                                      : _figureFade,
                                  switchInCurve: _figureIn,
                                  switchOutCurve: _figureOut,
                                  child: Text(
                                    '$seconds',
                                    key: ValueKey(seconds),
                                    maxLines: 1,
                                    softWrap: false,
                                    style: figureStyle,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    start: math.max(2, unitSize * 0.06),
                                  ),
                                  child: Text(
                                    l10n.executionPrepareUnitSeconds,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: figureStyle.copyWith(
                                      fontSize: unitSize,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Five segments, one per remaining second; a segment
                      // goes off at once when its second ends (`.x-segs`).
                      ExomProgressRule(
                        value: seconds / 5,
                        segments: 5,
                        thickness: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Quiet action (`.btn-quiet`): underlined text colour, full
              // width, at least 48 dp high. Never lime: cancelling is not the
              // goal of the screen.
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(kExomMinTapTarget),
                  foregroundColor: palette.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ExomRadius.control),
                  ),
                  textStyle: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: 0.32,
                    decoration: TextDecoration.underline,
                    decorationColor: palette.textPrimary,
                  ),
                ),
                onPressed: () => _close(false),
                child: Text(
                  l10n.executionPrepareCancel,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
