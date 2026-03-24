import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';

class MealDetailPage extends StatelessWidget {
  final String mealId;
  final String? selectedDate;

  const MealDetailPage({super.key, required this.mealId, this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<DietBloc>()
            ..add(MealDetailLoadRequested(mealId, date: selectedDate)),
      child: const _MealDetailView(),
    );
  }
}

class _MealDetailView extends StatelessWidget {
  const _MealDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DietBloc, DietState>(
      builder: (context, state) {
        if (state is DietLoading || state is DietInitial) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
            ),
            body: const ShimmerList(count: 5, itemHeight: 80),
          );
        }
        if (state is DietError) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
            ),
            body: ErrorWidget2(message: state.message),
          );
        }
        if (state is MealDetailLoaded) {
          return _MealScaffold(meal: state.meal);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _MealScaffold extends StatefulWidget {
  final MealEntity meal;

  const _MealScaffold({required this.meal});

  @override
  State<_MealScaffold> createState() => _MealScaffoldState();
}

class _MealScaffoldState extends State<_MealScaffold> {
  String _mealTypeLabel(String type) {
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

  Future<void> _launchRecipe() async {
    final query = Uri.encodeComponent('${widget.meal.name} receta');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final dietState = context.watch<DietBloc>().state;
    final isCompleted = dietState is MealDetailLoaded
        ? dietState.isCompleted
        : false;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(meal.name),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // Hero image or placeholder
              _MealHeroImage(meal: meal),

              const SizedBox(height: 16),

              // Meal type badge + name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
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
                        _mealTypeLabel(meal.type),
                        style: TextStyle(
                          color: semantic.calorie,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Macros section
              _MacroSection(meal: meal),

              const SizedBox(height: 8),

              // Nutritional badges
              if (meal.nutritionalBadges.isNotEmpty)
                _NutritionalBadges(badges: meal.nutritionalBadges),

              // Ingredients
              if (meal.ingredients.isNotEmpty)
                _IngredientsSection(ingredients: meal.ingredients),

              // Recipe button
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _launchRecipe,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Ver Receta en Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: semantic.calorie,
                    side: BorderSide(color: semantic.calorie),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bottom button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.divider)),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<DietBloc>().add(
                    MarkMealCompleted(mealId: meal.id, completed: !isCompleted),
                  );
                },
                icon: Icon(
                  isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                  size: 20,
                ),
                label: Text(
                  isCompleted ? 'Completada' : 'Marcar como completada',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted
                      ? semantic.success
                      : palette.primary,
                  foregroundColor: palette.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealHeroImage extends StatelessWidget {
  final MealEntity meal;

  const _MealHeroImage({required this.meal});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final primary = context.exomPalette.primary;
    return meal.imageUrl != null
        ? CachedNetworkImage(
            imageUrl: meal.imageUrl!,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 220,
              color: palette.surfaceVariant,
              child: Center(child: CircularProgressIndicator(color: primary)),
            ),
            errorWidget: (_, __, ___) => _PlaceholderHero(),
          )
        : _PlaceholderHero();
  }
}

class _PlaceholderHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Container(
      height: 200,
      color: palette.surfaceVariant,
      child: Center(
        child: Icon(Icons.restaurant, color: palette.textDisabled, size: 64),
      ),
    );
  }
}

class _MacroSection extends StatelessWidget {
  final MealEntity meal;

  const _MacroSection({required this.meal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final hasData =
        meal.calories != null ||
        meal.proteinG != null ||
        meal.carbsG != null ||
        meal.fatG != null;

    if (!hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información nutricional',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (meal.calories != null)
                _MacroRing(
                  label: 'Calorías',
                  value: '${meal.calories}',
                  unit: 'kcal',
                  color: semantic.calorie,
                ),
              if (meal.proteinG != null)
                _MacroRing(
                  label: 'Proteína',
                  value: meal.proteinG!.toStringAsFixed(1),
                  unit: 'g',
                  color: palette.primary,
                ),
              if (meal.carbsG != null)
                _MacroRing(
                  label: 'Carbos',
                  value: meal.carbsG!.toStringAsFixed(1),
                  unit: 'g',
                  color: semantic.info,
                ),
              if (meal.fatG != null)
                _MacroRing(
                  label: 'Grasas',
                  value: meal.fatG!.toStringAsFixed(1),
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

class _MacroRing extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MacroRing({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            color: color.withValues(alpha: 0.1),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
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

class _NutritionalBadges extends StatelessWidget {
  final List<String> badges;

  const _NutritionalBadges({required this.badges});

  @override
  Widget build(BuildContext context) {
    final semantic = context.exomSemantic;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: badges
            .map(
              (b) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: semantic.calorie.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  b,
                  style: TextStyle(
                    color: semantic.calorie,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  final List<MealIngredientEntity> ingredients;

  const _IngredientsSection({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Ingredientes',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.divider),
          ),
          child: Column(
            children: ingredients.asMap().entries.map((entry) {
              final i = entry.key;
              final ing = entry.value;
              final isLast = i == ingredients.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ing.name,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${ing.quantity % 1 == 0 ? ing.quantity.toInt() : ing.quantity} ${ing.unit}',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, color: palette.divider, indent: 36),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
