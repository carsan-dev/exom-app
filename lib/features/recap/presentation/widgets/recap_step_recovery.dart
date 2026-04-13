import 'package:flutter/material.dart';
import 'package:exom_app/core/models/body_zone.dart';
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
    final musclePainZones = BodyZone.values
        .where((zone) => rawMusclePainZones.contains(zone.name))
        .toSet();
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: l10n.restAndRecovery,
            subtitle: l10n.rateHowYourBodyRespondedThisWeek,
            icon: Icons.hotel_outlined,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: l10n.sleepHoursSectionTitle,
                  helperText: l10n.selectTheRangeThatRepeatedTheMost,
                  value: formData['sleep_hours_range'] as String?,
                  options: const ['MENOS_5', 'ENTRE_5_6', 'ENTRE_6_7', 'MAS_8'],
                  onSelected: (value) => onChanged('sleep_hours_range', value),
                ),
                const SizedBox(height: 20),
                RecapChoiceChipsField(
                  label: l10n.fatigueLevel,
                  helperText: l10n.howYourOverallEnergyFelt,
                  value: formData['fatigue_level'] as String?,
                  options: const ['CANSADO', 'NORMAL', 'BIEN', 'FUERTE'],
                  onSelected: (value) => onChanged('fatigue_level', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: l10n.discomfortOrTightness,
            subtitle: l10n.tapTheAreasThatFeltTheMostLoaded,
            icon: Icons.accessibility_new,
            child: Column(
              children: [
                RecapBodyMapField(
                  label: l10n.areasWithPainOrTension,
                  helperText: l10n.tapTheAffectedBodyAreas,
                  values: musclePainZones,
                  onChanged: (value) => onChanged(
                    'muscle_pain_zones',
                    value.map((zone) => zone.name).toList(growable: false),
                  ),
                ),
                if (rawMusclePainZones.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  RecapChoiceChipsField(
                    label: l10n.painIntensity,
                    helperText: l10n.overallLevelOfDiscomfortFelt,
                    value: formData['pain_intensity'] as String?,
                    options: const ['LEVE', 'MODERADO', 'ALTO', 'MUY_ALTO'],
                    onSelected: (value) => onChanged('pain_intensity', value),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: l10n.recoveryNotes,
            subtitle: l10n.addAnythingImportantToAdjustThePlan,
            icon: Icons.self_improvement,
            child: RecapTextAreaField(
              label: l10n.recapTrainingObservations,
              hintText: l10n.egIStillHaveLowerBackTightness,
              initialValue: formData['recovery_notes'] as String? ?? '',
              onChanged: (value) => onChanged('recovery_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
