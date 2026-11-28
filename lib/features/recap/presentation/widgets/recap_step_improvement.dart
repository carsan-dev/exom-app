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

    return RecapStepFrame(
      step: 5,
      first: l10n.recapStepImprovementFirst,
      second: l10n.recapStepImprovementSecond,
      coach: l10n.recapStepImprovementCoach,
      questions: [
        RecapStarRatingField(
          number: 1,
          label: l10n.rateTheService,
          helperText: l10n.howYouRateTheSupportReceivedThisWeek,
          value: serviceRating.round().clamp(1, 5),
          onChanged: (value) => onChanged('improvement_service_rating', value),
        ),
        RecapStarRatingField(
          number: 2,
          label: l10n.rateTheApp,
          helperText: l10n.yourOverallExperienceWithTheApp,
          value: appRating.round().clamp(1, 5),
          onChanged: (value) => onChanged('improvement_app_rating', value),
        ),
        RecapMultiSelectField(
          number: 3,
          label: l10n.recapWhatCanWeImprove,
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
        RecapTextAreaField(
          number: 4,
          label: l10n.suggestionsOrImprovements,
          hintText: l10n.egIWouldLikeMoreContextInTheSessions,
          initialValue: formData['improvement_feedback_text'] as String? ?? '',
          onChanged: (value) => onChanged('improvement_feedback_text', value),
        ),
      ],
    );
  }
}
