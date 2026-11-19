import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/presentation/widgets/diet_history_button.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_sync_state.dart';
import 'package:exom_app/features/diets/presentation/widgets/weekly_shopping_list_flow.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:exom_app/injection_container.dart';

class DietsPage extends StatelessWidget {
  const DietsPage({super.key, this.selectedDate});

  final String? selectedDate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DietBloc>()..add(DietLoadRequested(date: selectedDate)),
      child: Column(
        children: [
          Expanded(child: _DietsView(selectedDate: selectedDate)),
          DietHistoryButton(
            load: () => sl<DietRepository>().getDietHistory(date: selectedDate),
          ),
        ],
      ),
    );
  }
}

class _DietsView extends StatelessWidget {
  const _DietsView({this.selectedDate});

  final String? selectedDate;

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
            message: state.apiException != null
                ? localizedApiError(context, state.apiException!)
                : l10n.errorServer,
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
          return _DietContent(state: state, selectedDate: selectedDate);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Flat placeholder with the shape of the loaded screen: title, summary,
/// macros and meal rows closed by hairlines.
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
        SizedBox(height: 24),
        _MealRowSkeleton(),
        _MealRowSkeleton(),
        _MealRowSkeleton(),
        _MealRowSkeleton(),
      ],
    );
  }
}

