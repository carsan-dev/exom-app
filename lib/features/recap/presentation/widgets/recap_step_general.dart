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
    final appRating =
        (formData['improvement_app_rating'] as num?)?.toInt() ?? 4;
    final serviceRating =
        (formData['improvement_service_rating'] as num?)?.toInt() ?? 4;
    final improvementAreas =
        (formData['improvement_areas'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
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
              ],
            ),
          ),
          RecapSectionCard(
            title: AppLocalizations.of(context)!.serviceFeedback,
            subtitle: AppLocalizations.of(context)!.helpImproveTheExperienceAndSupport,
            icon: Icons.rate_review_outlined,
            child: Column(
              children: [
                RecapStarRatingField(
                  label: AppLocalizations.of(context)!.rateTheApp,
                  helperText: AppLocalizations.of(context)!.yourOverallExperienceWithTheApp,
                  value: appRating.round().clamp(1, 5),
                  onChanged: (value) =>
                      onChanged('improvement_app_rating', value),
                ),
                const SizedBox(height: 20),
                RecapStarRatingField(
                  label: AppLocalizations.of(context)!.rateTheService,
                  helperText: AppLocalizations.of(context)!.howYouRateTheSupportReceivedThisWeek,
                  value: serviceRating.round().clamp(1, 5),
                  onChanged: (value) =>
                      onChanged('improvement_service_rating', value),
                ),
                const SizedBox(height: 20),
                RecapMultiSelectField(
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
              ],
            ),
          ),
          RecapSectionCard(
            title: AppLocalizations.of(context)!.finalComments,
            subtitle: AppLocalizations.of(context)!.closeTheWeekWithWhatMattersForYourCoach,
            icon: Icons.chat_bubble_outline,
            child: Column(
              children: [
                RecapTextAreaField(
                  label: AppLocalizations.of(context)!.notes,
                  hintText: AppLocalizations.of(context)!.shareAnyRelevantDetailFromYourWeek,
                  initialValue: formData['general_notes'] as String? ?? '',
                  onChanged: (value) => onChanged('general_notes', value),
                ),
                const SizedBox(height: 18),
                RecapTextAreaField(
                  label: AppLocalizations.of(context)!.suggestionsOrImprovements,
                  hintText: AppLocalizations.of(context)!.egIWouldLikeMoreContextInTheSessions,
                  initialValue:
                      formData['improvement_feedback_text'] as String? ?? '',
                  onChanged: (value) =>
                      onChanged('improvement_feedback_text', value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
