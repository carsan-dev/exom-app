import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';

class TodayDietCard extends StatelessWidget {
  final HomeSummaryEntity summary;

  const TodayDietCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant_menu, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dieta de hoy',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    Text(
                      summary.dietName ?? 'Plan nutricional',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.totalCalories != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${summary.totalCalories}',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'kcal',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (summary.totalMeals > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${summary.mealsCompleted}/${summary.totalMeals} comidas',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                Text(
                  summary.totalMeals > 0
                      ? '${((summary.mealsCompleted / summary.totalMeals) * 100).toInt()}%'
                      : '0%',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.totalMeals > 0
                    ? summary.mealsCompleted / summary.totalMeals
                    : 0.0,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/diets'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver dieta completa'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealTypeIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MealTypeIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}
