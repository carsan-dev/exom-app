import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class RecapOptionalRating extends StatelessWidget {
  final String label;
  final String helper;
  final int? value;
  final int min;
  final int max;
  final ValueChanged<int?> onChanged;

  const RecapOptionalRating({
    super.key,
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        Text(helper, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: Text(AppLocalizations.of(context).optionalRatingNoData),
              selected: value == null,
              onSelected: (_) => onChanged(null),
            ),
            for (var rating = min; rating <= max; rating++)
              ChoiceChip(
                label: Text('$rating'),
                tooltip: '$label: $rating / $max',
                selected: value == rating,
                onSelected: (selected) => onChanged(selected ? rating : null),
              ),
          ],
        ),
      ],
    );
  }
}
