import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_step_header.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'onboarding_step_layout.dart';

/// Header of a data step of the onboarding (sketch `.x-step`): the step
/// numeral «01/04» at 120 in the data colour, then [ExomStepHeader] with the
/// kicker «Paso 1 de 4», the two-line title and the rule of [total]
/// segments. It replaces the former pill of 8 dp dots (L5-D2).
///
/// The numeral is decorative: the rule already announces «Paso X de N».
class OnboardingStepHeading extends StatelessWidget {
  const OnboardingStepHeading({
    super.key,
    required this.step,
    required this.total,
    required this.first,
    required this.second,
  });

  final int step;
  final int total;
  final String first;
  final String second;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kOnboardingSidePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExcludeSemantics(
              child: ExomNumeral(
                value: ExomIndexNumber.format(step),
                unit: '/${ExomIndexNumber.format(total)}',
                size: ExomNumeralSize.hero120,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ExomStepHeader(
            step: step,
            total: total,
            kicker: l10n.exomStepOf(step, total),
            first: first,
            second: second,
            segmentGrowth: OnboardingStepEntranceScope.maybeOf(context)?.rule,
          ),
        ],
      ),
    );
  }
}
