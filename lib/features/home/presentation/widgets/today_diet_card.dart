import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';

class TodayDietCard extends StatelessWidget {
  const TodayDietCard({super.key, required this.summary});

  final HomeSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final hasNextMeal = summary.nextMealId != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: semantic.calorie.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: semantic.calorie,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dieta de hoy',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      summary.dietName ?? 'Plan nutricional',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.textPrimary,
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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: semantic.calorie,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  summary.totalMeals > 0
                      ? '${((summary.mealsCompleted / summary.totalMeals) * 100).toInt()}%'
                      : '0%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: semantic.calorie,
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
                    : 0,
                backgroundColor: palette.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(semantic.calorie),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 8),
          ],
          if (summary.nextMealName != null) ...[
            Text(
              'Siguiente: ${summary.nextMealName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                if (hasNextMeal) {
                  await context.push('/meals/${summary.nextMealId}');
                } else {
                  await context.push('/diets');
                }
                if (context.mounted) {
                  context.read<HomeBloc>().add(const HomeLoadRequested());
                }
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(
                hasNextMeal ? 'Siguiente comida' : 'Ver dieta completa',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: semantic.calorie,
                side: BorderSide(color: semantic.calorie),
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
