import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Compact rest timer (L5-E3a skin of the sketch «Descanso»): the title, the
/// remaining seconds at 96 in the data colour over the rule «N1 · Barra con
/// tic» ([RestStepRule], L5-D48), an optional subtitle and «Saltar» as a quiet
/// action. Flat on the page: no card, no ring. Same ticker and callbacks as
/// before; the figures change on the whole seconds of [restEndsAt]
/// ([untilFigureChange], round r3), the bar steps in the same rebuild and the
/// figures beat over the last seconds ([RestFigurePulse]).
class RestTimerInline extends StatefulWidget {
  final int totalSeconds;
  final DateTime restEndsAt;
  final VoidCallback onSkip;
  final VoidCallback onFinished;
  final String? title;
  final String? subtitle;

  const RestTimerInline({
    super.key,
    required this.totalSeconds,
    required this.restEndsAt,
    required this.onSkip,
    required this.onFinished,
    this.title,
    this.subtitle,
    this.now,
  });

  /// Clock override for tests.
  final DateTime Function()? now;

  @override
  State<RestTimerInline> createState() => _RestTimerInlineState();
}

class _RestTimerInlineState extends State<RestTimerInline>
    with WidgetsBindingObserver {
  Timer? _ticker;
  Timer? _figure;
  bool _didFinish = false;

  @override
  void initState() {
    super.initState();
    _startTicker();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Back from the background (round r2): the timers may not have run while
  /// the app slept, so the figure and the bar read the clock at once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _handleTick();
    _scheduleFigure();
  }

  @override
  void didUpdateWidget(covariant RestTimerInline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restEndsAt != widget.restEndsAt ||
        oldWidget.totalSeconds != widget.totalSeconds) {
      _didFinish = false;
      _startTicker();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _figure?.cancel();
    super.dispose();
  }

  int get _remainingMs => widget.restEndsAt
      .difference(widget.now?.call() ?? DateTime.now())
      .inMilliseconds;

  int get _remainingSeconds {
    final remainingMs = _remainingMs;
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _handleTick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleTick());
    _scheduleFigure();
  }

  /// Repaints the figure on the next whole second of the deadline (round r3,
  /// D1). The once-a-second tick above still dispatches [onFinished].
  void _scheduleFigure() {
    _figure?.cancel();
    final wait = untilFigureChange(_remainingMs);
    _figure = wait == null
        ? null
        : Timer(wait, () {
            if (!mounted || _didFinish) return;
            setState(() {});
            _scheduleFigure();
          });
  }

  void _handleTick() {
    if (!mounted) return;

    final remaining = _remainingSeconds;
    if (remaining <= 0 && !_didFinish) {
      _didFinish = true;
      _ticker?.cancel();
      HapticFeedback.mediumImpact();
      widget.onFinished();
      return;
    }

    if (!_didFinish) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final remaining = _remainingSeconds;
    final secondary = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      height: 1.4,
      color: palette.textSecondary,
    );

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title ?? l10n.restTimerTitle,
            style: secondary.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: RestFigurePulse(
              seconds: remaining,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: ExomType.hero96.fontSize! * 0.025,
                ),
                child: Text(
                  '$remaining',
                  maxLines: 1,
                  softWrap: false,
                  style: ExomType.hero96.copyWith(
                    color: palette.data,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: RestStepRule.gapAbove),
          RestStepRule(
            remainingSeconds: remaining,
            totalSeconds: widget.totalSeconds,
          ),
          if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(widget.subtitle!, style: secondary),
          ],
          const SizedBox(height: 12),
          Center(
            child: ExomQuietButton(
              label: l10n.restTimerSkip,
              onPressed: widget.onSkip,
            ),
          ),
        ],
      ),
    );
  }
}
