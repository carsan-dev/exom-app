import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class OnboardingSummaryStep extends StatelessWidget {
  const OnboardingSummaryStep({
    super.key,
    required this.accumulatedData,
    required this.avatarUrl,
    required this.onConfirm,
    required this.onEditBasics,
    required this.onEditBody,
    required this.onEditGoals,
  });

  final Map<String, dynamic> accumulatedData;
  final String? avatarUrl;
  final VoidCallback onConfirm;
  final VoidCallback onEditBasics;
  final VoidCallback onEditBody;
  final VoidCallback onEditGoals;

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
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final percent = _completionPercent();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            l10n.onboardingSummaryTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _CompletionCard(
                  accumulatedData: accumulatedData,
                  avatarUrl: avatarUrl,
                  percent: percent,
                ),
                const SizedBox(height: 16),
                _SummarySection(
                  title: l10n.onboardingBasicsTitle,
                  onEdit: onEditBasics,
                  rows: [
                    _SummaryRow(
                      label: l10n.onboardingFirstNameLabel,
                      value: _stringValue(accumulatedData['first_name']),
                    ),
                    _SummaryRow(
                      label: l10n.onboardingLastNameLabel,
                      value: _stringValue(accumulatedData['last_name']),
                    ),
                    _SummaryRow(
                      label: l10n.onboardingBirthDateLabel,
                      value: _birthDateLabel(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummarySection(
                  title: l10n.onboardingBodyTitle,
                  onEdit: onEditBody,
                  rows: [
                    _SummaryRow(
                      label: l10n.onboardingHeightLabel,
                      value: _formattedNumber(accumulatedData['height'], 'cm'),
                    ),
                    _SummaryRow(
                      label: l10n.onboardingWeightLabel,
                      value: _formattedNumber(
                        accumulatedData['current_weight'],
                        'kg',
                        decimals: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummarySection(
                  title: l10n.onboardingGoalsTitle,
                  onEdit: onEditGoals,
                  rows: [
                    _SummaryRow(
                      label: l10n.onboardingLevelLabel,
                      value: _localizedLevel(
                        context,
                        accumulatedData['level'] as String?,
                      ),
                    ),
                    _SummaryRow(
                      label: l10n.onboardingMainGoalLabel,
                      value: _stringValue(accumulatedData['main_goal']),
                    ),
                    _SummaryRow(
                      label: l10n.onboardingMuscleMassGoalLabel,
                      value: _formattedNumber(
                        accumulatedData['muscle_mass_goal'],
                        'kg',
                        decimals: 1,
                      ),
                    ),
                    _SummaryRow(
                      label: l10n.onboardingTargetCaloriesLabel,
                      value: _formattedNumber(
                        accumulatedData['target_calories'],
                        'kcal',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              child: Text(l10n.onboardingConfirmButton),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

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
        return l10n.beginnerLevel;
      case 'INTERMEDIATE':
        return l10n.intermediateLevel;
      case 'ADVANCED':
        return l10n.advancedLevel;
      default:
        return level;
    }
  }

  String _stringValue(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String _formattedNumber(Object? value, String suffix, {int decimals = 0}) {
    if (value is! num) {
      return '-';
    }

    final number = decimals == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(decimals);
    return '$number $suffix';
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.accumulatedData,
    required this.avatarUrl,
    required this.percent,
  });

  final Map<String, dynamic> accumulatedData;
  final String? avatarUrl;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final fullName =
        [accumulatedData['first_name'], accumulatedData['last_name']]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .join(' ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: palette.surfaceVariant,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Icon(Icons.person, color: palette.textDisabled, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? l10n.userDefaultName : fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.onboardingProgressComplete(percent),
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: palette.surfaceVariant,
              color: palette.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.onEdit,
    required this.rows,
  });

  final String title;
  final VoidCallback onEdit;
  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: Text(l10n.onboardingEditButton),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;
}
