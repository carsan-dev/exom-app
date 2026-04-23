import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class RestTimerOverlay extends StatefulWidget {
  final int restSeconds;
  final String? nextExerciseName;
  final VoidCallback onDone;

  const RestTimerOverlay({
    super.key,
    required this.restSeconds,
    this.nextExerciseName,
    required this.onDone,
  });

  static Future<void> show(
    BuildContext context, {
    required int restSeconds,
    String? nextExerciseName,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RestTimerOverlay(
        restSeconds: restSeconds,
        nextExerciseName: nextExerciseName,
        onDone: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<RestTimerOverlay> createState() => _RestTimerOverlayState();
}

class _RestTimerOverlayState extends State<RestTimerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.restSeconds;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.restSeconds),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        HapticFeedback.mediumImpact();
        widget.onDone();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: GlassDecoration.elevated(borderRadius: 28),
          padding: EdgeInsets.fromLTRB(24, 20, 24, 40 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.restTimerTitle,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: palette.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CircularProgressIndicator(
                          value: 1 - _controller.value,
                          strokeWidth: 8,
                          backgroundColor: palette.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            palette.primary,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '$_remaining',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.nextExerciseName != null) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.restTimerNextExercise(widget.nextExerciseName!),
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _timer.cancel();
                    widget.onDone();
                  },
                  child: Text(l10n.restTimerSkip),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