class _DietHeaderSkeleton extends StatelessWidget {
  const _DietHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerCard(
            height: 42,
            width: 220,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          SizedBox(height: 12),
          ShimmerCard(
            height: 14,
            width: 160,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          SizedBox(height: 12),
          ShimmerCard(
            height: 20,
            width: 200,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ShimmerCard(
                height: 36,
                width: 64,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              SizedBox(width: 24),
              ShimmerCard(
                height: 36,
                width: 64,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              SizedBox(width: 24),
              ShimmerCard(
                height: 36,
                width: 64,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealRowSkeleton extends StatelessWidget {
  const _MealRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.exomPalette.borderSoft, width: 1),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            ShimmerCard(
              height: 48,
              width: 48,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerCard(
                    height: 18,
                    width: 120,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  SizedBox(height: 8),
                  ShimmerCard(
                    height: 14,
                    width: 190,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Re-reads the owner's offline queue (read only) whenever the sync service
/// reports a change, so the per-meal sync status follows mark, unmark, retry
/// and acknowledgement while the screen is open.
class _QueueActions extends StatefulWidget {
  const _QueueActions({required this.builder});

  final Widget Function(
    BuildContext context,
    List<Map<String, dynamic>> actions,
  )
  builder;

  @override
  State<_QueueActions> createState() => _QueueActionsState();
}

class _QueueActionsState extends State<_QueueActions> {
  StreamSubscription<void>? _changes;
  List<Map<String, dynamic>> _actions = const [];

  @override
  void initState() {
    super.initState();
    _read();
    if (sl.isRegistered<OfflineSyncService>()) {
      _changes = sl<OfflineSyncService>().changes.listen((_) {
        if (mounted) setState(_read);
      });
    }
  }

  void _read() {
    _actions = sl.isRegistered<LocalStorage>()
        ? sl<LocalStorage>().getPendingSyncActions()
        : const [];
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _actions);
}

class _DietContent extends StatelessWidget {
  const _DietContent({required this.state, required this.selectedDate});

  final DietLoaded state;
  final String? selectedDate;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final diet = state.diet;
    final meals = _sortedMeals(diet.meals);
    final completedCount = state.completedMealIds.length;

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: () async {
        context.read<DietBloc>().add(DietLoadRequested(date: selectedDate));
      },
      child: _QueueActions(
        builder: (context, actions) => ListView.builder(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          cacheExtent: PerformanceProfile.scrollCacheExtent(context),
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: meals.length + 3,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _DietHeader(
                diet: diet,
                completedCount: completedCount,
                completedMealIds: state.completedMealIds,
                date: DateTime.tryParse(state.selectedDate),
              );
            }
            if (index == 1) return const _MealsSectionTitle();
            if (index == meals.length + 2) {
              return _ShoppingListRow(
                date: DateTime.tryParse(state.selectedDate) ?? DateTime.now(),
              );
            }

            final meal = meals[index - 2];
            final completedMealId = _completedMealId(
              meal,
              state.completedMealIds,
            );
            return _MealRow(
              meal: meal,
              isCompleted: completedMealId != null,
              selectedDate: selectedDate,
              completedMealId: completedMealId,
              sync: mealSyncState(
                ownedActions: actions,
                date: state.selectedDate,
                mealIds: {meal.id, ...meal.variants.map((v) => v.id)},
              ),
              onToggle: (val, mealId) {
                context.read<DietBloc>().add(
                  MarkMealCompleted(mealId: mealId, completed: val),
                );
              },
            );
          },
        ),
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

  String? _completedMealId(MealEntity meal, Set<String> completedMealIds) {
    for (final mealId in [
      meal.id,
      ...meal.variants.map((variant) => variant.id),
    ]) {
      if (completedMealIds.contains(mealId)) return mealId;
    }
    return null;
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Semantics(
        header: true,
        child: Text(
          l10n.mealsOfTheDayLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Last row of the list (sketch «Nutrición»): opens the weekly shopping list
/// of the week that contains the shown date, the same flow as the calendar
/// export.
class _ShoppingListRow extends StatefulWidget {
  const _ShoppingListRow({required this.date});

  final DateTime date;

  @override
  State<_ShoppingListRow> createState() => _ShoppingListRowState();
}

class _ShoppingListRowState extends State<_ShoppingListRow> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startWeeklyShoppingList(context, widget.date);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      key: const Key('diet-shopping-list-row'),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderSoft, width: 1)),
      ),
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: _busy ? null : _open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.weeklyExportShoppingList,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen head (sketch «Nutrición»): plan name as the Barlow title, date,
/// kcal · meals summary, progress and what is left to eat.
class _DietHeader extends StatelessWidget {
  const _DietHeader({
    required this.diet,
    required this.completedCount,
    required this.completedMealIds,
    required this.date,
  });

  final DietEntity diet;
  final int completedCount;
  final Set<String> completedMealIds;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final remaining = diet.remainingMacros(completedMealIds);
    final mealsText = l10n.dietMealsCount(diet.meals.length);
    final summary = diet.totalCalories == null
        ? mealsText
        : '${diet.totalCalories} kcal · $mealsText';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeTitle(diet.name),
          if (date != null) ...[
            const SizedBox(height: 12),
            HomeDateLine(date: date!),
          ],
          const SizedBox(height: 12),
          Text(
            summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.dietMealsProgress(completedCount, diet.meals.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.remainingToConsumeLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              if (remaining.calories != null)
                _MacroStat(
                  label: l10n.caloriesLabel,
                  value: '${remaining.calories}',
                  unit: 'kcal',
                ),
              if (remaining.proteinG != null)
                _MacroStat(
                  label: l10n.proteinLabel,
                  value: remaining.proteinG!.toStringAsFixed(0),
                  unit: 'g',
                ),
              if (remaining.carbsG != null)
                _MacroStat(
                  label: l10n.carbsLabel,
                  value: remaining.carbsG!.toStringAsFixed(0),
                  unit: 'g',
                ),
              if (remaining.fatG != null)
                _MacroStat(
                  label: l10n.fatsLabel,
                  value: remaining.fatG!.toStringAsFixed(0),
                  unit: 'g',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One remaining-macro figure: Barlow numeral with its unit, label below. The
/// label names the figure, so the colour is not needed to tell them apart.
class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: AppTheme.displayFontFamily,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.0,
                color: palette.textPrimary,
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Meal row (sketch `.meal`): square 48 dp mark on the left, the rest of the
/// row opens the meal detail. Completed = filled mark with a check and a
/// struck-through name (never colour alone); a queued change adds the
/// "pending to sync" line with its clock icon.
class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.meal,
    required this.isCompleted,
    required this.selectedDate,
    required this.completedMealId,
    required this.sync,
    required this.onToggle,
  });

  final MealEntity meal;
  final bool isCompleted;
  final String? selectedDate;
  final String? completedMealId;
  final ExomSyncState? sync;
  final void Function(bool completed, String mealId) onToggle;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final metrics = [
      if (meal.calories != null) '${meal.calories} kcal',
      if (meal.proteinG != null) 'P ${meal.proteinG!.toStringAsFixed(0)} g',
      if (meal.carbsG != null) 'C ${meal.carbsG!.toStringAsFixed(0)} g',
    ].join(' · ');
    final tags = [
      if (meal.variants.isNotEmpty) l10n.optionsCount(meal.variants.length + 1),
      ...meal.nutritionalBadges.take(3),
    ];
    final imageUrl = meal.imageUrl;
    final syncState = sync;

    return DecoratedBox(
      key: Key('meal-row-${meal.id}'),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderSoft, width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MealMark(
              key: Key('meal-toggle-${meal.id}'),
              isCompleted: isCompleted,
              label: isCompleted
                  ? l10n.mealMarkUncompleteLabel(_mealLabel(context, meal.type))
                  : l10n.mealMarkCompleteLabel(_mealLabel(context, meal.type)),
              onTap: () => onToggle(
                !isCompleted,
                isCompleted ? completedMealId ?? meal.id : meal.id,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Semantics(
                button: true,
                child: InkWell(
                  onTap: () async {
                    await showMealDetailSheet(
                      context,
                      mealId: meal.id,
                      selectedDate: selectedDate,
                    );
                    if (context.mounted) {
                      context.read<DietBloc>().add(
                        DietLoadRequested(date: selectedDate),
                      );
                    }
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _mealLabel(context, meal.type),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                              Hero(
                                tag: 'meal-${meal.id}-title',
                                flightShuttleBuilder:
                                    (flightCtx, anim, dir, fromCtx, toCtx) {
                                      return Material(
                                        color: Colors.transparent,
                                        child: Text(
                                          meal.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleLarge
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
                                    meal.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: palette.textSecondary,
                                      fontSize: 14,
                                      height: 1.35,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: palette.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              if (metrics.isNotEmpty)
                                Text(
                                  metrics,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: palette.textSecondary,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              if (syncState != null) ...[
                                const SizedBox(height: 4),
                                ExomSyncStatus(state: syncState),
                              ],
                              if (tags.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final tag in tags)
                                      _MealTag(label: tag),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (imageUrl != null) ...[
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              memCacheWidth: PerformanceProfile.imageCacheWidth(
                                context,
                                56,
                              ),
                              placeholder: (context, url) =>
                                  const SizedBox(width: 56, height: 56),
                              errorWidget: (context, url, error) =>
                                  const SizedBox(width: 56, height: 56),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: ExcludeSemantics(
                            child: Icon(
                              Icons.chevron_right,
                              size: 22,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square 48 dp mark (sketch `.mark`): empty outline, or filled with a check
/// once the meal is done, so the state reads from the shape and not the colour.
class _MealMark extends StatelessWidget {
  const _MealMark({
    super.key,
    required this.isCompleted,
    required this.label,
    required this.onTap,
  });

  final bool isCompleted;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Semantics(
      button: true,
      checked: isCompleted,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCompleted ? palette.textPrimary : null,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.textPrimary, width: 1.5),
            ),
            child: isCompleted
                ? Icon(Icons.check, size: 26, color: palette.background)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Quiet tag (options count, nutritional badge): outlined, 13 px.
class _MealTag extends StatelessWidget {
  const _MealTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: palette.textSecondary,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
