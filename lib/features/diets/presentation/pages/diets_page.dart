import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';
import 'package:exom_app/injection_container.dart';

class DietsPage extends StatelessWidget {
  const DietsPage({super.key, this.selectedDate});

  final String? selectedDate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DietBloc>()..add(DietLoadRequested(date: selectedDate)),
      child: _DietsView(selectedDate: selectedDate),
    );
  }
}

class _DietsView extends StatelessWidget {
  const _DietsView({this.selectedDate});

  final String? selectedDate;

  String _dateLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (selectedDate == null) return l10n.todayLabel.toLowerCase();
    final parsed = DateTime.tryParse(selectedDate!);
    if (parsed == null) return l10n.selectedDateLabel;
    final now = DateTime.now();
    final isToday =
        parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
    if (isToday) return l10n.todayLabel.toLowerCase();
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DietBloc, DietState>(
      builder: (context, state) {
        if (state is DietLoading || state is DietInitial) {
          return const _DietsLoadingView();
        }
        if (state is DietError) {
          return ErrorWidget2(
            message: state.message,
            onRetry: () => context.read<DietBloc>().add(
              DietLoadRequested(date: selectedDate),
            ),
          );
        }
        if (state is DietNoContent) {
          return EmptyWidget(
            message: selectedDate == null
                ? l10n.noDietTodayMessage
                : l10n.noDietForDateMessage,
            subtitle: l10n.contactCoachForPlanMessage,
            icon: Icons.restaurant_menu_outlined,
            action: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.message_outlined, size: 16),
              label: Text(l10n.contactCoachButton),
            ),
          );
        }
        if (state is DietLoaded) {
          return _DietContent(
            state: state,
            selectedDate: selectedDate,
            dateLabel: _dateLabel(context),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _DietsLoadingView extends StatelessWidget {
  const _DietsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 32),
      children: const [
        _DietHeaderSkeleton(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: ShimmerCard(
            height: 16,
            width: 124,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
        _MealCardSkeleton(),
        _MealCardSkeleton(),
        _MealCardSkeleton(),
        _MealCardSkeleton(),
      ],
    );
  }
}

class _DietHeaderSkeleton extends StatelessWidget {
  const _DietHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ShimmerCard(
                  height: 22,
                  width: 176,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              SizedBox(width: 12),
              ShimmerCard(
                height: 28,
                width: 92,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ],
          ),
          SizedBox(height: 10),
          ShimmerCard(
            height: 14,
            width: 132,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DietMacroSkeleton(),
              _DietMacroSkeleton(),
              _DietMacroSkeleton(),
              _DietMacroSkeleton(),
            ],
          ),
        ],
      ),
    );
  }
}

class _DietMacroSkeleton extends StatelessWidget {
  const _DietMacroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        ShimmerCard(
          height: 22,
          width: 34,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        SizedBox(height: 6),
        ShimmerCard(
          height: 12,
          width: 18,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        SizedBox(height: 6),
        ShimmerCard(
          height: 12,
          width: 42,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ],
    );
  }
}

