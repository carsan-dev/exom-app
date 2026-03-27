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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: AppLocalizations.of(context)!.loadAndFeelings,
            subtitle: AppLocalizations.of(context)!.tellUsHowYouFeltTrainingThisWeek,
            icon: Icons.fitness_center,
            child: Column(
              children: [
                RecapEmojiRatingField(
                  label: AppLocalizations.of(context)!.overallEffort,
                  helperText: AppLocalizations.of(context)!.howDidYouFeelWithTheTrainingLoad,
                  value: trainingEffort.round().clamp(0, 4),
                  onChanged: (value) => onChanged('training_effort', value),
                ),
                const SizedBox(height: 20),
                RecapEmojiRatingField(
                  label: AppLocalizations.of(context)!.completedSessions,
                  helperText: AppLocalizations.of(context)!.howDoYouRateTheNumberOfSessions,
                  value: trainingSessions.round().clamp(0, 4),
                  onChanged: (value) => onChanged('training_sessions', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: AppLocalizations.of(context)!.perceivedProgress,
            subtitle: AppLocalizations.of(context)!.chooseTheProgressThatBestReflectsYourWeek,
            icon: Icons.trending_up,
            child: RecapChoiceChipsField(
              label: AppLocalizations.of(context)!.progressPerception,
              helperText: AppLocalizations.of(context)!.yourOverallFeelingAboutThePlanProgress,
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
            title: AppLocalizations.of(context)!.trainingNotes,
            subtitle: AppLocalizations.of(context)!.addContextSoYourCoachCanReviewYourWeekBetter,
            icon: Icons.notes,
            child: RecapTextAreaField(
              label: AppLocalizations.of(context)!.recapTrainingObservations,
              hintText: AppLocalizations.of(context)!.egItWasHardToKeepThePaceOnThursday,
              initialValue: formData['training_notes'] as String? ?? '',
              onChanged: (value) => onChanged('training_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
