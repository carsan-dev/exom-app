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

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _SheetTopBar(handleColor: palette.primary),
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
    final palette = context.exomPalette;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _SheetTopBar(handleColor: palette.primary),
        const SizedBox(height: 24),
        ErrorWidget2(message: message, onRetry: onRetry),
      ],
    );
  }
}

class _MealSheetBody extends StatelessWidget {
  const _MealSheetBody({
    required this.meal,
    required this.isCompleted,
    required this.scrollController,
  });

  final MealEntity meal;
  final bool isCompleted;
  final ScrollController scrollController;

  Future<void> _launchRecipe() async {
    final query = Uri.encodeComponent('${meal.name} receta');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
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

    if (meal.calories != null) {
      items.add(
        _MacroChipData(label: '${meal.calories} kcal', color: semantic.calorie),
      );
    }

    if (meal.proteinG != null) {
      items.add(
        _MacroChipData(
          label:
              '${l10n.proteinLabel.substring(0, 1).toUpperCase()} ${_formatNumber(meal.proteinG!)} g',
          color: semantic.accent,
        ),
      );
    }

    if (meal.carbsG != null) {
      items.add(
        _MacroChipData(
          label:
              '${l10n.carbsLabel.substring(0, 1).toUpperCase()} ${_formatNumber(meal.carbsG!)} g',
          color: semantic.warning,
        ),
      );
    }

    if (meal.fatG != null) {
      items.add(
        _MacroChipData(
          label:
              '${l10n.fatsLabel.substring(0, 1).toUpperCase()} ${_formatNumber(meal.fatG!)} g',
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
    final badges = meal.nutritionalBadges
        .map((badge) => badge.trim())
        .where((badge) => badge.isNotEmpty)
        .toList();
    final resolvedCompleted = dietState is MealDetailLoaded
        ? dietState.isCompleted
        : isCompleted;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _SheetTopBar(handleColor: palette.primary),
        const SizedBox(height: 8),
        Text(
          meal.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
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
        const SizedBox(height: 16),
        _MealHeroImage(meal: meal),
        if (macroChips.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MacroChipsRow(items: macroChips),
        ],
        if (meal.ingredients.isNotEmpty) ...[
          const SizedBox(height: 24),
          _IngredientsSection(ingredients: meal.ingredients),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<DietBloc>().add(
                    MarkMealCompleted(
                      mealId: meal.id,
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
                onPressed: _launchRecipe,
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
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: handleColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: handleColor.withValues(alpha: 0.24),
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
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
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
                    color: palette.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.divider),
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
                  '${_formatQuantity(ingredient.quantity)} ${ingredient.unit}',
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
