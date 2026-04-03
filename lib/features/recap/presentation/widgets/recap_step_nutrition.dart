import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';

import 'package:exom_app/core/theme/app_theme.dart';
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
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: l10n.weekQuality,
            subtitle: l10n.rateHowYourNutritionWentTheseDays,
            icon: Icons.restaurant_menu,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: l10n.nutritionQuality,
                  helperText: l10n.yourOverallPerceptionOfThisWeeksNutrition,
                  value: formData['nutrition_quality'] as String?,
                  options: const ['BAJA', 'MODERADA', 'ALTA', 'MUY_ALTA'],
                  onSelected: (value) => onChanged('nutrition_quality', value),
                ),
                const SizedBox(height: 20),
                RecapEmojiRatingField(
                  label: l10n.mealQuality,
                  helperText: l10n.howDoYouRateYourNutritionThisWeek,
                  value: foodQuality.clamp(0, 4),
                  onChanged: (value) => onChanged('food_quality', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: l10n.hydration,
            subtitle: l10n.tellUsIfYouPaidAttentionToThisArea,
            icon: Icons.water_drop_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: hydrationEnabled,
                  onChanged: (value) {
                    onChanged('hydration_enabled', value);
                    if (!value) {
                      onChanged('hydration_level', null);
                    }
                  },
                  activeThumbColor: palette.primary,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.iWantToRateMyHydration,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    l10n.enableItIfYouWantToReportHowItWentDuringTheWeek,
                    style: TextStyle(color: palette.textDisabled),
                  ),
                ),
                if (hydrationEnabled) ...[
                  const SizedBox(height: 8),
                  RecapChoiceChipsField(
                    label: l10n.hydrationLevel,
                    helperText: l10n.chooseTheOptionThatFitsYouBest,
                    value: formData['hydration_level'] as String?,
                    options: const ['MALA', 'REGULAR', 'BUENA', 'MUY_BUENA'],
                    onSelected: (value) => onChanged('hydration_level', value),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: l10n.nutritionNotes,
            subtitle: l10n.addContextForIssuesCravingsOrDifficulties,
            icon: Icons.edit_note,
            child: RecapTextAreaField(
              label: l10n.recapTrainingObservations,
              hintText: l10n.egItWasHardToOrganizeBreakfasts,
              initialValue: formData['nutrition_notes'] as String? ?? '',
              onChanged: (value) => onChanged('nutrition_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