class _MealCardSkeleton extends StatelessWidget {
  const _MealCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              ShimmerCard(
                height: 40,
                width: 40,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCard(
                      height: 18,
                      width: 140,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    SizedBox(height: 8),
                    ShimmerCard(
                      height: 14,
                      width: 92,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              ShimmerCard(
                height: 22,
                width: 22,
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              ShimmerCard(
                height: 14,
                width: 64,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              SizedBox(width: 10),
              ShimmerCard(
                height: 14,
                width: 74,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DietContent extends StatelessWidget {
  const _DietContent({
    required this.state,
    required this.selectedDate,
    required this.dateLabel,
  });

  final DietLoaded state;
  final String? selectedDate;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final diet = state.diet;
    final meals = diet.meals;
    final completedCount = state.completedMealIds.length;

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: () async {
        context.read<DietBloc>().add(DietLoadRequested(date: selectedDate));
      },
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _DietHeader(
            diet: diet,
            completedCount: completedCount,
            dateLabel: dateLabel,
          ),
          const _MealsSectionTitle(),
          ..._sortedMeals(meals).map(
            (meal) => _MealCard(
              meal: meal,
              isCompleted: state.completedMealIds.contains(meal.id),
              selectedDate: selectedDate,
              onToggle: (val) {
                context.read<DietBloc>().add(
                  MarkMealCompleted(mealId: meal.id, completed: val),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<MealEntity> _sortedMeals(List<MealEntity> meals) {
    const order = ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER'];
    final sorted = List<MealEntity>.from(meals);
    sorted.sort((a, b) {
      final ai = order.indexOf(a.type.toUpperCase());
      final bi = order.indexOf(b.type.toUpperCase());
      return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
    });
    return sorted;
  }
}

class _MealsSectionTitle extends StatelessWidget {
  const _MealsSectionTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        l10n.mealsOfTheDayLabel,
        style: theme.textTheme.labelLarge?.copyWith(
          color: palette.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DietHeader extends StatelessWidget {
  const _DietHeader({
    required this.diet,
    required this.completedCount,
    required this.dateLabel,
  });

  final DietEntity diet;
  final int completedCount;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: GlassDecoration.accentCard(semantic.calorie),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  diet.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: semantic.calorie.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completedCount/${diet.meals.length} ${l10n.completedFeminine.toLowerCase()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: semantic.calorie,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel == l10n.todayLabel.toLowerCase()
                ? l10n.todaysPlanLabel
                : '${l10n.planForLabel} $dateLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (diet.totalCalories != null)
                _MacroStat(
                  label: l10n.caloriesLabel,
                  value: '${diet.totalCalories}',
                  unit: 'kcal',
                  color: semantic.calorie,
                ),
              if (diet.totalProteinG != null)
                _MacroStat(
                  label: l10n.proteinLabel,
                  value: diet.totalProteinG!.toStringAsFixed(0),
                  unit: 'g',
                  color: palette.primary,
                ),
              if (diet.totalCarbsG != null)
                _MacroStat(
                  label: l10n.carbsLabel,
                  value: diet.totalCarbsG!.toStringAsFixed(0),
                  unit: 'g',
                  color: semantic.info,
                ),
              if (diet.totalFatG != null)
                _MacroStat(
                  label: l10n.fatsLabel,
                  value: diet.totalFatG!.toStringAsFixed(0),
                  unit: 'g',
                  color: semantic.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          unit,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textDisabled,
            fontSize: 11,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.isCompleted,
    required this.selectedDate,
    required this.onToggle,
  });

  final MealEntity meal;
  final bool isCompleted;
  final String? selectedDate;
  final ValueChanged<bool> onToggle;

  IconData _mealIcon(String type) {
    switch (type.toUpperCase()) {
      case 'BREAKFAST':
        return Icons.wb_sunny_outlined;
      case 'LUNCH':
        return Icons.restaurant_outlined;
      case 'SNACK':
        return Icons.local_cafe_outlined;
      case 'DINNER':
        return Icons.nights_stay_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  String _mealLabel(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context);
    switch (type.toUpperCase()) {
      case 'BREAKFAST':
        return l10n.mealTypeBreakfast;
      case 'LUNCH':
        return l10n.mealTypeLunch;
      case 'SNACK':
        return l10n.mealTypeSnack;
      case 'DINNER':
        return l10n.mealTypeDinner;
      default:
        return type;
    }
  }

  Color _mealColor(BuildContext context, String type) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;

    switch (type.toUpperCase()) {
      case 'BREAKFAST':
        return semantic.warning;
      case 'LUNCH':
        return semantic.info;
      case 'SNACK':
        return palette.primary;
      case 'DINNER':
        return semantic.sleep;
      default:
        return palette.textDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final color = _mealColor(context, meal.type);

    return TappableScale(
      onTap: () async {
        await showMealDetailSheet(
          context,
          mealId: meal.id,
          selectedDate: selectedDate,
        );
        if (context.mounted) {
          context.read<DietBloc>().add(DietLoadRequested(date: selectedDate));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: isCompleted
            ? BoxDecoration(
                color: semantic.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: semantic.success.withValues(alpha: 0.32),
                ),
              )
            : GlassDecoration.card(borderRadius: 18),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: meal.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: meal.imageUrl!,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _MealIconFallback(
                        icon: _mealIcon(meal.type),
                        color: color,
                      ),
                      errorWidget: (context, url, error) => _MealIconFallback(
                        icon: _mealIcon(meal.type),
                        color: color,
                      ),
                    )
                  : _MealIconFallback(icon: _mealIcon(meal.type), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _mealLabel(context, meal.type),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isCompleted
                                ? palette.textSecondary
                                : palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: palette.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right,
                        color: palette.textDisabled,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (meal.calories != null ||
                      meal.proteinG != null ||
                      meal.carbsG != null)
                    Row(
                      children: [
                        if (meal.calories != null) ...[
                          Icon(
                            Icons.local_fire_department_outlined,
                            color: palette.textDisabled,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${meal.calories} kcal',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textDisabled,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (meal.proteinG != null)
                          Text(
                            'P: ${meal.proteinG!.toStringAsFixed(0)}g',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textDisabled,
                              fontSize: 11,
                            ),
                          ),
                        if (meal.carbsG != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            'C: ${meal.carbsG!.toStringAsFixed(0)}g',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textDisabled,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (meal.nutritionalBadges.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      children: meal.nutritionalBadges.take(3).map((b) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.glassBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: palette.glassBorder.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                          child: Text(
                            b,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textDisabled,
                              fontSize: 9,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onToggle(!isCompleted),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? semantic.success
                                  : palette.surfaceVariant,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCompleted
                                    ? semantic.success
                                    : palette.textDisabled,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: isCompleted
                                  ? Colors.white
                                  : palette.textDisabled,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 52,
                            child: Text(
                              isCompleted ? 'Hecha' : 'Marcar',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isCompleted
                                    ? semantic.success
                                    : palette.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MealIconFallback extends StatelessWidget {
  const _MealIconFallback({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      color: color.withValues(alpha: 0.12),
      child: Icon(icon, color: color, size: 30),
    );
  }
}
