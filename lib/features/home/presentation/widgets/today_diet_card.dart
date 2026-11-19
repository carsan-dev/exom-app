import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/utils/date_utils.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/home_row.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';

/// Diet summary of the selected day as one quiet Inicio row: plan name, meals
/// done and remaining kcal, next meal. Tapping it opens the next meal sheet
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

    return HomeRow(
      icon: Icons.restaurant_menu,
      title: summary.dietName ?? l10n.nutritionPlanDefault,
      subtitles: [
        if (progress.isNotEmpty) progress.join(' · '),
        if (summary.nextMealName != null)
          '${l10n.nextMealLabel}: ${summary.nextMealName}',
      ],
      onTap: () async {
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
          context.read<HomeBloc>().add(HomeLoadRequested(date: selectedDate));
        }
      },
    );
  }
}
