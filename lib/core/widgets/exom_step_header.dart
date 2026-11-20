import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Header of a form step (ESPEC §3 «Cabecera de paso», `.stephead` /
/// `.x-step`): [kicker] ([ExomKicker]), the step title as an
/// [ExomTwoLineHeadline] of screen size ([first] in the text colour, [second]
/// in data) and a progress rule of [total] segments of 4 dp with the first
/// [step] filled ([ExomProgressRule]).
///
/// Semantics: the headline is a header node; the rule is one node labelled
/// «Paso X de N» (localised), so the position is read even when [kicker] says
/// something else. A [kicker] equal to that label (ignoring case) is excluded
/// from semantics, so the position is announced once.
class ExomStepHeader extends StatelessWidget {
  const ExomStepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.kicker,
    required this.first,
    required this.second,
  }) : assert(total > 0 && step >= 1 && step <= total, '1 <= step <= total');

  final int step;
  final int total;
  final String kicker;
  final String first;
  final String second;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stepLabel = l10n.exomStepOf(step, total);
    // A kicker that already says «Paso X de N» would be read twice: the rule
    // node carries the position, so the kicker is then painted only.
    final kickerRepeatsStep =
        kicker.trim().toLowerCase() == stepLabel.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExcludeSemantics(
            excluding: kickerRepeatsStep,
            child: ExomKicker(kicker),
          ),
        ),
        const SizedBox(height: ExomSpacing.sm),
        ExomTwoLineHeadline(
          first: first,
          second: second,
          size: ExomHeadlineSize.screen,
        ),
        const SizedBox(height: ExomSpacing.lg),
        Semantics(
          container: true,
          label: stepLabel,
          child: ExcludeSemantics(
            child: ExomProgressRule(
              value: step / total,
              thickness: ExomRule.bar,
              segments: total,
            ),
          ),
        ),
      ],
    );
  }
}
