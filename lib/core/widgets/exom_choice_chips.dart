import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/material.dart';

/// Single-select row of chips (e.g. RIR 0-5+), sketch «A · Hoja de registro».
///
/// Each chip is at least 48x48 with a 1 px `muted` border and radius 4; the
/// selected chip is filled with `text` and labelled in the background colour.
/// The change crossfades in [ExomMotion.chipCrossfade] (120 ms with reduced
/// motion). Chips wrap onto several lines when they do not fit.
///
/// Each chip is a button in a mutually exclusive group with its selected
/// state exposed; [semanticLabelOf] gives a fuller spoken label.
///
/// [ExomChoiceChips.multi] (L5 T0.4, `.x-chips`) is the multi-select variant:
/// every selected chip shows a check before its label and is exposed as a
/// checked button, not as part of an exclusive group.
///
/// [columns] (optional) lays the chips out in rows of that many equal columns
/// (`.x-scale`), dropping columns while a chip would be narrower than 48.
/// [labelStyle] (optional) is merged over the label style; the colour always
/// follows the chip state. Without them the layout is the original one.
///
/// [fitLabels] (optional, with [columns]; L5-A4 D2, sketch A1 `.a-fit`): when
/// the longest word of any label does not fit its chip at the current text
/// scale, all labels shrink together until it fits, so a word never breaks
/// inside. Off by default: the labels keep their size and wrap.
class ExomChoiceChips<T> extends StatelessWidget {
  const ExomChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.semanticLabelOf,
    this.columns,
    this.labelStyle,
    this.fitLabels = false,
  }) : selectedValues = null;

  /// Multi-select chips: [selectedValues] are the selected options and
  /// [onToggled] receives the tapped option (the caller adds or removes it).
  /// A null [onToggled] disables every chip.
  const ExomChoiceChips.multi({
    super.key,
    required this.options,
    required Set<T> this.selectedValues,
    required this.labelOf,
    required ValueChanged<T>? onToggled,
    this.semanticLabelOf,
    this.columns,
    this.labelStyle,
    this.fitLabels = false,
  }) : selected = null,
       onSelected = onToggled;

  final List<T> options;
  final T? selected;
  final String Function(T option) labelOf;
  final String Function(T option)? semanticLabelOf;

  /// Selected options of the multi-select variant; null when single-select.
  final Set<T>? selectedValues;

  /// Null disables every chip.
  final ValueChanged<T>? onSelected;

  /// Equal columns per row, or null for content-width chips.
  final int? columns;

  /// Merged over the label style (the colour is always the state colour).
  final TextStyle? labelStyle;

  /// With [columns], shrink every label together so no word breaks inside.
  final bool fitLabels;

  static const double _spacing = 8;
  static const double _minChip = 48;

  /// Horizontal padding and border of a chip around its label.
  static const double _labelInset = 2 * (6 + 1);

  /// Space the check and its gap take before a selected multi label.
  static const double _checkInset = 18 + 6;

  /// Label style of a chip before its state colour.
  static TextStyle _baseLabelStyle(TextStyle? labelStyle) {
    const base = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    return labelStyle == null ? base : base.merge(labelStyle);
  }

  /// Font size at which the longest word of every label fits [available]
  /// logical pixels with [scaler]; null when it already fits. The size is
  /// searched with the scaler itself, which may be nonlinear (Android 14+).
  /// Smallest label size the refit may reach, in logical font pixels before
  /// the scaler: 10 there is 10 sp of visible text for the active scaler.
  /// Below it the word splits across lines instead of shrinking further.
  static const double _minFittedFontSize = 10;

  double? _fittedFontSize(
    double available,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final style = _baseLabelStyle(labelStyle);
    final base = style.fontSize ?? 16;
    final words = [
      for (final option in options)
        for (final word in labelOf(option).split(RegExp(r'\s+')))
          if (word.isNotEmpty) word,
    ];
    double widest(double fontSize) {
      var widest = 0.0;
      for (final word in words) {
        final painter = TextPainter(
          text: TextSpan(
            text: word,
            style: style.copyWith(fontSize: fontSize),
          ),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
      return widest;
    }

    if (available <= 0 || widest(base) <= available) return null;
    // A small margin so the shrunk word does not wrap on rounding.
    final target = available * 0.98;
    var low = 0.0;
    var high = base;
    for (var i = 0; i < 16; i++) {
      final mid = (low + high) / 2;
      if (widest(mid) <= target) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return math.max(low, math.min(base, _minFittedFontSize));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final motion = ExomMotion.of(context);
    final enabled = onSelected != null;
    final multi = selectedValues;
    List<Widget> chipsWith([double? fontSize]) => [
      for (final option in options)
        _Chip(
          label: labelOf(option),
          semanticLabel: semanticLabelOf?.call(option) ?? labelOf(option),
          selected: multi == null ? option == selected : multi.contains(option),
          multi: multi != null,
          enabled: enabled,
          duration: motion.chipCrossfade,
          palette: palette,
          labelStyle: labelStyle,
          fontSize: fontSize,
          onTap: enabled ? () => onSelected!(option) : null,
        ),
    ];
    final perRow = columns;
    if (perRow == null) {
      return Wrap(
        spacing: _spacing,
        runSpacing: _spacing,
        children: chipsWith(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        var n = perRow < 1 ? 1 : perRow;
        double widthFor(int count) =>
            (constraints.maxWidth - _spacing * (count - 1)) / count;
        while (n > 1 && widthFor(n) < _minChip) {
          n--;
        }
        // A hair less than the exact share, so rounding never pushes the last
        // chip of a row onto the next one.
        final width = widthFor(n) - 0.01;
        final chipWidth = width < _minChip ? _minChip : width;
        final fontSize = fitLabels
            ? _fittedFontSize(
                chipWidth - _labelInset - (multi == null ? 0 : _checkInset),
                MediaQuery.textScalerOf(context),
                Directionality.of(context),
              )
            : null;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final chip in chipsWith(fontSize))
              SizedBox(width: chipWidth, child: chip),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.multi,
    required this.enabled,
    required this.duration,
    required this.palette,
    required this.labelStyle,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final bool multi;
  final bool enabled;
  final Duration duration;
  final ExomThemePalette palette;
  final TextStyle? labelStyle;

  /// Fitted label size ([ExomChoiceChips.fitLabels]); null keeps the style's.
  final double? fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? palette.background
        : (enabled ? palette.textPrimary : palette.textDisabled);
    final baseStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: foreground,
    );
    final fitted = fontSize;
    final text = Text(label, textAlign: TextAlign.center);
    final Widget content = multi && selected
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 18, color: foreground),
              const SizedBox(width: 6),
              Flexible(child: text),
            ],
          )
        : text;
    return Semantics(
      container: true,
      button: true,
      selected: multi ? null : selected,
      checked: multi ? selected : null,
      inMutuallyExclusiveGroup: multi ? null : true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.linear,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          // No `alignment` here: inside a Wrap it would expand the chip to
          // the full run width. The Center below keeps it content-width.
          decoration: BoxDecoration(
            color: selected ? palette.textPrimary : null,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? palette.textPrimary : palette.textSecondary,
              width: 1,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style:
                (labelStyle == null
                        ? baseStyle
                        : baseStyle
                              .merge(labelStyle)
                              .copyWith(color: foreground))
                    .copyWith(fontSize: fitted),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}
