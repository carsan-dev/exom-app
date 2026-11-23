import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'onboarding_progress_indicator.dart';
import 'onboarding_step_layout.dart';

/// Summary of the onboarding (sketch «Paso 4 · Resumen»): the profile
/// completion, then the three groups numbered 01-03 with «Editar», keeping
/// every field of before (R20: also the muscle mass goal and the calories).
/// Numbers use the separator of the language with the rules of the steppers
/// (at most 2 decimals, trailing zeros trimmed, no grouping), so the summary
/// shows what the steps showed.
///
/// While [busy] the content is dimmed, «Editar» does not respond and the
/// lime button says «Guardando tu perfil...». [errorTitle] and [errorBody]
/// are the save error, kept above «Confirmar» until the next attempt.
class OnboardingSummaryStep extends StatelessWidget {
  const OnboardingSummaryStep({
    super.key,
    required this.accumulatedData,
    required this.avatarUrl,
    required this.onConfirm,
    required this.onEditBasics,
    required this.onEditBody,
    required this.onEditGoals,
    this.busy = false,
    this.errorTitle,
    this.errorBody,
  });

  final Map<String, dynamic> accumulatedData;
  final String? avatarUrl;
  final VoidCallback onConfirm;
  final VoidCallback onEditBasics;
  final VoidCallback onEditBody;
  final VoidCallback onEditGoals;
  final bool busy;
  final String? errorTitle;
  final String? errorBody;

  int _completionPercent() {
    const fields = [
      'first_name',
      'last_name',
      'birth_date',
      'height',
      'current_weight',
      'level',
      'main_goal',
      'target_calories',
    ];
    final filled = fields.where((field) {
      final value = accumulatedData[field];
      if (value is String) {
        return value.trim().isNotEmpty;
      }
      return value != null;
    }).length;
    final total = fields.length + 1;
    final withAvatar = avatarUrl != null ? filled + 1 : filled;
    return (withAvatar / total * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = _completionPercent();
    final cm = lengthUnitSymbol(UnitSystem.metric);
    final kg = weightUnitSymbol(UnitSystem.metric);

    ExomFigure figure(String key, String label, String unit) {
      final value = accumulatedData[key];
      return value is num
          ? ExomFigure(
              value: _decimal(context, value),
              unit: unit,
              label: label,
            )
          : ExomFigure(value: '-', label: label);
    }

    final calories = accumulatedData['target_calories'];
    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExomNumberedSectionHeader(
          n: 1,
          title: l10n.onboardingBasicsTitle,
          trailing: ExomTextLink(
            label: l10n.onboardingEditButton,
            onTap: busy ? null : onEditBasics,
          ),
        ),
        _TextColumns(
          items: [
            (
              l10n.onboardingFirstNameLabel,
              _stringValue(accumulatedData['first_name']),
            ),
            (
              l10n.onboardingLastNameLabel,
              _stringValue(accumulatedData['last_name']),
            ),
            (l10n.onboardingBirthDateLabel, _birthDateLabel(context)),
          ],
        ),
        ExomNumberedSectionHeader(
          n: 2,
          title: l10n.onboardingBodyTitle,
          trailing: ExomTextLink(
            label: l10n.onboardingEditButton,
            onTap: busy ? null : onEditBody,
          ),
        ),
        ExomFigureColumns(
          numbered: false,
          alignLabels: true,
          items: [
            figure('height', l10n.height, cm),
            figure('current_weight', l10n.weight, kg),
          ],
        ),
        ExomNumberedSectionHeader(
          n: 3,
          title: l10n.onboardingGoalsTitle,
          trailing: ExomTextLink(
            label: l10n.onboardingEditButton,
            onTap: busy ? null : onEditGoals,
          ),
        ),
        _TextColumns(
          items: [
            (
              l10n.onboardingLevelLabel,
              _localizedLevel(context, accumulatedData['level'] as String?),
            ),
            (
              l10n.onboardingMainGoalLabel,
              _stringValue(accumulatedData['main_goal']),
            ),
          ],
        ),
        ExomFigureColumns(
          numbered: false,
          alignLabels: true,
          items: [
            figure('muscle_mass_goal', l10n.onboardingMuscleMassGoalLabel, kg),
            calories is num
                ? ExomFigure(
                    value: formatFigure(context, calories),
                    unit: 'kcal',
                    label: l10n.onboardingTargetCaloriesLabel,
                  )
                : ExomFigure(
                    value: '-',
                    label: l10n.onboardingTargetCaloriesLabel,
                  ),
          ],
        ),
      ],
    );

