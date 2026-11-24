import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';

import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';
import 'recap_optional_rating.dart';

int stressLevelFromRatingIndex(int index) => index + 1;

class RecapStepGeneral extends StatelessWidget {
  final Map<String, dynamic> formData;
  final void Function(String field, dynamic value) onChanged;

  const RecapStepGeneral({
    super.key,
    required this.formData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stressEnabled = formData['stress_enabled'] as bool? ?? false;
    final stressLevel = (formData['stress_level'] as num?)?.toInt();
    final l10n = AppLocalizations.of(context);
    // Numbers follow the questions that are shown (the stress one is optional).
    var n = 1;

    return RecapStepFrame(
      step: 4,
      first: l10n.recapStepGeneralFirst,
      second: l10n.recapStepGeneralSecond,
      coach: l10n.recapStepGeneralCoach,
      questions: [
        RecapChoiceChipsField(
          number: n++,
          label: l10n.mainMood,
          helperText: l10n.howYouFeltMostOfTheWeek,
          value: formData['mood'] as String?,
          options: const ['MAL', 'REGULAR', 'NORMAL', 'BIEN', 'MUY_BIEN'],
          onSelected: (value) => onChanged('mood', value),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExomSwitchRow(
              label: l10n.rateStressLevel,
              value: stressEnabled,
              onChanged: (value) {
                onChanged('stress_enabled', value);
                if (!value) {
                  onChanged('stress_level', null);
                }
              },
            ),
            if (stressEnabled) ...[
              const SizedBox(height: 16),
              RecapOptionalRating(
                number: n++,
                label: l10n.perceivedStress,
                helper: l10n.weeklyStressScale,
                value: stressLevel,
                min: 0,
                max: 5,
                onChanged: (value) => onChanged('stress_level', value),
              ),
            ],
          ],
        ),
        RecapOptionalRating(
          number: n++,
          label: l10n.weeklyHunger,
          helper: l10n.weeklyHungerScale,
          value: formData['hunger_level'] as int?,
          onChanged: (value) => onChanged('hunger_level', value),
        ),
        RecapOptionalRating(
          number: n++,
          label: l10n.weeklyEnergy,
          helper: l10n.weeklyEnergyScale,
          value: formData['energy_level'] as int?,
          onChanged: (value) => onChanged('energy_level', value),
        ),
        RecapOptionalRating(
          number: n++,
          label: l10n.weeklyDigestion,
          helper: l10n.weeklyDigestionScale,
          value: formData['digestion_level'] as int?,
          onChanged: (value) => onChanged('digestion_level', value),
        ),
        RecapTextAreaField(
          number: n++,
          label: l10n.notes,
          hintText: l10n.shareAnyRelevantDetailFromYourWeek,
          initialValue: formData['general_notes'] as String? ?? '',
          onChanged: (value) => onChanged('general_notes', value),
        ),
      ],
    );
  }
}
