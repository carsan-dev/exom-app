import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';

class StreakCard extends StatelessWidget {
  final HomeSummaryEntity summary;

  const StreakCard({super.key, required this.summary});

  String _motivationalMessage(int days) {
    if (days == 0) return 'Â¡Empieza tu racha hoy!';
    if (days == 1) return 'Â¡Primer dÃ­a completado! Sigue asÃ­';
    if (days < 7) return 'Â¡Vas muy bien! No lo detengas';
    if (days < 14) return 'Â¡Una semana seguida! IncreÃ­ble';
    if (days < 30) return 'Â¡Eres una mÃ¡quina! MÃ¡s de $days dÃ­as';
    return 'Â¡Leyenda viva! $days dÃ­as de racha';
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
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'dÃ­as de racha',
                        style: TextStyle(
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
                  _motivationalMessage(days),
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

