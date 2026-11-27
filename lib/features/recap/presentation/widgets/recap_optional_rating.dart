import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Optional rating of the form (D14-4): a scale of chips from [min] to [max]
/// (1-10, stress 0-5) and a «sin dato» chip. [value] is what the form keeps:
/// an integer in the range, or `null`. «Sin dato» and tapping the chosen value
/// again both give `null`.
class RecapOptionalRating extends StatelessWidget {
  final String label;
  final String helper;
  final int? value;
  final int min;
  final int max;
  final ValueChanged<int?> onChanged;
  final int? number;

  const RecapOptionalRating({
    super.key,
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    final current = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...recapFieldHeader(
          context,
          label: label,
          helperText: helper,
          number: number,
        ),
        ExomScaleChips(
          min: min,
          max: max,
          selected: current,
          allowDeselect: true,
          // Spoken with the question and the maximum, like the tooltip before.
          semanticLabelOf: (rating) => '$label: $rating / $max',
          onChanged: onChanged,
        ),
        const SizedBox(height: ExomSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExomChoiceChips<bool>(
            options: const [true],
            selected: current == null ? true : null,
            labelOf: (_) => AppLocalizations.of(context).optionalRatingNoData,
            onSelected: (_) => onChanged(null),
          ),
        ),
      ],
    );
  }
}
