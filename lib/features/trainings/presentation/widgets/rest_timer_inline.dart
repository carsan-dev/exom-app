import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Compact rest timer (L5-E3a skin of the sketch «Descanso»): the title, the
/// remaining seconds at 96 in the data colour over the 50-mark rule
/// ([RestTickRule]), an optional subtitle and «Saltar» as a quiet action. Flat
/// on the page: no card, no ring. Same ticker and callbacks as before; the
/// rule drains every frame from [restEndsAt] ([RestDrainRule], L5-E3e) and the
/// figures change on its whole seconds ([untilFigureChange], round r3).
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

class _RestTimerInlineState extends State<RestTimerInline> {
  Timer? _ticker;
  Timer? _figure;
  bool _didFinish = false;

  @override
  void initState() {
    super.initState();
    _startTicker();
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
            child: Padding(
              padding: EdgeInsets.only(bottom: ExomType.hero96.fontSize! * 0.025),
              child: Text(
                '$_remainingSeconds',
                maxLines: 1,
                softWrap: false,
                style: ExomType.hero96.copyWith(
                  color: palette.data,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          RestDrainRule(
            restEndsAt: widget.restEndsAt,
            totalSeconds: widget.totalSeconds,
            now: widget.now,
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
