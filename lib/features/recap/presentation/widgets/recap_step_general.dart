import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';

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
    final stressLevel = (formData['stress_level'] as num?)?.toInt() ?? 2;
    final palette = context.exomPalette;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: AppLocalizations.of(context)!.generalState,
            subtitle: AppLocalizations.of(context)!.yourMentalAndEmotionalContextAlsoMatters,
            icon: Icons.mood,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: AppLocalizations.of(context)!.mainMood,
                  helperText: AppLocalizations.of(context)!.howYouFeltMostOfTheWeek,
                  value: formData['mood'] as String?,
                  options: const [
                    'MAL',
                    'REGULAR',
                    'NORMAL',
                    'BIEN',
                    'MUY_BIEN',
                  ],
                  onSelected: (value) => onChanged('mood', value),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  value: stressEnabled,
                  onChanged: (value) {
                    onChanged('stress_enabled', value);
                    if (!value) {
                      onChanged('stress_level', null);
                    }
                  },
                  activeThumbColor: palette.primary,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    AppLocalizations.of(context)!.rateStressLevel,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.enableItIfYouWantToReportThePressureOrLoadOfTheWeek,
                    style: TextStyle(color: palette.textDisabled),
                  ),
                ),
                if (stressEnabled) ...[
                  const SizedBox(height: 8),
                  RecapEmojiRatingField(
                    label: AppLocalizations.of(context)!.perceivedStress,
                    helperText: AppLocalizations.of(context)!.howMuchStressDidYouFeelThisWeek,
                    value: stressLevel.clamp(0, 4),
                    onChanged: (value) => onChanged('stress_level', value),
                  ),
                ],
                const SizedBox(height: 20),
                RecapTextAreaField(
                  label: AppLocalizations.of(context)!.notes,
                  hintText: AppLocalizations.of(context)!.shareAnyRelevantDetailFromYourWeek,
                  initialValue: formData['general_notes'] as String? ?? '',
                  onChanged: (value) => onChanged('general_notes', value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
