import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/utils/date_utils.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';

/// Diet summary of the selected day as one rich Inicio row (L5-E1, sketch
/// `.x-row`): plan name with its daily kcal, meals done and remaining kcal,
/// next meal, and one segment per meal with the done ones in data. Tapping it opens the next meal sheet
/// when there is one, or the full diet otherwise, and reloads Home after, as
/// the previous card did.
///
/// Renders nothing when the day has no diet.
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
    if (summary.dietId == null) {
      return const SizedBox.shrink();
    }

    final assignmentDate = AppDateUtils.toIso(selectedDate);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hasNextMeal = summary.nextMealId != null;

    final progress = <String>[
      if (summary.totalMeals > 0)
        l10n.homeMealsDone(summary.mealsCompleted, summary.totalMeals),
      if (summary.remainingCalories != null)
        l10n.homeRemainingKcal(
          NumberFormat.decimalPattern(locale).format(summary.remainingCalories),
        ),
    ];

    final name = summary.dietName ?? l10n.nutritionPlanDefault;
    final totalCalories = summary.totalCalories;
    final facts = [
      if (progress.isNotEmpty) progress.join(' · '),
      if (summary.nextMealName != null)
        '${l10n.nextMealLabel}: ${summary.nextMealName}',
    ];
    final totalMeals = summary.totalMeals;

    return ExomRichRow(
      leading: const ExomRowLeading.icon(ExomIcons.meal),
      title: totalCalories == null
          ? name
          : '$name · ${NumberFormat.decimalPattern(locale).format(totalCalories)} kcal',
      facts: facts.isEmpty ? null : facts.join('\n'),
      status: totalMeals > 0
          ? Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ExomProgressRule(
                    value: summary.mealsCompleted / totalMeals,
                    segments: totalMeals,
                  ),
                ),
              ),
            )
          : null,
      onTap: () async {
        HapticFeedback.selectionClick();
        if (hasNextMeal) {
          await showMealDetailSheet(
            context,
            mealId: summary.nextMealId!,
            selectedDate: assignmentDate,
            previewName: summary.nextMealName,
          );
        } else {
          await context.push('/diets?date=$assignmentDate');
        }
        if (context.mounted) {
          context.read<HomeBloc>().add(HomeLoadRequested(date: selectedDate));
        }
      },
    );
  }
}
