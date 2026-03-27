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
    final musclePainZones =
        (formData['muscle_pain_zones'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: AppLocalizations.of(context)!.restAndRecovery,
            subtitle: AppLocalizations.of(context)!.rateHowYourBodyRespondedThisWeek,
            icon: Icons.hotel_outlined,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: AppLocalizations.of(context)!.sleepHoursSectionTitle,
                  helperText: AppLocalizations.of(context)!.selectTheRangeThatRepeatedTheMost,
                  value: formData['sleep_hours_range'] as String?,
                  options: const ['MENOS_5', 'ENTRE_5_6', 'ENTRE_6_7', 'MAS_8'],
                  onSelected: (value) => onChanged('sleep_hours_range', value),
                ),
                const SizedBox(height: 20),
                RecapChoiceChipsField(
                  label: AppLocalizations.of(context)!.fatigueLevel,
                  helperText: AppLocalizations.of(context)!.howYourOverallEnergyFelt,
                  value: formData['fatigue_level'] as String?,
                  options: const ['CANSADO', 'NORMAL', 'BIEN', 'FUERTE'],
                  onSelected: (value) => onChanged('fatigue_level', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: AppLocalizations.of(context)!.discomfortOrTightness,
            subtitle: AppLocalizations.of(context)!.tapTheAreasThatFeltTheMostLoaded,
            icon: Icons.accessibility_new,
            child: Column(
              children: [
                RecapBodyMapField(
                  label: AppLocalizations.of(context)!.areasWithPainOrTension,
                  helperText: AppLocalizations.of(context)!.tapTheAffectedBodyAreas,
                  values: musclePainZones,
                  onChanged: (value) => onChanged('muscle_pain_zones', value),
                ),
                if (musclePainZones.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  RecapChoiceChipsField(
                    label: AppLocalizations.of(context)!.painIntensity,
                    helperText: AppLocalizations.of(context)!.overallLevelOfDiscomfortFelt,
                    value: formData['pain_intensity'] as String?,
                    options: const ['LEVE', 'MODERADO', 'ALTO', 'MUY_ALTO'],
                    onSelected: (value) => onChanged('pain_intensity', value),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: AppLocalizations.of(context)!.recoveryNotes,
            subtitle: AppLocalizations.of(context)!.addAnythingImportantToAdjustThePlan,
            icon: Icons.self_improvement,
            child: RecapTextAreaField(
              label: AppLocalizations.of(context)!.recapTrainingObservations,
              hintText: AppLocalizations.of(context)!.egIStillHaveLowerBackTightness,
              initialValue: formData['recovery_notes'] as String? ?? '',
              onChanged: (value) => onChanged('recovery_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
