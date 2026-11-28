import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'onboarding_step_layout.dart';

/// Welcome of the onboarding (sketch `d-acceso.html` «Bienvenida»): the
/// logotype, «Tu cambio. / Con mi método.», the method in three numbered
/// steps and the four-step promise, with «Empezar» and «Hacerlo después».
class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({
    super.key,
    required this.onStart,
    required this.onSkip,
  });

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final method = [
      (l10n.onboardingMethodOneTitle, l10n.onboardingMethodOneBody),
      (l10n.onboardingMethodTwoTitle, l10n.onboardingMethodTwoBody),
      (l10n.onboardingMethodThreeTitle, l10n.onboardingMethodThreeBody),
    ];
    final rule = BorderSide(
      color: palette.borderSoft,
      width: ExomRule.hairline,
    );

    return OnboardingStepLayout(
      footer: OnboardingStepActions(
        primaryKey: const Key('onboarding-start'),
        primaryLabel: l10n.onboardingStartButton,
        onPrimary: onStart,
        quietLabel: l10n.onboardingDoItLaterButton,
        onQuiet: onSkip,
      ),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            kOnboardingSidePadding,
            ExomSpacing.lg,
            kOnboardingSidePadding,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExomBrandLogo(height: 40),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kOnboardingSidePadding,
            ExomSpacing.xxl,
            kOnboardingSidePadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExomKicker(l10n.onboardingWelcomeKicker),
              const SizedBox(height: ExomSpacing.sm),
              ExomTwoLineHeadline(
                first: l10n.onboardingWelcomeHeadlineFirst,
                second: l10n.onboardingWelcomeHeadlineSecond,
                size: ExomHeadlineSize.screen,
              ),
            ],
          ),
        ),
        const SizedBox(height: ExomSpacing.xxl),
        DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: rule)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < method.length; i++)
                DecoratedBox(
                  decoration: BoxDecoration(border: Border(top: rule)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kOnboardingSidePadding,
                      14,
                      kOnboardingSidePadding,
                      ExomSpacing.lg,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(child: ExomIndexNumber(i + 1)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method[i].$1,
                                style: onboardingStrongStyle(context),
                              ),
                              const SizedBox(height: ExomSpacing.xs),
                              Text(
                                method[i].$2,
                                style: onboardingSecondaryStyle(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kOnboardingSidePadding,
            ExomSpacing.lg,
            kOnboardingSidePadding,
            0,
          ),
          child: Text(
            l10n.onboardingWelcomeSteps,
            style: onboardingSecondaryStyle(context),
          ),
        ),
      ],
    );
  }
}
