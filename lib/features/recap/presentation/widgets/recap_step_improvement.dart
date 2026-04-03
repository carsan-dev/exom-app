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
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: l10n.recapImprovementRatingsTitle,
            subtitle: l10n.recapImprovementRatingsSubtitle,
            icon: Icons.star_outline_rounded,
            child: Column(
              children: [
                RecapStarRatingField(
                  label: l10n.rateTheService,
                  helperText: l10n.howYouRateTheSupportReceivedThisWeek,
                  value: serviceRating.round().clamp(1, 5),
                  onChanged: (value) =>
                      onChanged('improvement_service_rating', value),
                ),
                const SizedBox(height: 20),
                RecapStarRatingField(
                  label: l10n.rateTheApp,
                  helperText: l10n.yourOverallExperienceWithTheApp,
                  value: appRating.round().clamp(1, 5),
                  onChanged: (value) =>
                      onChanged('improvement_app_rating', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: l10n.recapWhatCanWeImprove,
            subtitle: l10n.selectThePointsWhereYouWantMoreSupport,
            icon: Icons.tune_rounded,
            child: RecapMultiSelectField(
              label: l10n.selectThePointsWhereYouWantMoreSupport,
              helperText: l10n.selectThePointsWhereYouWantMoreSupport,
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
            title: l10n.recapTellUsMore,
            subtitle: l10n.closeTheWeekWithWhatMattersForYourCoach,
            icon: Icons.chat_bubble_outline_rounded,
            child: RecapTextAreaField(
              label: l10n.suggestionsOrImprovements,
              hintText: l10n.egIWouldLikeMoreContextInTheSessions,
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
