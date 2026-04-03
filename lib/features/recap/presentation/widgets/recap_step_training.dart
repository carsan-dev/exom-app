import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';

import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';

class RecapStepTraining extends StatelessWidget {
  final Map<String, dynamic> formData;
  final void Function(String field, dynamic value) onChanged;

  const RecapStepTraining({
    super.key,
    required this.formData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trainingEffort = (formData['training_effort'] as num?)?.toInt() ?? 2;
    final trainingSessions =
        (formData['training_sessions'] as num?)?.toInt() ?? 2;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: l10n.loadAndFeelings,
            subtitle: l10n.tellUsHowYouFeltTrainingThisWeek,
            icon: Icons.fitness_center,
            child: Column(
              children: [
                RecapEmojiRatingField(
                  label: l10n.overallEffort,
                  helperText: l10n.howDidYouFeelWithTheTrainingLoad,
                  value: trainingEffort.round().clamp(0, 4),
                  onChanged: (value) => onChanged('training_effort', value),
                ),
                const SizedBox(height: 20),
                RecapEmojiRatingField(
                  label: l10n.completedSessions,
                  helperText: l10n.howDoYouRateTheNumberOfSessions,
                  value: trainingSessions.round().clamp(0, 4),
                  onChanged: (value) => onChanged('training_sessions', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: l10n.perceivedProgress,
            subtitle: l10n.chooseTheProgressThatBestReflectsYourWeek,
            icon: Icons.trending_up,
            child: RecapChoiceChipsField(
              label: l10n.progressPerception,
              helperText: l10n.yourOverallFeelingAboutThePlanProgress,
              value: formData['training_progress'] as String?,
              options: const [
                'NADA',
                'POCO',
                'ESTABLE',
                'MEJORANDO',
                'EXCELENTE',
              ],
              onSelected: (value) => onChanged('training_progress', value),
            ),
          ),
          RecapSectionCard(
            title: l10n.trainingNotes,
            subtitle: l10n.addContextSoYourCoachCanReviewYourWeekBetter,
            icon: Icons.notes,
            child: RecapTextAreaField(
              label: l10n.recapTrainingObservations,
              hintText: l10n.egItWasHardToKeepThePaceOnThursday,
              initialValue: formData['training_notes'] as String? ?? '',
              onChanged: (value) => onChanged('training_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
