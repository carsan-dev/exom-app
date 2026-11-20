import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:flutter/material.dart';

/// Segmented control of 2 or 3 options (ESPEC §3, `.segc`): radius 4, 1 px
/// `muted` border, equal segments at least 48 high whose labels wrap (never
/// ellipsised). The selected segment is filled with `selectionFill` and
/// labelled in `onSelectionFill` (bone or charcoal, never lime).
///
/// Motion (M4): the fill slides to the new segment in 200 ms ease-out; with
/// reduced motion it does not slide, the new segment fades in over 120 ms.
/// The tap calls [onChanged] at once; the animation only follows.
///
/// Semantics: each segment is a button in a mutually exclusive group with
/// its selected state. A null [onChanged] disables the control.
class ExomSegmentedControl<T> extends StatelessWidget {
  const ExomSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    this.onChanged,
  }) : assert(
         options.length >= 2 && options.length <= 3,
         'A segmented control has 2 or 3 options',
       );

  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T>? onChanged;

  /// Key of the sliding fill (standard motion only), for tests.
  static const Key fillKey = ValueKey('exom-segmented-fill');

  // M4 (T0.5): unificar con ExomMotionSpec al integrar.
  static const Duration _slide = Duration(milliseconds: 200);
  static const Curve _slideCurve = Curves.easeOut;

  static const double _minHeight = 48;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final reduced = ExomMotion.of(context).isReduced;
    final index = options.indexOf(selected);
    assert(index >= 0, 'selected must be one of options');
    final change = onChanged;
    final labelDuration = reduced ? ExomMotion.reducedFade : _slide;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ExomRadius.control),
        border: Border.all(
          color: palette.textSecondary,
          width: ExomRule.hairline,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          ExomRadius.control - ExomRule.hairline,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segment = constraints.maxWidth / options.length;
            return Stack(
              children: [
                if (!reduced && index >= 0)
                  AnimatedPositionedDirectional(
                    duration: _slide,
                    curve: _slideCurve,
                    start: segment * index,
                    width: segment,
                    top: 0,
                    bottom: 0,
                    child: KeyedSubtree(
                      key: fillKey,
                      child: ColoredBox(color: palette.selectionFill),
                    ),
                  ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < options.length; i++)
                        Expanded(
                          child: _Segment(
                            key: ValueKey('exom-segment-$i'),
                            index: i,
                            label: labelOf(options[i]),
                            selected: i == index,
                            reduced: reduced,
                            labelDuration: labelDuration,
                            minHeight: _minHeight,
                            palette: palette,
                            onTap: change == null
                                ? null
                                : () {
                                    if (i != index) change(options[i]);
                                  },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.index,
    required this.label,
    required this.selected,
    required this.reduced,
    required this.labelDuration,
    required this.minHeight,
    required this.palette,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool reduced;
  final Duration labelDuration;
  final double minHeight;
  final ExomThemePalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = selected
        ? palette.onSelectionFill
        : (enabled ? palette.textPrimary : palette.textDisabled);
    final labelBox = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ExomSpacing.sm,
          vertical: ExomSpacing.xs + ExomSpacing.xxs,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: labelDuration,
            curve: Curves.easeOut,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: color,
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: reduced
            ? Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedOpacity(
                      key: ValueKey('exom-segment-fill-$index'),
                      opacity: selected ? 1 : 0,
                      duration: ExomMotion.reducedFade,
                      child: ColoredBox(color: palette.selectionFill),
                    ),
                  ),
                  labelBox,
                ],
              )
            : labelBox,
      ),
    );
  }
}
