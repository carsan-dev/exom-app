import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
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
      child: _DietsView(selectedDate: selectedDate),
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
          // The history is an independent read: it stays reachable under the
          // error, as the pinned history bar kept it before.
          return Column(
            children: [
              Expanded(
                child: ErrorWidget2(
                  message: state.apiException != null
                      ? localizedApiError(context, state.apiException!)
                      : l10n.errorServer,
                  onRetry: () => context.read<DietBloc>().add(
                    DietLoadRequested(date: selectedDate),
                  ),
                ),
              ),
              _DietIndex(date: null, selectedDate: selectedDate),
              const SizedBox(height: 8),
            ],
          );
        }
        if (state is DietNoContent) {
          return _DietsEmptyView(selectedDate: selectedDate);
        }
        if (state is DietLoaded) {
          return _DietContent(state: state, selectedDate: selectedDate);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Day without a plan (sketch «Nutrición · día sin plan»): title and date, the
/// two-line headline with the cause and the way out, and the history entry.
class _DietsEmptyView extends StatelessWidget {
  const _DietsEmptyView({required this.selectedDate});

  final String? selectedDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date =
        (selectedDate == null ? null : DateTime.tryParse(selectedDate!)) ??
        DateTime.now();
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeTitle(l10n.nutrition),
              const SizedBox(height: 12),
              HomeDateLine(date: date),
            ],
          ),
        ),
        ExomEmptyState(
          first: l10n.dietEmptyHeadlineFirst,
          second: l10n.dietEmptyHeadlineSecond,
          lead: selectedDate == null
              ? l10n.noDietTodayMessage
              : l10n.noDietForDateMessage,
          body: l10n.contactCoachForPlanMessage,
          action: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExomSecondaryButton(
              label: l10n.contactCoachButton,
              onPressed: () {},
            ),
          ),
        ),
        _DietIndex(date: null, selectedDate: selectedDate),
      ],
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
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            ShimmerCard(
              height: 64,
              width: 64,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            SizedBox(width: 12),
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
            SizedBox(width: 12),
            ShimmerCard(
              height: 48,
              width: 48,
              borderRadius: BorderRadius.all(Radius.circular(4)),
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
              return _DietIndex(
                date: DateTime.tryParse(state.selectedDate) ?? DateTime.now(),
                selectedDate: selectedDate,
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

/// Numbered index closing the screen (sketch «Nutrición», `.x-ixs`): «01» the
/// weekly shopping list of the week that contains [date] (the same flow as the
/// calendar export) and «02» the read-only diet history. Without [date] (no
/// plan, load error) only the history is offered. The wrapper keeps the
/// `diet-shopping-list-row` key of the former single row.
class _DietIndex extends StatefulWidget {
  const _DietIndex({required this.date, required this.selectedDate});

  final DateTime? date;
  final String? selectedDate;

  @override
  State<_DietIndex> createState() => _DietIndexState();
}

class _DietIndexState extends State<_DietIndex> {
  bool _busy = false;

  Future<void> _openShoppingList(DateTime date) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startWeeklyShoppingList(context, date);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = widget.date;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: KeyedSubtree(
        key: const Key('diet-shopping-list-row'),
        child: ExomIndexList(
          items: [
            if (date != null)
              ExomIndexItem(
                title: l10n.weeklyExportShoppingList,
                onTap: _busy ? null : () => _openShoppingList(date),
              ),
            ExomIndexItem(
              title: l10n.dietHistoryTitle,
              onTap: () => showDietHistory(
                context,
                load: () => sl<DietRepository>().getDietHistory(
                  date: widget.selectedDate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen head (sketch «Nutrición»): plan name as the Barlow title, date,
/// kcal · meals summary, the two-line headline, then what is left to eat as a
/// hero figure with a segmented progress rule and the macros in columns.
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
    final totalMeals = diet.meals.length;
    final figures = [
      if (remaining.proteinG != null)
        ExomFigure(
          label: l10n.proteinLabel,
          value: formatFigure(context, remaining.proteinG!),
          unit: 'g',
        ),
      if (remaining.carbsG != null)
        ExomFigure(
          label: l10n.carbsLabel,
          value: formatFigure(context, remaining.carbsG!),
          unit: 'g',
        ),
      if (remaining.fatG != null)
        ExomFigure(
          label: l10n.fatsLabel,
          value: formatFigure(context, remaining.fatG!),
          unit: 'g',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
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
              const SizedBox(height: 16),
              ExomTwoLineHeadline(
                first: l10n.dietHeadlineFirst,
                second: l10n.dietHeadlineSecond,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (remaining.calories != null) ...[
                ExomKicker(l10n.dietLeftKicker),
                const SizedBox(height: 12),
                ExomNumeral(
                  value: '${remaining.calories}',
                  unit: 'kcal',
                  size: ExomNumeralSize.hero96,
                  side: diet.totalCalories == null
                      ? null
                      : Text(
                          l10n.dietOfTotalKcal(diet.totalCalories!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.textSecondary,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
              ],
              if (totalMeals > 0) ...[
                ExomProgressRule(
                  value: completedCount / totalMeals,
                  segments: totalMeals,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                l10n.dietMealsProgress(completedCount, totalMeals),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (figures.isNotEmpty) ...[
          const SizedBox(height: 16),
          ExomFigureColumns(items: figures, numbered: false),
        ],
      ],
    );
  }
}

/// Meal row (sketch B `.mealx`): 64 dp photo on the left, text in the centre,
/// square 48 dp mark on the right; the photo and text open the meal detail.
/// The description is capped at two lines (the full text is in the detail and
/// in the semantics label). Completed = filled mark with a check and a
/// struck-through description (never colour alone); a queued change adds the
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
      if (meal.proteinG != null) 'P ${formatFigure(context, meal.proteinG!)} g',
      if (meal.carbsG != null) 'C ${formatFigure(context, meal.carbsG!)} g',
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MealThumb(
                        key: Key('meal-thumb-${meal.id}'),
                        imageUrl: imageUrl,
                        mealType: meal.type,
                        dimmed: isCompleted,
                      ),
                      const SizedBox(width: 12),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                            ] else if (isCompleted) ...[
                              const SizedBox(height: 4),
                              const _MealDoneStatus(),
                            ],
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final tag in tags) _MealTag(label: tag),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: _MealThumb.size,
              child: Center(
                child: _MealMark(
                  key: Key('meal-toggle-${meal.id}'),
                  isCompleted: isCompleted,
                  label: isCompleted
                      ? l10n.mealMarkUncompleteLabel(
                          _mealLabel(context, meal.type),
                        )
                      : l10n.mealMarkCompleteLabel(
                          _mealLabel(context, meal.type),
                        ),
                  onTap: () => onToggle(
                    !isCompleted,
                    isCompleted ? completedMealId ?? meal.id : meal.id,
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

/// «Hecha» line of a completed meal (sketch `.x-ok`): the client's own done is
/// data (D19), icon and text, so it never rests on colour alone. A queued
/// change shows its sync state instead.
class _MealDoneStatus extends StatelessWidget {
  const _MealDoneStatus();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(Icons.check, size: 18, color: palette.data),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AppLocalizations.of(context).mealDoneStatus,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.data,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// 64 dp thumbnail (sketch `.th64`): the meal photo, or a raised-surface box
/// with the linear icon of the meal type when there is no photo, while it
/// loads, or if it fails. A completed meal dims it to 45 %.
class _MealThumb extends StatelessWidget {
  const _MealThumb({
    super.key,
    required this.imageUrl,
    required this.mealType,
    required this.dimmed,
  });

  static const double size = 64;

  final String? imageUrl;
  final String mealType;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final fallback = _MealIconFallback(icon: _mealIcon(mealType));
    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: url == null || url.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  memCacheWidth: PerformanceProfile.imageCacheWidth(
                    context,
                    size,
                  ),
                  placeholder: (context, url) => fallback,
                  errorWidget: (context, url, error) => fallback,
                ),
        ),
      ),
    );
  }

  static IconData _mealIcon(String type) {
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
}

class _MealIconFallback extends StatelessWidget {
  const _MealIconFallback({required this.icon});

  final IconData icon;

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
          child: Icon(icon, size: 28, color: palette.textSecondary),
        ),
      ),
    );
  }
}

/// Square 48 dp mark (sketch `.e-mark`): empty outline, or a heavier outline
/// with a check in the data colour once the meal is done (D19: the client's
/// «hecha» is data), so the state reads from the shape and not the colour.
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
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCompleted ? palette.data : palette.textPrimary,
                width: isCompleted ? 2 : 1.5,
              ),
            ),
            child: isCompleted
                ? Icon(Icons.check, size: 26, color: palette.data)
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
