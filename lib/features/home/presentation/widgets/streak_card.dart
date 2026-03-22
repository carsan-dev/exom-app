import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';

class StreakCard extends StatelessWidget {
  final HomeSummaryEntity summary;

  const StreakCard({super.key, required this.summary});

  String _motivationalMessage(int days) {
    if (days == 0) return '¡Empieza tu racha hoy!';
    if (days == 1) return '¡Primer día completado! Sigue así';
    if (days < 7) return '¡Vas muy bien! No lo detengas';
    if (days < 14) return '¡Una semana seguida! Increíble';
    if (days < 30) return '¡Eres una máquina! Más de ${days} días';
    return '¡Leyenda viva! $days días de racha';
  }

  @override
  Widget build(BuildContext context) {
    final days = summary.streakDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.calorieAccent.withValues(alpha: 0.15),
            AppColors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.calorieAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Flame icon with circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.calorieAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 28)),
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
                        'días de racha',
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
