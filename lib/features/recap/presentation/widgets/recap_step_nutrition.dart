import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';

import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';

class RecapStepNutrition extends StatelessWidget {
  final Map<String, dynamic> formData;
  final void Function(String field, dynamic value) onChanged;

  const RecapStepNutrition({
    super.key,
    required this.formData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final foodQuality = (formData['food_quality'] as num?)?.toInt() ?? 2;
    final hydrationEnabled = formData['hydration_enabled'] as bool? ?? false;
    final l10n = AppLocalizations.of(context);

    return RecapStepFrame(
      step: 2,
      first: l10n.recapStepNutritionFirst,
      second: l10n.recapStepNutritionSecond,
      coach: l10n.recapStepNutritionCoach,
      questions: [
        RecapChoiceChipsField(
          number: 1,
          label: l10n.nutritionQuality,
          helperText: l10n.yourOverallPerceptionOfThisWeeksNutrition,
          value: formData['nutrition_quality'] as String?,
          options: const ['BAJA', 'MODERADA', 'ALTA', 'MUY_ALTA'],
          onSelected: (value) => onChanged('nutrition_quality', value),
        ),
        RecapEmojiRatingField(
          number: 2,
          label: l10n.mealQuality,
          helperText: l10n.howDoYouRateYourNutritionThisWeek,
          value: foodQuality.clamp(0, 4),
          onChanged: (value) => onChanged('food_quality', value),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExomSwitchRow(
              label: l10n.iWantToRateMyHydration,
              value: hydrationEnabled,
              onChanged: (value) {
                onChanged('hydration_enabled', value);
                if (!value) {
                  onChanged('hydration_level', null);
                }
              },
            ),
            if (hydrationEnabled) ...[
              const SizedBox(height: 16),
              RecapChoiceChipsField(
                number: 3,
                label: l10n.hydrationLevel,
                helperText: l10n.chooseTheOptionThatFitsYouBest,
                value: formData['hydration_level'] as String?,
                options: const ['MALA', 'REGULAR', 'BUENA', 'MUY_BUENA'],
                onSelected: (value) => onChanged('hydration_level', value),
              ),
            ],
          ],
        ),
        RecapTextAreaField(
          number: hydrationEnabled ? 4 : 3,
          label: l10n.nutritionNotes,
          hintText: l10n.egItWasHardToOrganizeBreakfasts,
          initialValue: formData['nutrition_notes'] as String? ?? '',
          onChanged: (value) => onChanged('nutrition_notes', value),
        ),
      ],
    );
  }
}
