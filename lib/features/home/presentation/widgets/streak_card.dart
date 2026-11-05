import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';

class StreakCard extends StatelessWidget {
  final HomeSummaryEntity summary;

  const StreakCard({super.key, required this.summary});

  String _motivationalMessage(AppLocalizations l10n, int days) {
    if (days == 0) return l10n.streakMsgStart;
    if (days == 1) return l10n.streakMsgFirstDay;
    if (days < 7) return l10n.streakMsgGoingWell;
    if (days < 14) return l10n.streakMsgWeek;
    if (days < 30) return l10n.streakMsgMachine(days);
    return l10n.streakMsgLegend(days);
  }

  @override
  Widget build(BuildContext context) {
    final days = summary.streakDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: GlassDecoration.accentCard(AppColors.calorieAccent),
      child: Row(
        children: [
          // Flame icon with circle and glow
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.calorieAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.calorieAccent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Center(
              child: Text('ðŸ”¥', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$days',
                      style: const TextStyle(
                        color: AppColors.calorieAccent,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        AppLocalizations.of(context).streakDaysLabel(days),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _motivationalMessage(AppLocalizations.of(context), days),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

