import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';

import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';

class RecapStepRecovery extends StatelessWidget {
  final Map<String, dynamic> formData;
  final void Function(String field, dynamic value) onChanged;

  const RecapStepRecovery({
    super.key,
    required this.formData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rawMusclePainZones =
        (formData['muscle_pain_zones'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    final l10n = AppLocalizations.of(context);
    final hasZones = rawMusclePainZones.isNotEmpty;

    return RecapStepFrame(
      step: 3,
      first: l10n.recapStepRecoveryFirst,
      second: l10n.recapStepRecoverySecond,
      coach: l10n.recapStepRecoveryCoach,
      questions: [
        RecapChoiceChipsField(
          number: 1,
          label: l10n.sleepHoursSectionTitle,
          helperText: l10n.selectTheRangeThatRepeatedTheMost,
          value: formData['sleep_hours_range'] as String?,
          options: const ['MENOS_5', 'ENTRE_5_6', 'ENTRE_6_7', 'MAS_8'],
          onSelected: (value) => onChanged('sleep_hours_range', value),
        ),
        RecapChoiceChipsField(
          number: 2,
          label: l10n.fatigueLevel,
          helperText: l10n.howYourOverallEnergyFelt,
          value: formData['fatigue_level'] as String?,
          options: const ['CANSADO', 'NORMAL', 'BIEN', 'FUERTE'],
          onSelected: (value) => onChanged('fatigue_level', value),
        ),
        RecapBodyMapField(
          number: 3,
          label: l10n.areasWithPainOrTension,
          helperText: l10n.tapTheAffectedBodyAreas,
          values: rawMusclePainZones,
          onChanged: (value) => onChanged('muscle_pain_zones', value),
        ),
        if (hasZones)
          RecapChoiceChipsField(
            number: 4,
            label: l10n.painIntensity,
            helperText: l10n.overallLevelOfDiscomfortFelt,
            value: formData['pain_intensity'] as String?,
            options: const ['LEVE', 'MODERADO', 'ALTO', 'MUY_ALTO'],
            onSelected: (value) => onChanged('pain_intensity', value),
          ),
        RecapTextAreaField(
          number: hasZones ? 5 : 4,
          label: l10n.recoveryNotes,
          hintText: l10n.egIStillHaveLowerBackTightness,
          initialValue: formData['recovery_notes'] as String? ?? '',
          onChanged: (value) => onChanged('recovery_notes', value),
        ),
      ],
    );
  }
}
