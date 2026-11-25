import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:flutter/material.dart';

/// Rating scale of the L5 redesign (`.x-scale`, `.x-scale-ends`, `.x-chip`):
/// one chip per integer from [min] to [max] (1-5 or 1-10), composed on
/// [ExomChoiceChips], so the selection is the text-coloured fill (never lime),
/// crossfading in `ExomMotion.chipCrossfade`.
///
/// The values sit in rows of five equal columns (1-10 takes two rows), each
/// at least 48x48, with the numbers in Barlow Condensed 800. [lowLabel] and
/// [highLabel] are painted under the first and last values and appended to
/// their spoken labels.
///
/// A radio group: every chip is a button in a mutually exclusive group with
/// its selected state. Tapping the selected value does nothing unless
/// [allowDeselect], which clears it (`onChanged(null)`). A null [onChanged]
/// disables the scale.
///
/// [chipKeyOf] (optional, L5-E2b) keys each value's chip; without it the
/// chips have no key.
class ExomScaleChips extends StatelessWidget {
  const ExomScaleChips({
    super.key,
    required this.min,
    required this.max,
    this.selected,
    this.onChanged,
    this.lowLabel,
    this.highLabel,
    this.semanticLabelOf,
    this.allowDeselect = false,
    this.chipKeyOf,
  }) : assert(min < max, 'min must be below max');

  final int min;
  final int max;
  final int? selected;
  final ValueChanged<int?>? onChanged;
  final String? lowLabel;
  final String? highLabel;

  /// Spoken label of each value; by default the number, with [lowLabel] and
  /// [highLabel] on the first and last. Use it to give the question and the
  /// maximum when the scale stands alone in a form.
  final String Function(int value)? semanticLabelOf;
  final bool allowDeselect;

  /// Key of the chip of each value; null leaves the chips without a key.
  final Key Function(int value)? chipKeyOf;

  static const int _columns = 5;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final change = onChanged;
    final low = lowLabel;
    final high = highLabel;
    final endStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 13,
      height: 1.3,
      color: palette.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExomChoiceChips<int>(
          options: [for (var v = min; v <= max; v++) v],
          selected: selected,
          labelOf: (v) => '$v',
          semanticLabelOf:
              semanticLabelOf ??
              (v) {
                if (v == min && low != null) return '$v, $low';
                if (v == max && high != null) return '$v, $high';
                return '$v';
              },
          columns: _columns,
          chipKeyOf: chipKeyOf,
          labelStyle: const TextStyle(
            fontFamily: AppTheme.displayFontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
          onSelected: change == null
              ? null
              : (v) {
                  if (v != selected) {
                    change(v);
                  } else if (allowDeselect) {
                    change(null);
                  }
                },
        ),
        if (low != null || high != null) ...[
          const SizedBox(height: ExomSpacing.xs),
          // Spoken with the first and last chips instead.
          ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(low ?? '', style: endStyle)),
                const SizedBox(width: ExomSpacing.md),
                Expanded(
                  child: Text(
                    high ?? '',
                    textAlign: TextAlign.end,
                    style: endStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
