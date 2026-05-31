import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/core/navigation/page_aware_bottom_sheet.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/injection_container.dart';

Future<void> showMealDetailSheet(
  BuildContext context, {
  required String mealId,
  String? selectedDate,
  VoidCallback? onDismissed,
}) async {
  await showPageAwareModalBottomSheet<void>(
    context: context,
    backgroundColor: context.exomPalette.surface,
    isScrollControlled: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (sheetContext, scrollController) => MealDetailSheet(
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
      create: (blocContext) =>
          sl<DietBloc>()
            ..add(MealDetailLoadRequested(mealId, date: selectedDate)),
      child: _MealDetailSheetContent(
        mealId: mealId,
        selectedDate: selectedDate,
        scrollController: scrollController,
      ),
    );
  }
}

class _MealDetailSheetContent extends StatelessWidget {
  const _MealDetailSheetContent({
    required this.mealId,
    required this.selectedDate,
    required this.scrollController,
  });

  final String mealId;
  final String? selectedDate;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DietBloc, DietState>(
      builder: (context, state) {
        if (state is DietLoading || state is DietInitial) {
          return _MealDetailLoading(scrollController: scrollController);
        }

        if (state is DietError) {
          return _MealDetailError(
            scrollController: scrollController,
            message: state.message,
            onRetry: () {
              context.read<DietBloc>().add(
                MealDetailLoadRequested(mealId, date: selectedDate),
              );
            },
          );
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

class _MealDetailLoading extends StatelessWidget {
  const _MealDetailLoading({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
      children: [
        _SheetTopBar(handleColor: context.dietAccent),
        const SizedBox(height: 16),
        const ShimmerCard(height: 28),
        const SizedBox(height: 12),
        Row(
          children: const [
            ShimmerCard(
              height: 28,
              width: 84,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            SizedBox(width: 8),
            ShimmerCard(
              height: 28,
              width: 78,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            SizedBox(width: 8),
            ShimmerCard(
              height: 28,
              width: 74,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Divider(color: palette.divider, height: 1),
        const SizedBox(height: 16),
        const ShimmerCard(
          height: 196,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            ShimmerCard(
              height: 34,
              width: 92,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            ShimmerCard(
              height: 34,
              width: 84,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            ShimmerCard(
              height: 34,
              width: 84,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            ShimmerCard(
              height: 34,
              width: 84,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const ShimmerCard(height: 164),
        const SizedBox(height: 28),
        Row(
          children: const [
            Expanded(child: ShimmerCard(height: 52)),
            SizedBox(width: 12),
            Expanded(child: ShimmerCard(height: 52)),
          ],
        ),
      ],
    );
  }
}

class _MealDetailError extends StatelessWidget {
  const _MealDetailError({
    required this.scrollController,
    required this.message,
    required this.onRetry,
  });

  final ScrollController scrollController;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
      children: [
        _SheetTopBar(handleColor: context.dietAccent),
        const SizedBox(height: 24),
        ErrorWidget2(message: message, onRetry: onRetry),
      ],
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
  late MealEntity _selectedMeal = widget.meal;
  bool _selectionTouched = false;

  @override
  void didUpdateWidget(covariant _MealSheetBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meal.id != widget.meal.id) {
      _selectedMeal = widget.meal;
      _selectionTouched = false;
    }
  }

  Future<void> _launchRecipe(BuildContext context) async {
    final url = Uri.https('www.google.com', '/search', {
      'q': '${_selectedMeal.name} receta',
    });

    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);

    if (!launched) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  List<_MacroChipData> _buildMacroChips(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final items = <_MacroChipData>[];

    if (_selectedMeal.calories != null) {
      items.add(
        _MacroChipData(
          label: '${_selectedMeal.calories} kcal',
          color: semantic.calorie,
        ),
      );
    }

    if (_selectedMeal.proteinG != null) {
      items.add(
        _MacroChipData(
          label:
              '${l10n.proteinLabel.substring(0, 1).toUpperCase()} ${_formatNumber(_selectedMeal.proteinG!)} g',
          color: semantic.accent,
        ),
      );
    }

    if (_selectedMeal.carbsG != null) {
      items.add(
        _MacroChipData(
          label:
              '${l10n.carbsLabel.substring(0, 1).toUpperCase()} ${_formatNumber(_selectedMeal.carbsG!)} g',
          color: semantic.warning,
        ),
      );
    }

    if (_selectedMeal.fatG != null) {
      items.add(
        _MacroChipData(
          label:
              '${l10n.fatsLabel.substring(0, 1).toUpperCase()} ${_formatNumber(_selectedMeal.fatG!)} g',
          color: palette.primary,
        ),
      );
    }

    return items;
  }

  Color _badgeColor(BuildContext context, String badge) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final normalized = badge.toLowerCase();

    if (normalized.contains('prote')) return semantic.accent;
    if (normalized.contains('gras') || normalized.contains('fat')) {
      return palette.primary;
    }
    if (normalized.contains('fib') || normalized.contains('fiber')) {
      return palette.textSecondary;
    }
    if (normalized.contains('carb')) return semantic.warning;
    return semantic.calorie;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final dietState = context.watch<DietBloc>().state;
    final macroChips = _buildMacroChips(context);
    final badges = _selectedMeal.nutritionalBadges
        .map((badge) => badge.trim())
        .where((badge) => badge.isNotEmpty)
        .toList();
    final mealOptions = [widget.meal, ...widget.meal.variants];
    final completedMealIds = dietState is MealDetailLoaded
        ? dietState.completedMealIds
        : widget.isCompleted
            ? {widget.meal.id}
            : <String>{};
    if (!_selectionTouched &&
        !completedMealIds.contains(_selectedMeal.id)) {
      for (final option in mealOptions) {
        if (completedMealIds.contains(option.id)) {
          _selectedMeal = option;
          break;
        }
      }
    }
    final resolvedCompleted = completedMealIds.contains(_selectedMeal.id);

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
      children: [
        _SheetTopBar(handleColor: context.dietAccent),
        const SizedBox(height: 8),
        Hero(
          tag: 'meal-${widget.meal.id}-title',
          flightShuttleBuilder: (flightCtx, anim, dir, fromCtx, toCtx) {
            return Material(
              color: Colors.transparent,
              child: Text(
                _selectedMeal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.374,
                ),
              ),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Text(
              _selectedMeal.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: palette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.374,
              ),
            ),
          ),
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(
                  l10n.richInLabel,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...badges.map(
                (badge) => _NutritionalBadgePill(
                  label: badge,
                  color: _badgeColor(context, badge),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Divider(color: palette.divider, height: 1),
        if (mealOptions.length > 1) ...[
          const SizedBox(height: 16),
          _VariantSelector(
            meals: mealOptions,
            selectedMealId: _selectedMeal.id,
            onChanged: (meal) => setState(() {
              _selectionTouched = true;
              _selectedMeal = meal;
            }),
          ),
        ],
        const SizedBox(height: 16),
        _MealHeroImage(meal: _selectedMeal),
        if (macroChips.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MacroChipsRow(items: macroChips),
        ],
        if (_selectedMeal.ingredients.isNotEmpty) ...[
          const SizedBox(height: 24),
          _IngredientsSection(ingredients: _selectedMeal.ingredients),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<DietBloc>().add(
                    MarkMealCompleted(
                      mealId: _selectedMeal.id,
                      completed: !resolvedCompleted,
                    ),
                  );
                },
                icon: Icon(
                  resolvedCompleted
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  size: 18,
                ),
                label: Text(
                  resolvedCompleted
                      ? l10n.mealCompletedButton
                      : l10n.completeButton,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: resolvedCompleted
                      ? semantic.success
                      : palette.primary,
                  foregroundColor: palette.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _launchRecipe(context),
                icon: const Icon(Icons.search, size: 18),
                label: Text(l10n.recipeButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: BorderSide(color: palette.divider),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VariantSelector extends StatelessWidget {
  const _VariantSelector({
    required this.meals,
    required this.selectedMealId,
    required this.onChanged,
  });

  final List<MealEntity> meals;
  final String selectedMealId;
  final ValueChanged<MealEntity> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final selected = meals.firstWhere(
      (meal) => meal.id == selectedMealId,
      orElse: () => meals.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige una opción',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(selected.id),
          initialValue: selected.id,
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.surfaceVariant.withValues(alpha: 0.6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.divider),
            ),
          ),
          dropdownColor: palette.surface,
          iconEnabledColor: palette.textSecondary,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: meals
              .map(
                (meal) => DropdownMenuItem<String>(
                  value: meal.id,
                  child: Text(
                    meal.id == meals.first.id ? '${meal.name} (principal)' : meal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            final next = meals.firstWhere((meal) => meal.id == value);
            onChanged(next);
          },
        ),
      ],
    );
  }
}

class _SheetTopBar extends StatelessWidget {
  const _SheetTopBar({required this.handleColor});

  final Color handleColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 72,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: handleColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: handleColor.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: _SheetHeaderAction(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              highlighted: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHeaderAction extends StatelessWidget {
  const _SheetHeaderAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Material(
      color: highlighted
          ? palette.surfaceVariant.withValues(alpha: 0.92)
          : palette.surface.withValues(alpha: 0.72),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: palette.textPrimary, size: 18),
          ),
        ),
      ),
    );
  }
}

class _MealHeroImage extends StatelessWidget {
  const _MealHeroImage({required this.meal});

  final MealEntity meal;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final imageUrl = meal.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      height: 196,
      clipBehavior: Clip.antiAlias,
      decoration: GlassDecoration.card(borderRadius: 18),
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, imageUrl) => Container(
                color: palette.surfaceVariant,
                alignment: Alignment.center,
                child: CircularProgressIndicator(color: palette.primary),
              ),
              errorWidget: (context, imageUrl, error) =>
                  const _MealPlaceholderHero(),
            )
          : const _MealPlaceholderHero(),
    );
  }
}

class _MealPlaceholderHero extends StatelessWidget {
  const _MealPlaceholderHero();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.surfaceVariant, palette.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_rounded,
        color: palette.textDisabled,
        size: 48,
      ),
    );
  }
}

class _MacroChipData {
  const _MacroChipData({required this.label, required this.color});

  final String label;
  final Color color;
}

class _MacroChipsRow extends StatelessWidget {
  const _MacroChipsRow({required this.items});

  final List<_MacroChipData> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: item.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _NutritionalBadgePill extends StatelessWidget {
  const _NutritionalBadgePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({required this.ingredients});

  final List<MealIngredientEntity> ingredients;

  String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _unitLabel(String unit) {
    switch (unit) {
      case 'g':
        return 'g';
      case 'ml':
        return 'ml';
      case 'piece':
        return 'unidad';
      case 'tablespoon':
        return 'cucharada';
      case 'teaspoon':
        return 'cucharadita';
      case 'handful':
        return 'puñado';
      case 'slice':
        return 'rebanada';
      case 'palm':
        return 'palma';
      case 'fist':
        return 'puño';
      case 'ladle':
        return 'cucharón';
      case 'cold_cut_slice':
        return 'loncha';
      case 'glass':
        return 'vaso';
      case 'cup':
        return 'taza';
      case 'pinch':
        return 'pizca';
      case 'serving':
        return 'ración';
      case 'to_taste':
        return 'al gusto';
      default:
        return unit;
    }
  }

  String _ingredientAmountLabel(MealIngredientEntity ingredient) {
    final unit = _unitLabel(ingredient.unit);

    if (ingredient.unit == 'to_taste') {
      return unit;
    }

    final base = '${_formatQuantity(ingredient.quantity)} $unit';
    final grams = ingredient.gramsEquivalent;

    if (ingredient.unit == 'g' || grams == null || grams <= 0) {
      return base;
    }

    return '$base (${_formatQuantity(grams)} g)';
  }

  IconData _fallbackIcon(String ingredientName) {
    final normalized = ingredientName.toLowerCase();

    if (normalized.contains('leche') ||
        normalized.contains('yogur') ||
        normalized.contains('yogurt') ||
        normalized.contains('bebida')) {
      return Icons.local_drink_outlined;
    }

    if (normalized.contains('pollo') ||
        normalized.contains('atun') ||
        normalized.contains('pesc') ||
        normalized.contains('carne') ||
        normalized.contains('huevo')) {
      return Icons.local_dining_outlined;
    }

    if (normalized.contains('avena') ||
        normalized.contains('semilla') ||
        normalized.contains('platano') ||
        normalized.contains('plátano') ||
        normalized.contains('fruta') ||
        normalized.contains('verdura')) {
      return Icons.eco_outlined;
    }

    return Icons.restaurant_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.ingredientsTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: palette.divider, height: 1),
        const SizedBox(height: 12),
        ...ingredients.asMap().entries.map((entry) {
          final index = entry.key;
          final ingredient = entry.value;
          final iconLabel = ingredient.icon?.trim();
          final showGlyph =
              iconLabel != null &&
              iconLabel.isNotEmpty &&
              iconLabel.length <= 2;

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == ingredients.length - 1 ? 0 : 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.glassBackground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.glassBorder.withValues(alpha: 0.15),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: showGlyph
                      ? Text(iconLabel, style: const TextStyle(fontSize: 14))
                      : Icon(
                          _fallbackIcon(ingredient.name),
                          color: palette.textSecondary,
                          size: 16,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ingredient.name,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _ingredientAmountLabel(ingredient),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
