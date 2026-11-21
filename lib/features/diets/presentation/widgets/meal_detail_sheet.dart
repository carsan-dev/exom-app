import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/core/navigation/page_aware_bottom_sheet.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart' show kExomSheetRadius;
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/services/ingredient_unit_formatter.dart';
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
    // Surface and border are painted in the builder so they follow the live
    // theme; a color captured here would stay stale if the theme changes.
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (sheetContext) {
      final palette = sheetContext.exomPalette;
      return Material(
        color: palette.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(kExomSheetRadius),
          ),
          side: BorderSide(color: palette.borderSoft, width: 1),
        ),
        child: DraggableScrollableSheet(
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
    },
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
            message: state.apiException != null
                ? localizedApiError(context, state.apiException!)
                : AppLocalizations.of(context).errorServer,
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

const BorderRadius _skeletonRadius = BorderRadius.all(Radius.circular(4));

class _MealDetailLoading extends StatelessWidget {
  const _MealDetailLoading({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + bottomInset),
      children: const [
        _SheetTopBar(),
        ShimmerCard(height: 168, borderRadius: _skeletonRadius),
        SizedBox(height: 16),
        ShimmerCard(height: 28, width: 220, borderRadius: _skeletonRadius),
        SizedBox(height: 16),
        ShimmerCard(height: 72, width: 160, borderRadius: _skeletonRadius),
        SizedBox(height: 16),
        ShimmerCard(height: 64, borderRadius: _skeletonRadius),
        SizedBox(height: 24),
        ShimmerCard(height: 120, borderRadius: _skeletonRadius),
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
      padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + bottomInset),
      children: [
        const _SheetTopBar(),
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

  /// Up to two decimals, with the separator of the app locale; no thousands
  /// grouping (L5-D33).
  String _formatNumber(BuildContext context, double value) => NumberFormat(
    '0.##',
    AppLocalizations.of(context).localeName,
  ).format(value);

  String _mealTypeLabel(AppLocalizations l10n, String type) {
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

  List<ExomFigure> _macroFigures(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      if (_selectedMeal.proteinG != null)
        ExomFigure(
          label: l10n.proteinLabel,
          value: _formatNumber(context, _selectedMeal.proteinG!),
          unit: 'g',
        ),
      if (_selectedMeal.carbsG != null)
        ExomFigure(
          label: l10n.carbsLabel,
          value: _formatNumber(context, _selectedMeal.carbsG!),
          unit: 'g',
        ),
      if (_selectedMeal.fatG != null)
        ExomFigure(
          label: l10n.fatsLabel,
          value: _formatNumber(context, _selectedMeal.fatG!),
          unit: 'g',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final dietState = context.watch<DietBloc>().state;
    final figures = _macroFigures(context);
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
    if (!_selectionTouched && !completedMealIds.contains(_selectedMeal.id)) {
      for (final option in mealOptions) {
        if (completedMealIds.contains(option.id)) {
          _selectedMeal = option;
          break;
        }
      }
    }
    final resolvedCompleted = completedMealIds.contains(_selectedMeal.id);
    final calories = _selectedMeal.calories;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    void toggleCompleted() {
      context.read<DietBloc>().add(
        MarkMealCompleted(
          mealId: _selectedMeal.id,
          completed: !resolvedCompleted,
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const _SheetTopBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _MealPhoto(meal: _selectedMeal),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExomKicker(_mealTypeLabel(l10n, _selectedMeal.type)),
                    const SizedBox(height: 8),
                    Hero(
                      tag: 'meal-${widget.meal.id}-title',
                      flightShuttleBuilder:
                          (flightCtx, anim, dir, fromCtx, toCtx) {
                            return Material(
                              color: Colors.transparent,
                              child: Text(
                                _selectedMeal.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
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
                          style: ExomType.section.copyWith(
                            color: palette.textPrimary,
                            fontSize: 30,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (calories != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: ExomNumeral(
                    value: '$calories',
                    unit: 'kcal',
                    size: ExomNumeralSize.hero96,
                    side: mealOptions.length > 1
                        ? Text(
                            l10n.optionsCount(mealOptions.length),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: palette.textSecondary,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                          )
                        : null,
                  ),
                ),
              if (figures.isNotEmpty) ...[
                const SizedBox(height: 16),
                ExomFigureColumns(items: figures, numbered: false),
              ],
              if (mealOptions.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _OptionSelector(
                    meals: mealOptions,
                    selectedMealId: _selectedMeal.id,
                    onChanged: (meal) => setState(() {
                      _selectionTouched = true;
                      _selectedMeal = meal;
                    }),
                  ),
                ),
              if (badges.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExomKicker(l10n.richInLabel),
                      const SizedBox(height: 4),
                      Text(
                        badges.join(' · '),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: palette.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_selectedMeal.ingredients.isNotEmpty) ...[
                const SizedBox(height: 16),
                _IngredientsSection(ingredients: _selectedMeal.ingredients),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(
              top: BorderSide(color: palette.borderSoft, width: 1),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (resolvedCompleted)
                  ExomSecondaryButton(
                    label: l10n.mealCompletedButton,
                    icon: Icons.check,
                    onPressed: toggleCompleted,
                  )
                else
                  ExomPrimaryButton(
                    label: l10n.completeButton,
                    trailingIcon: Icons.check,
                    onPressed: toggleCompleted,
                  ),
                const SizedBox(height: 4),
                Center(
                  child: ExomQuietButton(
                    label: l10n.recipeButton,
                    onPressed: () => _launchRecipe(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Options of the meal as choice chips (sketch `.x-chips`): the main one first,
/// then its alternatives. Picking one only changes what the sheet shows and
/// which meal «Completar» marks; nothing is written until then.
class _OptionSelector extends StatelessWidget {
  const _OptionSelector({
    required this.meals,
    required this.selectedMealId,
    required this.onChanged,
  });

  final List<MealEntity> meals;
  final String selectedMealId;
  final ValueChanged<MealEntity> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byId = {for (final meal in meals) meal.id: meal};
    final selected = byId.containsKey(selectedMealId)
        ? selectedMealId
        : meals.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExomKicker(l10n.mealOptionsLabel),
        const SizedBox(height: 8),
        ExomChoiceChips<String>(
          options: [for (final meal in meals) meal.id],
          selected: selected,
          labelOf: (id) =>
              id == meals.first.id ? l10n.weeklyVariantMain : byId[id]!.name,
          semanticLabelOf: (id) =>
              id == meals.first.id ? l10n.weeklyVariantMain : byId[id]!.name,
          onSelected: (id) => onChanged(byId[id]!),
        ),
      ],
    );
  }
}

/// Grab handle and close action of the sheet. The handle is the EXOM sheet
/// one (40x4, `borderSoft`); closing goes through the navigator like any pop.
class _SheetTopBar extends StatelessWidget {
  const _SheetTopBar();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: palette.borderSoft,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Icon(Icons.close, color: palette.textPrimary, size: 22),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ),
        ],
      ),
    );
  }
}

/// Meal photo (sketch `.x-photo`, 168 dp): the image, or a raised-surface box
/// with the meal icon while it loads, if it fails or when there is none.
class _MealPhoto extends StatelessWidget {
  const _MealPhoto({required this.meal});

  final MealEntity meal;

  @override
  Widget build(BuildContext context) {
    final imageUrl = meal.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    const placeholder = _MealPhotoPlaceholder();

    return SizedBox(
      height: 168,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, imageUrl) => placeholder,
                errorWidget: (context, imageUrl, error) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

class _MealPhotoPlaceholder extends StatelessWidget {
  const _MealPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        border: Border.all(color: palette.borderSoft),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: ExcludeSemantics(
          child: Icon(
            Icons.restaurant_outlined,
            color: palette.textSecondary,
            size: 32,
          ),
        ),
      ),
    );
  }
}

/// Numbered ingredients (sketch `.x-sh` + `.rows`): name on the left, amount on
/// the right, one hairline between rows.
class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({required this.ingredients});

  final List<MealIngredientEntity> ingredients;

  String _ingredientAmountLabel(
    BuildContext context,
    MealIngredientEntity ingredient,
  ) =>
      IngredientUnitFormatter(
        locale: Localizations.localeOf(context).toString(),
      ).amount(
        quantityValue: ingredient.quantity,
        unitCode: ingredient.unit,
        gramsEquivalent: ingredient.gramsEquivalent,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExomNumberedSectionHeader(n: 1, title: l10n.ingredientsTitle),
        for (var i = 0; i < ingredients.length; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(
                      top: BorderSide(color: palette.borderSoft, width: 1),
                    ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        ingredients[i].name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: palette.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _ingredientAmountLabel(context, ingredients[i]),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