    return OnboardingStepLayout(
      footer: OnboardingStepActions(
        primaryKey: const Key('onboarding-summary-confirm'),
        primaryLabel: busy
            ? l10n.onboardingSubmittingMessage
            : l10n.onboardingConfirmButton,
        onPrimary: onConfirm,
        busy: busy,
        errorKey: const Key('onboarding-save-error'),
        errorTitle: busy ? null : errorTitle,
        errorBody: errorBody,
      ),
      children: [
        OnboardingStepHeading(
          step: 4,
          total: 4,
          first: l10n.onboardingSummaryHeadlineFirst,
          second: l10n.onboardingSummaryHeadlineSecond,
        ),
        const SizedBox(height: ExomSpacing.xxl),
        Opacity(
          opacity: busy ? 0.6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Completion(percent: percent),
              const SizedBox(height: ExomSpacing.xxl),
              sections,
            ],
          ),
        ),
      ],
    );
  }

  /// [value] with the separator of the language: at most 2 decimals, trailing
  /// zeros trimmed, no grouping (the stepper's own format).
  static String _decimal(BuildContext context, num value) =>
      formatDisplayDecimal(
        value.toDouble(),
        decimalSeparator: decimalSeparatorFor(
          Localizations.localeOf(context).languageCode,
        ),
      );

  String _birthDateLabel(BuildContext context) {
    final rawValue = accumulatedData['birth_date'] as String?;
    if (rawValue == null || rawValue.trim().isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(rawValue);
    if (date == null) {
      return rawValue;
    }

    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(date);
  }

  String _localizedLevel(BuildContext context, String? level) {
    if (level == null || level.trim().isEmpty) {
      return '-';
    }

    final l10n = AppLocalizations.of(context);
    switch (level.toUpperCase()) {
      case 'BEGINNER':
      case 'PRINCIPIANTE':
        return l10n.beginnerLevel;
      case 'INTERMEDIATE':
      case 'INTERMEDIO':
        return l10n.intermediateLevel;
      case 'ADVANCED':
      case 'AVANZADO':
        return l10n.advancedLevel;
      default:
        return level;
    }
  }

  String _stringValue(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }
}

/// Label of the profile completion for [percent], by tiers: 0-39 incomplete,
/// 40-69 half done, 70-99 almost complete, 100 complete.
/// `onboardingProgressComplete` («Perfil N% completo») is no longer used here;
/// it stays in the ARB files.
String onboardingCompletionLabel(AppLocalizations l10n, int percent) {
  if (percent >= 100) return l10n.onboardingProfileComplete;
  if (percent >= 70) return l10n.onboardingProfileAlmostComplete;
  if (percent >= 40) return l10n.onboardingProfileHalfDone;
  return l10n.onboardingProfileIncomplete;
}

/// Profile completion (sketch `.x-feat` + `.x-meter`): the tier label
/// («Perfil casi completo»), the percentage in the data colour and a 4 dp
/// rule. The block is a `panel` fill with the thin neutral line that separates
/// the sections of the summary on top (not the thick data bar of
/// `ExomFeatureBlock`, round 4).
class _Completion extends StatelessWidget {
  const _Completion({required this.percent});

  final int percent;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final label = onboardingCompletionLabel(l10n, percent);
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.borderSoft, width: ExomRule.hairline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kOnboardingSidePadding),
        child: Semantics(
          container: true,
          label: l10n.onboardingProfileCompletionA11y(label, percent),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(label, style: onboardingStrongStyle(context)),
                  ),
                  const SizedBox(width: ExomSpacing.md),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: formatFigure(context, percent)),
                        const TextSpan(
                          text: '%',
                          style: TextStyle(fontSize: _size / 2),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: AppTheme.displayFontFamily,
                      fontSize: _size,
                      fontWeight: FontWeight.w800,
                      height: 0.85,
                      color: context.exomPalette.data,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ExomProgressRule(value: percent / 100, thickness: ExomRule.bar),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text values in columns separated by hairlines (sketch `.x-cols` with
/// `.sec` labels and `.strong` values), two per row; the last one alone when
/// the count is odd. Each value wraps, never clips.
class _TextColumns extends StatelessWidget {
  const _TextColumns({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final rule = BorderSide(
      color: palette.borderSoft,
      width: ExomRule.hairline,
    );
    Widget cell((String, String) item, {required bool first}) => Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        first ? kOnboardingSidePadding : 14,
        14,
        ExomSpacing.md,
        ExomSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.$1, style: onboardingSecondaryStyle(context)),
          const SizedBox(height: 6),
          Text(item.$2, style: onboardingStrongStyle(context)),
        ],
      ),
    );

    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final second = i + 1 < items.length ? items[i + 1] : null;
      rows.add(
        DecoratedBox(
          decoration: BoxDecoration(border: Border(top: rule)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cell(items[i], first: true)),
                Expanded(
                  child: second == null
                      ? const SizedBox.shrink()
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            border: BorderDirectional(start: rule),
                          ),
                          child: cell(second, first: false),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: rule)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}
