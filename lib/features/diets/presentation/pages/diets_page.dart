import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';

class DietsPage extends StatelessWidget {
  const DietsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DietBloc>()..add(const DietLoadRequested()),
      child: const _DietsView(),
    );
  }
}

class _DietsView extends StatelessWidget {
  const _DietsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DietBloc, DietState>(
      builder: (context, state) {
        if (state is DietLoading || state is DietInitial) {
          return const ShimmerList(count: 4, itemHeight: 140);
        }
        if (state is DietError) {
          return ErrorWidget2(
            message: state.message,
            onRetry: () =>
                context.read<DietBloc>().add(const DietLoadRequested()),
          );
        }
        if (state is DietNoContent) {
          return EmptyWidget(
            message: 'No tienes dieta asignada hoy',
            subtitle:
                'Contacta a tu entrenador para que te asigne un plan nutricional',
            icon: Icons.restaurant_menu_outlined,
            action: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.message_outlined, size: 16),
              label: const Text('Contactar entrenador'),
            ),
          );
        }
        if (state is DietLoaded) {
          return _DietContent(state: state);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _DietContent extends StatelessWidget {
  final DietLoaded state;

  const _DietContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final diet = state.diet;
    final meals = diet.meals;
    final completedCount = state.completedMealIds.length;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async {
        context.read<DietBloc>().add(const DietLoadRequested());
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Diet header summary
          _DietHeader(diet: diet, completedCount: completedCount),

          // Meals section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Comidas del día',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Ensure ordered display: BREAKFAST, LUNCH, SNACK, DINNER
          ..._sortedMeals(meals).map(
            (meal) => _MealCard(
              meal: meal,
              isCompleted: state.completedMealIds.contains(meal.id),
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

class _DietHeader extends StatelessWidget {
  final DietEntity diet;
  final int completedCount;

  const _DietHeader({required this.diet, required this.completedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary.withOpacity(0.15), AppColors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  diet.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
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
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completedCount/${diet.meals.length} completadas',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
                  color: AppColors.calorieAccent,
                ),
              if (diet.totalProteinG != null)
                _MacroStat(
                  label: 'Proteína',
                  value: diet.totalProteinG!.toStringAsFixed(0),
                  unit: 'g',
                  color: AppColors.primary,
                ),
              if (diet.totalCarbsG != null)
                _MacroStat(
                  label: 'Carbos',
                  value: diet.totalCarbsG!.toStringAsFixed(0),
                  unit: 'g',
                  color: AppColors.secondary,
                ),
              if (diet.totalFatG != null)
                _MacroStat(
                  label: 'Grasas',
                  value: diet.totalFatG!.toStringAsFixed(0),
                  unit: 'g',
                  color: AppColors.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MacroStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealEntity meal;
  final bool isCompleted;
  final ValueChanged<bool> onToggle;

  const _MealCard({
    required this.meal,
    required this.isCompleted,
    required this.onToggle,
  });

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

  Color _mealColor(String type) {
    switch (type.toUpperCase()) {
      case 'BREAKFAST':
        return AppColors.warning;
      case 'LUNCH':
        return AppColors.secondary;
      case 'SNACK':
        return AppColors.primary;
      case 'DINNER':
        return AppColors.sleepAccent;
      default:
        return AppColors.textDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _mealColor(meal.type);

    return GestureDetector(
      onTap: () async {
        await context.push('/meals/${meal.id}');
        if (context.mounted) {
          context.read<DietBloc>().add(const DietLoadRequested());
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted
              ? AppColors.success.withOpacity(0.06)
              : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCompleted
                ? AppColors.success.withOpacity(0.35)
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            // Image or icon
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
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
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meal.name,
                    style: TextStyle(
                      color: isCompleted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (meal.calories != null) ...[
                        const Icon(
                          Icons.local_fire_department_outlined,
                          color: AppColors.textDisabled,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${meal.calories} kcal',
                          style: const TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (meal.proteinG != null)
                        Text(
                          'P: ${meal.proteinG!.toStringAsFixed(0)}g',
                          style: const TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 11,
                          ),
                        ),
                      if (meal.carbsG != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          'C: ${meal.carbsG!.toStringAsFixed(0)}g',
                          style: const TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Nutritional badges
                  if (meal.nutritionalBadges.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      children: meal.nutritionalBadges
                          .take(3)
                          .map(
                            (b) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                b,
                                style: const TextStyle(
                                  color: AppColors.textDisabled,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textDisabled,
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
                          ? AppColors.success
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? AppColors.success
                            : AppColors.textDisabled,
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
  final IconData icon;
  final Color color;

  const _MealIconFallback({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      color: color.withOpacity(0.12),
      child: Icon(icon, color: color, size: 30),
    );
  }
}
