import 'dart:math' as math;

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
///
/// A word never breaks inside (L4-I22, sketch A1 `.a-fit`): when the longest
/// word of any label does not fit its segment at the current text scale, all
/// labels shrink together until it fits; otherwise they keep their 16 and
/// wrap between words.
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

  static const double _minHeight = 48;
  static const double _fontSize = 16;

  /// Label style at [fontSize] (16 unless the labels had to shrink).
  static TextStyle _labelStyle(double fontSize) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Font size at which the longest word of every label fits [available]
  /// logical pixels with [scaler]; 16 when it already fits.
  double _fittedFontSize(
    double available,
    TextScaler scaler,
    TextDirection direction,
  ) {
    var factor = 1.0;
    for (final option in options) {
      for (final word in labelOf(option).split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        final painter = TextPainter(
          text: TextSpan(text: word, style: _labelStyle(_fontSize)),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        if (available > 0 && width > available) {
          factor = math.min(factor, available / width);
        }
      }
    }
    // A small margin so the shrunk word does not wrap on rounding.
    return factor < 1 ? _fontSize * factor * 0.98 : _fontSize;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final reduced = ExomMotion.of(context).isReduced;
    final index = options.indexOf(selected);
    assert(index >= 0, 'selected must be one of options');
    final change = onChanged;
    final labelDuration = reduced
        ? ExomMotion.reducedFade
        : ExomMotion.selectionSlide;
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
            final fontSize = _fittedFontSize(
              segment - 2 * ExomSpacing.sm,
              MediaQuery.textScalerOf(context),
              Directionality.of(context),
            );
            return Stack(
              children: [
                if (!reduced && index >= 0)
                  AnimatedPositionedDirectional(
                    duration: ExomMotion.selectionSlide,
                    curve: ExomMotion.inPlaceCurve,
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
                            fontSize: fontSize,
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
    required this.fontSize,
    required this.palette,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool reduced;
  final Duration labelDuration;
  final double minHeight;
  final double fontSize;
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
            style: ExomSegmentedControl._labelStyle(
              fontSize,
            ).copyWith(color: color),
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
