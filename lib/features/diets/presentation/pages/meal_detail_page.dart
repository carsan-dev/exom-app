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

  const MealDetailPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DietBloc>()..add(MealDetailLoadRequested(mealId)),
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
            backgroundColor: AppColors.background,
            appBar: AppBar(backgroundColor: AppColors.background),
            body: const ShimmerList(count: 5, itemHeight: 80),
          );
        }
        if (state is DietError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(backgroundColor: AppColors.background),
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
  bool _markedCompleted = false;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _mealTypeLabel(meal.type),
                        style: const TextStyle(
                          color: AppColors.secondary,
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
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
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
                color: AppColors.surface,
                border: const Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _markedCompleted = !_markedCompleted);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _markedCompleted
                            ? '¡${meal.name} marcado como completado!'
                            : '${meal.name} desmarcado',
                      ),
                      backgroundColor: _markedCompleted ? AppColors.success : AppColors.surfaceVariant,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                icon: Icon(
                  _markedCompleted ? Icons.check_circle : Icons.check_circle_outline,
                  size: 20,
                ),
                label: Text(
                  _markedCompleted ? 'Completado' : 'Marcar como completada',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _markedCompleted ? AppColors.success : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return meal.imageUrl != null
        ? CachedNetworkImage(
            imageUrl: meal.imageUrl!,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 220,
              color: AppColors.surfaceVariant,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            errorWidget: (_, __, ___) => _PlaceholderHero(),
          )
        : _PlaceholderHero();
  }
}

class _PlaceholderHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Icon(Icons.restaurant, color: AppColors.textDisabled, size: 64),
      ),
    );
  }
}

class _MacroSection extends StatelessWidget {
  final MealEntity meal;

  const _MacroSection({required this.meal});

  @override
  Widget build(BuildContext context) {
    final hasData = meal.calories != null ||
        meal.proteinG != null ||
        meal.carbsG != null ||
        meal.fatG != null;

    if (!hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información nutricional',
            style: TextStyle(
              color: AppColors.textPrimary,
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
                  color: AppColors.calorieAccent,
                ),
              if (meal.proteinG != null)
                _MacroRing(
                  label: 'Proteína',
                  value: meal.proteinG!.toStringAsFixed(1),
                  unit: 'g',
                  color: AppColors.primary,
                ),
              if (meal.carbsG != null)
                _MacroRing(
                  label: 'Carbos',
                  value: meal.carbsG!.toStringAsFixed(1),
                  unit: 'g',
                  color: AppColors.secondary,
                ),
              if (meal.fatG != null)
                _MacroRing(
                  label: 'Grasas',
                  value: meal.fatG!.toStringAsFixed(1),
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
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            color: color.withOpacity(0.1),
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
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 9),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: badges.map((b) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            b,
            style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        )).toList(),
      ),
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  final List<MealIngredientEntity> ingredients;

  const _IngredientsSection({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Ingredientes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: ingredients.asMap().entries.map((entry) {
              final i = entry.key;
              final ing = entry.value;
              final isLast = i == ingredients.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ing.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${ing.quantity % 1 == 0 ? ing.quantity.toInt() : ing.quantity} ${ing.unit}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: AppColors.divider, indent: 36),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
