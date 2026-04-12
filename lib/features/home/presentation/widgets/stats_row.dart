import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';

class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.summary});

  final HomeSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ExomSpacing.lg,
        vertical: ExomSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: summary.lastWeightKg != null
                  ? formatWeightValue(summary.lastWeightKg, unitSystem)
                  : '--',
              unit: weightUnitSymbol(unitSystem),
              label: l10n.weight,
              subtitle: summary.lastWeightDate != null
                  ? DateFormat('dd/MM/yyyy').format(summary.lastWeightDate!)
                  : null,
              color: AppColors.textSecondary,
              onTap: () => context.push('/profile/metrics'),
            ),
          ),
          const SizedBox(width: ExomSpacing.md),
          Expanded(
            child: _StatCard(
              value: '${summary.streakDays}',
              unit: l10n.days,
              label: l10n.streak,
              subtitle: summary.streakDays > 0 ? l10n.keepItUpSubtitle : null,
              color: palette.primary,
              highlighted: true,
              onTap: () => context.push('/challenges'),
            ),
          ),
          const SizedBox(width: ExomSpacing.md),
          Expanded(
            child: _StatCard(
              value: summary.lastSleepHours != null
                  ? summary.lastSleepHours!.toStringAsFixed(1)
                  : '--',
              unit: l10n.hours,
              label: l10n.sleep,
              subtitle: _sleepQuality(context, summary.lastSleepHours),
              color: semantic.sleep,
              onTap: () => context.push('/profile/metrics'),
            ),
          ),
        ],
      ),
    );
  }

  String? _sleepQuality(BuildContext context, double? hours) {
    final l10n = AppLocalizations.of(context)!;
    if (hours == null) return null;
    if (hours >= 8) return l10n.sleepQualityGood;
    if (hours >= 6) return l10n.sleepQualityFair;
    return l10n.sleepQualityLow;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.unit,
    required this.label,
    this.subtitle,
    required this.color,
    this.highlighted = false,
    this.onTap,
  });

  final String value;
  final String unit;
  final String label;
  final String? subtitle;
  final Color color;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Semantics(
      button: onTap != null,
      label: '$label: $value $unit',
      child: TappableScale(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ExomSpacing.md,
          vertical: ExomSpacing.md + 2,
        ),
        decoration: highlighted
            ? GlassDecoration.accentCard(color, borderRadius: 16)
            : GlassDecoration.card(borderRadius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: highlighted ? color : palette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.44,
              ),
            ),
            const SizedBox(height: ExomSpacing.xxs),
            Text(
              unit,
              style: theme.textTheme.bodySmall?.copyWith(
                color: highlighted ? color : palette.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: ExomSpacing.xs + 2),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: highlighted ? color : palette.textSecondary,
                fontSize: 13,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: ExomSpacing.xxs),
              Text(
                subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: highlighted
                      ? color.withValues(alpha: 0.7)
                      : palette.textDisabled,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
