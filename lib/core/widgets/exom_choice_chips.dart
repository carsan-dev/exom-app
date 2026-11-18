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
class ExomChoiceChips<T> extends StatelessWidget {
  const ExomChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.semanticLabelOf,
  });

  final List<T> options;
  final T? selected;
  final String Function(T option) labelOf;
  final String Function(T option)? semanticLabelOf;

  /// Null disables every chip.
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final motion = ExomMotion.of(context);
    final enabled = onSelected != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _Chip(
            label: labelOf(option),
            semanticLabel: semanticLabelOf?.call(option) ?? labelOf(option),
            selected: option == selected,
            enabled: enabled,
            duration: motion.chipCrossfade,
            palette: palette,
            onTap: enabled ? () => onSelected!(option) : null,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.enabled,
    required this.duration,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final bool enabled;
  final Duration duration;
  final ExomThemePalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? palette.background
        : (enabled ? palette.textPrimary : palette.textDisabled);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
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
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
