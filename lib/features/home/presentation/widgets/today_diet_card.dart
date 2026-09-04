import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/utils/date_utils.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';

class TodayDietCard extends StatelessWidget {
  const TodayDietCard({
    super.key,
    required this.summary,
    required this.selectedDate,
  });

  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final assignmentDate = AppDateUtils.toIso(selectedDate);
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final dietAccent = context.dietAccent;
    final l10n = AppLocalizations.of(context);
    final hasNextMeal = summary.nextMealId != null;

    return Semantics(
      label:
          '${l10n.todaysDietTitle}: ${summary.dietName ?? l10n.nutritionPlanDefault}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: GlassDecoration.accentCard(dietAccent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: dietAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: dietAccent.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: dietAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.todaysDietTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        summary.dietName ?? l10n.nutritionPlanDefault,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: palette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (summary.remainingCalories != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${summary.remainingCalories}',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: dietAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.remainingKcalLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (summary.totalMeals > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${summary.mealsCompleted}/${summary.totalMeals} ${l10n.meals}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      summary.totalMeals > 0
                          ? '${((summary.mealsCompleted / summary.totalMeals) * 100).toInt()}%'
                          : '0%',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: dietAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: dietAccent.withValues(alpha: 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.totalMeals > 0
                        ? summary.mealsCompleted / summary.totalMeals
                        : 0,
                    backgroundColor: palette.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(dietAccent),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 8),
            ],
            if (summary.nextMealName != null) ...[
              Text(
                '${l10n.nextMealLabel}: ${summary.nextMealName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  if (hasNextMeal) {
                    await showMealDetailSheet(
                      context,
                      mealId: summary.nextMealId!,
                      selectedDate: assignmentDate,
                    );
                  } else {
                    await context.push('/diets?date=$assignmentDate');
                  }
                  if (context.mounted) {
                    context.read<HomeBloc>().add(
                      HomeLoadRequested(date: selectedDate),
                    );
                  }
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(
                  hasNextMeal ? l10n.nextMealButton : l10n.viewFullDietButton,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: dietAccent,
                  side: BorderSide(color: dietAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
