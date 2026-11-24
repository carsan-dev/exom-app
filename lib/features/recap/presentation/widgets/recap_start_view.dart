import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Step 0 of the form (sketch C4, «Paso 0, inicio»): the two-line headline, the
/// empty rule of five segments, what the form is for and the five steps as a
/// numbered index. The pinned action starts the form, or goes straight to the
/// last step to review and send when the blocks already have their answers.
class RecapStartView extends StatelessWidget {
  final Map<String, dynamic> formData;
  final String weekLabel;
  final VoidCallback onStart;
  final VoidCallback onReviewAndSend;
  final VoidCallback onCancel;

  const RecapStartView({
    super.key,
    required this.formData,
    required this.weekLabel,
    required this.onStart,
    required this.onReviewAndSend,
    required this.onCancel,
  });

  bool _isStepComplete(int step) {
    switch (step) {
      case 0:
        return formData['training_effort'] != null;
      case 1:
        return formData['nutrition_quality'] != null;
      case 2:
        return formData['sleep_hours_range'] != null;
      case 3:
        return formData['mood'] != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    final sections = [
      l10n.recapTraining,
      l10n.recapNutrition,
      l10n.recapRecovery,
      l10n.recapGeneral,
      l10n.recapImprovement,
    ];

    final allComplete = List.generate(
      4,
      (i) => _isStepComplete(i),
    ).every((c) => c);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ExomKicker(l10n.recapStartTitle),
                ),
                const SizedBox(height: ExomSpacing.sm),
                ExomTwoLineHeadline(
                  first: l10n.recapStartHeadlineFirst,
                  second: l10n.recapStartHeadlineSecond,
                  size: ExomHeadlineSize.screen,
                ),
                const SizedBox(height: ExomSpacing.sm),
                RecapWeekLabel(weekLabel),
                const SizedBox(height: ExomSpacing.lg),
                const ExcludeSemantics(
                  child: ExomProgressRule(
                    value: 0,
                    thickness: ExomRule.bar,
                    segments: kRecapSteps,
                  ),
                ),
                const SizedBox(height: ExomSpacing.lg),
                Text(
                  l10n.recapStartDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: ExomSpacing.xxl),
                ExomIndexList(
                  items: [
                    for (final title in sections) ExomIndexItem(title: title),
                  ],
                ),
              ],
            ),
          ),
        ),
        ExomPinnedFooter(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExomPrimaryButton(
                key: const ValueKey('recap-start'),
                label: allComplete
                    ? l10n.recapReviewAndSendButton
                    : l10n.recapStartButton,
                trailingIcon: allComplete ? ExomIcons.send : ExomIcons.forward,
                onPressed: allComplete ? onReviewAndSend : onStart,
              ),
              ExomQuietButton(label: l10n.cancel, onPressed: onCancel),
            ],
          ),
        ),
      ],
    );
  }
}
