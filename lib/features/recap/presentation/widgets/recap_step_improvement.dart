import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';

import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';

class RecapStepImprovement extends StatelessWidget {
  final Map<String, dynamic> formData;
  final void Function(String field, dynamic value) onChanged;

  const RecapStepImprovement({
    super.key,
    required this.formData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appRating =
        (formData['improvement_app_rating'] as num?)?.toInt() ?? 4;
    final serviceRating =
        (formData['improvement_service_rating'] as num?)?.toInt() ?? 4;
    final improvementAreas =
        (formData['improvement_areas'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: AppLocalizations.of(context)!.recapImprovementRatingsTitle,
            subtitle: AppLocalizations.of(context)!.recapImprovementRatingsSubtitle,
            icon: Icons.star_outline_rounded,
            child: Column(
              children: [
                RecapStarRatingField(
                  label: AppLocalizations.of(context)!.rateTheService,
                  helperText: AppLocalizations.of(context)!.howYouRateTheSupportReceivedThisWeek,
                  value: serviceRating.round().clamp(1, 5),
                  onChanged: (value) =>
                      onChanged('improvement_service_rating', value),
                ),
                const SizedBox(height: 20),
                RecapStarRatingField(
                  label: AppLocalizations.of(context)!.rateTheApp,
                  helperText: AppLocalizations.of(context)!.yourOverallExperienceWithTheApp,
                  value: appRating.round().clamp(1, 5),
                  onChanged: (value) =>
                      onChanged('improvement_app_rating', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: AppLocalizations.of(context)!.recapWhatCanWeImprove,
            subtitle: AppLocalizations.of(context)!.selectThePointsWhereYouWantMoreSupport,
            icon: Icons.tune_rounded,
            child: RecapMultiSelectField(
              label: AppLocalizations.of(context)!.selectThePointsWhereYouWantMoreSupport,
              helperText: AppLocalizations.of(context)!.selectThePointsWhereYouWantMoreSupport,
              values: improvementAreas,
              options: const [
                'ENTRENAMIENTO',
                'NUTRICION',
                'ADHERENCIA',
                'RECUPERACION',
                'MOTIVACION',
                'APP',
              ],
              onChanged: (value) => onChanged('improvement_areas', value),
            ),
          ),
          RecapSectionCard(
            title: AppLocalizations.of(context)!.recapTellUsMore,
            subtitle: AppLocalizations.of(context)!.closeTheWeekWithWhatMattersForYourCoach,
            icon: Icons.chat_bubble_outline_rounded,
            child: RecapTextAreaField(
              label: AppLocalizations.of(context)!.suggestionsOrImprovements,
              hintText: AppLocalizations.of(context)!.egIWouldLikeMoreContextInTheSessions,
              initialValue:
                  formData['improvement_feedback_text'] as String? ?? '',
              onChanged: (value) =>
                  onChanged('improvement_feedback_text', value),
            ),
          ),
        ],
      ),
    );
  }
}
