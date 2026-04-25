import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';

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
  });

  @override
  State<RestTimerInline> createState() => _RestTimerInlineState();
}

class _RestTimerInlineState extends State<RestTimerInline> {
  Timer? _ticker;
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
    super.dispose();
  }

  int get _remainingSeconds {
    final remainingMs =
        widget.restEndsAt.difference(DateTime.now()).inMilliseconds;
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil();
  }

  double get _progressValue {
    if (widget.totalSeconds <= 0) return 0;
    return _remainingSeconds.clamp(0, widget.totalSeconds) / widget.totalSeconds;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _handleTick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleTick());
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

    return Container(
      width: double.infinity,
      decoration: GlassDecoration.card(borderRadius: 24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.title ?? l10n.restTimerTitle,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 136,
            height: 136,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _progressValue,
                    strokeWidth: 8,
                    backgroundColor: palette.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                  ),
                ),
                Text(
                  '$_remainingSeconds',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onSkip,
              child: Text(l10n.restTimerSkip),
            ),
          ),
        ],
      ),
    );
  }
}
