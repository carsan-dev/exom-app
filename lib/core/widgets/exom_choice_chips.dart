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

  static const double _spacing = 8;
  static const double _minChip = 48;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final motion = ExomMotion.of(context);
    final enabled = onSelected != null;
    final multi = selectedValues;
    final chips = [
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
          onTap: enabled ? () => onSelected!(option) : null,
        ),
    ];
    final perRow = columns;
    if (perRow == null) {
      return Wrap(spacing: _spacing, runSpacing: _spacing, children: chips);
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
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final chip in chips)
              SizedBox(width: width < _minChip ? _minChip : width, child: chip),
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
            style: labelStyle == null
                ? baseStyle
                : baseStyle.merge(labelStyle).copyWith(color: foreground),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}
