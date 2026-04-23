import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a widget with the signature EXOM press feedback:
/// subtle scale-down (0.97) + selection haptic on tap-down.
///
/// Use this anywhere a glass card, stat tile, chip or custom button needs
/// the "it reacts in your hand" iOS feel without bringing a Material InkWell
/// (whose ripple clashes with the glass aesthetic).
class TappableScale extends StatefulWidget {
  const TappableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 120),
    this.haptic = TappableScaleHapticKind.selection,
    this.behavior = HitTestBehavior.opaque,
    this.enabled = true,
  });

  const TappableScale.light({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double scale = 0.97,
    HitTestBehavior behavior = HitTestBehavior.opaque,
    bool enabled = true,
  }) : this(
          key: key,
          child: child,
          onTap: onTap,
          onLongPress: onLongPress,
          scale: scale,
          haptic: TappableScaleHapticKind.light,
          behavior: behavior,
          enabled: enabled,
        );

  const TappableScale.medium({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double scale = 0.96,
    HitTestBehavior behavior = HitTestBehavior.opaque,
    bool enabled = true,
  }) : this(
          key: key,
          child: child,
          onTap: onTap,
          onLongPress: onLongPress,
          scale: scale,
          haptic: TappableScaleHapticKind.medium,
          behavior: behavior,
          enabled: enabled,
        );

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;
  final TappableScaleHapticKind haptic;
  final HitTestBehavior behavior;
  final bool enabled;

  @override
  State<TappableScale> createState() => _TappableScaleState();
}

class _TappableScaleState extends State<TappableScale> {
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _fireHaptic() {
    switch (widget.haptic) {
      case TappableScaleHapticKind.selection:
        HapticFeedback.selectionClick();
      case TappableScaleHapticKind.light:
        HapticFeedback.lightImpact();
      case TappableScaleHapticKind.medium:
        HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _pressed ? widget.scale : 1.0,
      duration: widget.duration,
      curve: Curves.easeOut,
      child: widget.child,
    );

    if (!_interactive) return child;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) {
        _setPressed(true);
        _fireHaptic();
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: child,
    );
  }
}

enum TappableScaleHapticKind { selection, light, medium }
