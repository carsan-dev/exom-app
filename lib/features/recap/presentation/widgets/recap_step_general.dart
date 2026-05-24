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
    final stressLevel = (formData['stress_level'] as num?)?.toInt() ?? 3;
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: l10n.generalState,
            subtitle: l10n.yourMentalAndEmotionalContextAlsoMatters,
            icon: Icons.mood,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: l10n.mainMood,
                  helperText: l10n.howYouFeltMostOfTheWeek,
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
                    l10n.rateStressLevel,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    l10n.enableItIfYouWantToReportThePressureOrLoadOfTheWeek,
                    style: TextStyle(color: palette.textDisabled),
                  ),
                ),
                if (stressEnabled) ...[
                  const SizedBox(height: 8),
                  RecapEmojiRatingField(
                    label: l10n.perceivedStress,
                    helperText: l10n.howMuchStressDidYouFeelThisWeek,
                    value: (stressLevel - 1).clamp(0, 4),
                    onChanged: (value) => onChanged('stress_level', value + 1),
                  ),
                ],
                const SizedBox(height: 20),
                RecapTextAreaField(
                  label: l10n.notes,
                  hintText: l10n.shareAnyRelevantDetailFromYourWeek,
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
