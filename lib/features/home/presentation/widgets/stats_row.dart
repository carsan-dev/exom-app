import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';

class StatsRow extends StatelessWidget {
  final HomeSummaryEntity summary;

  const StatsRow({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: summary.lastWeightKg != null
                  ? summary.lastWeightKg!.toStringAsFixed(1)
                  : '--',
              unit: 'kilos',
              label: 'Peso',
              subtitle: summary.lastWeightDate != null
                  ? DateFormat('dd/MM/yyyy').format(summary.lastWeightDate!)
                  : null,
              color: AppColors.textSecondary,
              onTap: () => context.push('/profile/metrics'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '${summary.streakDays}',
              unit: 'días',
              label: 'Racha',
              subtitle: summary.streakDays > 0 ? '¡Sigue así!' : null,
              color: AppColors.primary,
              highlighted: true,
              onTap: () => context.push('/challenges'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: summary.lastSleepHours != null
                  ? summary.lastSleepHours!.toStringAsFixed(1)
                  : '--',
              unit: 'horas',
              label: 'Sueño',
              subtitle: _sleepQuality(summary.lastSleepHours),
              color: AppColors.sleepAccent,
              onTap: () => context.push('/profile/metrics'),
            ),
          ),
        ],
      ),
    );
  }

  String? _sleepQuality(double? hours) {
    if (hours == null) return null;
    if (hours >= 8) return 'Calidad Buena';
    if (hours >= 6) return 'Calidad Media';
    return 'Poco sueño';
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final String? subtitle;
  final Color color;
  final bool highlighted;
  final VoidCallback? onTap;

  const _StatCard({
    required this.value,
    required this.unit,
    required this.label,
    this.subtitle,
    required this.color,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: highlighted ? color.withValues(alpha: 0.12) : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted
                  ? color.withValues(alpha: 0.3)
                  : AppColors.borderSoft,
            ),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: highlighted ? color : AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                unit,
                style: TextStyle(
                  color: highlighted ? color : AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: highlighted ? color : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: highlighted
                        ? color.withValues(alpha: 0.7)
                        : AppColors.textDisabled,
                    fontSize: 10,
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
