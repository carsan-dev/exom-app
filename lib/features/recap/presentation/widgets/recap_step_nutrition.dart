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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: AppLocalizations.of(context)!.weekQuality,
            subtitle: AppLocalizations.of(context)!.rateHowYourNutritionWentTheseDays,
            icon: Icons.restaurant_menu,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: AppLocalizations.of(context)!.nutritionQuality,
                  helperText: AppLocalizations.of(context)!.yourOverallPerceptionOfThisWeeksNutrition,
                  value: formData['nutrition_quality'] as String?,
                  options: const ['BAJA', 'MODERADA', 'ALTA', 'MUY_ALTA'],
                  onSelected: (value) => onChanged('nutrition_quality', value),
                ),
                const SizedBox(height: 20),
                RecapEmojiRatingField(
                  label: AppLocalizations.of(context)!.mealQuality,
                  helperText: AppLocalizations.of(context)!.howDoYouRateYourNutritionThisWeek,
                  value: foodQuality.clamp(0, 4),
                  onChanged: (value) => onChanged('food_quality', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: AppLocalizations.of(context)!.hydration,
            subtitle: AppLocalizations.of(context)!.tellUsIfYouPaidAttentionToThisArea,
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
                    AppLocalizations.of(context)!.iWantToRateMyHydration,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.enableItIfYouWantToReportHowItWentDuringTheWeek,
                    style: TextStyle(color: palette.textDisabled),
                  ),
                ),
                if (hydrationEnabled) ...[
                  const SizedBox(height: 8),
                  RecapChoiceChipsField(
                    label: AppLocalizations.of(context)!.hydrationLevel,
                    helperText: AppLocalizations.of(context)!.chooseTheOptionThatFitsYouBest,
                    value: formData['hydration_level'] as String?,
                    options: const ['MALA', 'REGULAR', 'BUENA', 'MUY_BUENA'],
                    onSelected: (value) => onChanged('hydration_level', value),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: AppLocalizations.of(context)!.nutritionNotes,
            subtitle: AppLocalizations.of(context)!.addContextForIssuesCravingsOrDifficulties,
            icon: Icons.edit_note,
            child: RecapTextAreaField(
              label: AppLocalizations.of(context)!.recapTrainingObservations,
              hintText: AppLocalizations.of(context)!.egItWasHardToOrganizeBreakfasts,
              initialValue: formData['nutrition_notes'] as String? ?? '',
              onChanged: (value) => onChanged('nutrition_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
