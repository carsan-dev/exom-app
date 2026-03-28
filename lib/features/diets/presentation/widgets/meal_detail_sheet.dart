import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/injection_container.dart';

/// Shows the meal detail as a modal bottom sheet.
Future<void> showMealDetailSheet(
  BuildContext context, {
  required String mealId,
  String? selectedDate,
  VoidCallback? onDismissed,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.exomPalette.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => MealDetailSheet(
        mealId: mealId,
        selectedDate: selectedDate,
        scrollController: scrollController,
      ),
    ),
  );
  onDismissed?.call();
}

class MealDetailSheet extends StatelessWidget {
  const MealDetailSheet({
    super.key,
    required this.mealId,
    required this.scrollController,
    this.selectedDate,
  });

  final String mealId;
  final String? selectedDate;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<DietBloc>()
            ..add(MealDetailLoadRequested(mealId, date: selectedDate)),
      child: _MealDetailSheetContent(scrollController: scrollController),
    );
  }
}

class _MealDetailSheetContent extends StatelessWidget {
  const _MealDetailSheetContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return BlocBuilder<DietBloc, DietState>(
      builder: (context, state) {
        if (state is DietLoading || state is DietInitial) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: palette.textDisabled.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              for (int i = 0; i < 4; i++) ...[
                const ShimmerCard(height: 80),
                if (i < 3) const SizedBox(height: 12),
              ],
            ],
          );
        }
        if (state is DietError) {
          return Center(child: ErrorWidget2(message: state.message));
        }
        if (state is MealDetailLoaded) {
          return _MealSheetBody(
            meal: state.meal,
            isCompleted: state.isCompleted,
            scrollController: scrollController,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _MealSheetBody extends StatefulWidget {
  const _MealSheetBody({
    required this.meal,
    required this.isCompleted,
    required this.scrollController,
  });

  final MealEntity meal;
  final bool isCompleted;
  final ScrollController scrollController;

  @override
  State<_MealSheetBody> createState() => _MealSheetBodyState();
}

class _MealSheetBodyState extends State<_MealSheetBody> {
  String _mealTypeLabel(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;
    final dietState = context.watch<DietBloc>().state;
    final isCompleted = dietState is MealDetailLoaded
        ? dietState.isCompleted
        : widget.isCompleted;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Drag handle + close button
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.textDisabled.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: palette.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),

        // Meal name + type badge
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
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
                      _mealTypeLabel(context, meal.type),
                      style: TextStyle(
                        color: semantic.calorie,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Nutritional badges
        if (meal.nutritionalBadges.isNotEmpty) ...[
          const SizedBox(height: 10),
          _NutritionalBadges(badges: meal.nutritionalBadges),
        ],

        const SizedBox(height: 14),

        // Hero image or placeholder
        _MealHeroImage(meal: meal),

        // Macros section
        _MacroSection(meal: meal),

        const SizedBox(height: 4),

        // Ingredients
        if (meal.ingredients.isNotEmpty)
          _IngredientsSection(ingredients: meal.ingredients),

        // Recipe button
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _launchRecipe,
            icon: const Icon(Icons.search, size: 18),
            label: Text(l10n.openRecipeButton),
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

        // Complete / uncomplete button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              isCompleted
                  ? l10n.completedFeminine
                  : l10n.markMealCompletedButton,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleted ? semantic.success : palette.primary,
              foregroundColor: palette.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-Widgets ───────────────────────────────────────────────────────────────

class _MealHeroImage extends StatelessWidget {
  final MealEntity meal;

  const _MealHeroImage({required this.meal});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final primary = palette.primary;
    return meal.imageUrl != null
        ? CachedNetworkImage(
            imageUrl: meal.imageUrl!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 200,
              color: palette.surfaceVariant,
              child: Center(child: CircularProgressIndicator(color: primary)),
            ),
            errorWidget: (_, __, ___) => _MealPlaceholderHero(),
          )
        : _MealPlaceholderHero();
  }
}

class _MealPlaceholderHero extends StatelessWidget {
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
    final l10n = AppLocalizations.of(context)!;
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
            l10n.nutritionalInfoTitle,
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
                  label: l10n.caloriesLabel,
                  value: '${meal.calories}',
                  unit: 'kcal',
                  color: semantic.calorie,
                ),
              if (meal.proteinG != null)
                _MacroRing(
                  label: l10n.proteinLabel,
                  value: meal.proteinG!.toStringAsFixed(1),
                  unit: 'g',
                  color: palette.primary,
                ),
              if (meal.carbsG != null)
                _MacroRing(
                  label: l10n.carbsLabel,
                  value: meal.carbsG!.toStringAsFixed(1),
                  unit: 'g',
                  color: semantic.info,
                ),
              if (meal.fatG != null)
                _MacroRing(
                  label: l10n.fatsLabel,
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            l10n.ingredientsTitle,
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
