import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
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

  String _dateLabel() {
    if (selectedDate == null) return 'hoy';
    final parsed = DateTime.tryParse(selectedDate!);
    if (parsed == null) return 'la fecha seleccionada';
    final now = DateTime.now();
    final isToday =
        parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
    if (isToday) return 'hoy';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<DietBloc, DietState>(
      builder: (context, state) {
        if (state is DietLoading || state is DietInitial) {
          return const ShimmerList(count: 4, itemHeight: 140);
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
            dateLabel: _dateLabel(),
          );
        }
        return const SizedBox.shrink();
      },
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
    final l10n = AppLocalizations.of(context)!;

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
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [semantic.calorie.withValues(alpha: 0.12), palette.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: semantic.calorie.withValues(alpha: 0.28)),
      ),
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
                  '$completedCount/${diet.meals.length} completadas',
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
            dateLabel == 'hoy'
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
                  label: 'Calorías',
                  value: '${diet.totalCalories}',
                  unit: 'kcal',
                  color: semantic.calorie,
                ),
              if (diet.totalProteinG != null)
                _MacroStat(
                  label: 'Proteína',
                  value: diet.totalProteinG!.toStringAsFixed(0),
                  unit: 'g',
                  color: palette.primary,
                ),
              if (diet.totalCarbsG != null)
                _MacroStat(
                  label: 'Carbos',
                  value: diet.totalCarbsG!.toStringAsFixed(0),
                  unit: 'g',
                  color: semantic.info,
                ),
              if (diet.totalFatG != null)
                _MacroStat(
                  label: 'Grasas',
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

  String _mealLabel(String type) {
    switch (type.toUpperCase()) {
      case 'BREAKFAST':
        return 'Desayuno';
      case 'LUNCH':
        return 'Almuerzo';
      case 'SNACK':
        return 'Snack';
      case 'DINNER':
        return 'Cena';
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

    return GestureDetector(
      onTap: () async {
        final dateQuery = selectedDate != null ? '?date=$selectedDate' : '';
        await context.push('/meals/${meal.id}$dateQuery');
        if (context.mounted) {
          context.read<DietBloc>().add(DietLoadRequested(date: selectedDate));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted
              ? semantic.success.withValues(alpha: 0.06)
              : palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCompleted
                ? semantic.success.withValues(alpha: 0.32)
                : palette.divider,
          ),
        ),
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
                      placeholder: (_, __) => _MealIconFallback(
                        icon: _mealIcon(meal.type),
                        color: color,
                      ),
                      errorWidget: (_, __, ___) => _MealIconFallback(
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
                      _mealLabel(meal.type),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
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
                  const SizedBox(height: 4),
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
                            color: palette.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
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
            const SizedBox(width: 8),
            Column(
              children: [
                Icon(
                  Icons.chevron_right,
                  color: palette.textDisabled,
                  size: 18,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => onToggle(!isCompleted),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? semantic.success
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? semantic.success
                            : palette.textDisabled,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
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
