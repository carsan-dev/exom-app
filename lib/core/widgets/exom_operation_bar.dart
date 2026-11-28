import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Bar of uploads and system operations (`.bar`): 4 dp, track in the rule
/// colour, fill in the TEXT colour. Never lime and never the data colour
/// (rule D19: a system state is not the client's data).
///
/// [value] (0..1, clamped) fills that share from the start edge. A null
/// [value] is indeterminate: a 35 % segment travels across the bar every
/// 1.4 s, repeating. With reduced motion nothing loops: the segment stays
/// still in the middle.
///
/// Testing: while motion is standard the indeterminate bar schedules frames
/// forever, so `pumpAndSettle` would time out. Pump fixed durations, or use
/// reduced motion (`MediaQuery.disableAnimations`), where it settles. The
/// determinate bar never animates.
///
/// Semantics: a container whose value is the locale percentage when
/// determinate; when indeterminate, no value and the label «En curso»
/// (`buttonBusyA11y`, the same words as a busy button).
class ExomOperationBar extends StatefulWidget {
  const ExomOperationBar({super.key, this.value});

  final double? value;

  /// Key of the filled part, for tests.
  static const Key fillKey = ValueKey('exom-operation-bar-fill');

  @override
  State<ExomOperationBar> createState() => _ExomOperationBarState();
}

class _ExomOperationBarState extends State<ExomOperationBar>
    with SingleTickerProviderStateMixin {
  // M5 (T0.5): unificar con ExomMotionSpec al integrar.
  static const Duration _period = Duration(milliseconds: 1400);
  static const Curve _curve = Cubic(0.45, 0, 0.55, 1);
  static const double _segment = 0.35;

  AnimationController? _controller;

  bool get _loops => widget.value == null && !ExomMotion.of(context).isReduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ExomOperationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_loops) {
      final controller = _controller ??= AnimationController(
        vsync: this,
        duration: _period,
      );
      if (!controller.isAnimating) controller.repeat();
    } else {
      _controller?.stop();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final value = widget.value;
    final fraction = value == null || value.isNaN
        ? null
        : value.clamp(0.0, 1.0).toDouble();
    final fill = KeyedSubtree(
      key: ExomOperationBar.fillKey,
      child: ColoredBox(color: palette.textPrimary),
    );
    return Semantics(
      container: true,
      label: fraction == null
          ? AppLocalizations.of(context).buttonBusyA11y
          : null,
      value: fraction == null
          ? null
          : NumberFormat.percentPattern(
              Localizations.localeOf(context).toLanguageTag(),
            ).format(fraction),
      child: SizedBox(
        width: double.infinity,
        height: ExomRule.bar,
        child: ClipRect(
          child: ColoredBox(
            color: palette.borderSoft,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                if (fraction != null) {
                  return Stack(
                    children: [
                      PositionedDirectional(
                        start: 0,
                        top: 0,
                        bottom: 0,
                        width: width * fraction,
                        child: fill,
                      ),
                    ],
                  );
                }
                final controller = _controller;
                if (!_loops || controller == null) {
                  return Stack(
                    children: [
                      PositionedDirectional(
                        start: width * (1 - _segment) / 2,
                        top: 0,
                        bottom: 0,
                        width: width * _segment,
                        child: fill,
                      ),
                    ],
                  );
                }
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    final t = _curve.transform(controller.value);
                    return Stack(
                      children: [
                        PositionedDirectional(
                          start: width * (-_segment + t * (1 + _segment)),
                          top: 0,
                          bottom: 0,
                          width: width * _segment,
                          child: child!,
                        ),
                      ],
                    );
                  },
                  child: fill,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
