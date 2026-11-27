import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
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
import 'package:exom_app/core/widgets/exom_large_text.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart' show kExomSheetRadius;
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/services/ingredient_unit_formatter.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/injection_container.dart';

/// Opens the meal sheet. [preview] (the meal as the caller already has it) or,
/// failing that, [previewName] let the loading skeleton reproduce the header
/// of the loaded sheet, so with large text it opens at its final size (OBS-1).
Future<void> showMealDetailSheet(
  BuildContext context, {
  required String mealId,
  String? selectedDate,
  MealEntity? preview,
  String? previewName,
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
        child: _MealSheetHost(
          mealId: mealId,
          selectedDate: selectedDate,
          preview: preview,
          previewName: previewName,
        ),
      );
    },
  );
  onDismissed?.call();
}

/// Draggable container of the meal sheet: opens at 70 %. With large text it
/// opens tall enough to show the name, calories and macros above the pinned
/// foot, both measured, up to its maximum (L5-D63).
///
/// OBS-1: the size is settled once, from the loading skeleton, which repeats
/// the geometry of the loaded header; that happens on the first frame, while
/// the sheet is still below the screen. If the loaded header still needs more
/// room (the skeleton could not know it), the sheet grows once, animated, and
/// only if the user has not dragged it. Nothing resizes it afterwards, so
/// picking an option never moves it.
class _MealSheetHost extends StatefulWidget {
  const _MealSheetHost({
    required this.mealId,
    required this.selectedDate,
    required this.preview,
    required this.previewName,
  });

  final String mealId;
  final String? selectedDate;
  final MealEntity? preview;
  final String? previewName;

  @override
  State<_MealSheetHost> createState() => _MealSheetHostState();
}

class _MealSheetHostState extends State<_MealSheetHost> {
  static const double _initialFraction = 0.7;
  static const double _minFraction = 0.4;
  static const double _maxFraction = 0.95;
  static const Duration _growDuration = Duration(milliseconds: 200);

  final DraggableScrollableController _controller =
      DraggableScrollableController();

  double _available = 0;
  double? _lastScale;

  /// The screen or the text scale changed with the sheet open: its size is
  /// settled again once the new measurements arrive.
  bool _environmentChanged = false;

  /// Initial size, settled once from the skeleton measurement.
  double? _settledSize;
  double _skeletonFoot = 0;
  double _skeletonLead = 0;

  double _contentFoot = 0;
  double _contentLead = 0;
  bool _contentReconcileScheduled = false;

  bool _userDragged = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _sizeFor(double leadBottom, double footHeight) => exomSheetInitialSize(
    context,
    initialSize: _initialFraction,
    maxSize: _maxFraction,
    available: _available,
    leadBottom: leadBottom,
    footHeight: footHeight,
  );

  void _onSkeletonFoot(double height) {
    _skeletonFoot = height;
    _settleFromSkeleton();
    _scheduleEnvironmentReconcile();
  }

  void _onSkeletonLead(double bottom) {
    _skeletonLead = bottom;
    _settleFromSkeleton();
    _scheduleEnvironmentReconcile();
  }

  void _scheduleEnvironmentReconcile() {
    if (_environmentChanged) _scheduleContentReconcile();
  }

  void _settleFromSkeleton() {
    if (!mounted || _settledSize != null) return;
    if (_skeletonFoot <= 0 || _skeletonLead <= 0 || _available <= 0) return;
    setState(() => _settledSize = _sizeFor(_skeletonLead, _skeletonFoot));
  }

  void _onContentFoot(double height) {
    _contentFoot = height;
    _scheduleContentReconcile();
  }

  void _onContentLead(double bottom) {
    _contentLead = bottom;
    _scheduleContentReconcile();
  }

  // The foot and the header report in the same post-frame pass; reconcile
  // once both are in.
  void _scheduleContentReconcile() {
    if (_contentReconcileScheduled) return;
    _contentReconcileScheduled = true;
    Future.microtask(_reconcileWithContent);
  }

  void _reconcileWithContent() {
    if (!mounted || _userDragged || !_controller.isAttached) return;
    // The loaded header measures the sheet; until then, the skeleton does.
    final loaded = _contentFoot > 0 && _contentLead > 0;
    final foot = loaded ? _contentFoot : _skeletonFoot;
    final lead = loaded ? _contentLead : _skeletonLead;
    final resettle = _environmentChanged;
    final needsMeasure = !resettle || exomIsLargeText(context);
    if (needsMeasure && (foot <= 0 || lead <= 0)) {
      // Not measured yet: let the next report try again.
      if (resettle) _contentReconcileScheduled = false;
      return;
    }
    // From here on only another change of screen or text scale resizes it.
    _environmentChanged = false;
    _contentReconcileScheduled = true;
    final target = _sizeFor(lead, foot);
    final current = _controller.size;
    if (_available <= 0) return;
    final difference = (target - current) * _available;
    // Normally it only grows, and only when it reveals at least a pixel more;
    // after a change of screen or text scale it goes to the new size.
    if (resettle ? difference.abs() < 1 : difference < 1) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(
        target,
        duration: _growDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _onScrollStart(ScrollStartNotification notification) {
    if (notification.dragDetails != null) _userDragged = true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final changed =
            _lastScale != null &&
            (_available != constraints.maxHeight || _lastScale != scale);
        _available = constraints.maxHeight;
        _lastScale = scale;
        if (changed && !_userDragged) {
          _environmentChanged = true;
          _contentReconcileScheduled = false;
          // At the plain size nothing reports; settle it after this frame.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scheduleContentReconcile(),
          );
        }
        return DraggableScrollableSheet(
          expand: false,
          controller: _controller,
          // Never changed after opening, or the sheet would reset to it; later
          // adjustments go through the controller.
          initialChildSize: _settledSize ?? _initialFraction,
          minChildSize: _minFraction,
          maxChildSize: _maxFraction,
          builder: (_, scrollController) =>
              NotificationListener<ScrollStartNotification>(
                onNotification: _onScrollStart,
                child: MealDetailSheet(
                  mealId: widget.mealId,
                  selectedDate: widget.selectedDate,
                  scrollController: scrollController,
                  preview: widget.preview,
                  previewName: widget.previewName,
                  onLeadBottom: _onContentLead,
                  onFootHeight: _onContentFoot,
                  onLoadingLeadBottom: _onSkeletonLead,
                  onLoadingFootHeight: _onSkeletonFoot,
                ),
              ),
        );
      },
    );
  }
}

class MealDetailSheet extends StatelessWidget {
  const MealDetailSheet({
    super.key,
    required this.mealId,
    required this.scrollController,
    this.selectedDate,
    this.preview,
    this.previewName,
    this.onLeadBottom,
    this.onFootHeight,
    this.onLoadingLeadBottom,
    this.onLoadingFootHeight,
  });

  final String mealId;
  final String? selectedDate;
  final ScrollController scrollController;

  /// The meal as the caller has it, or only its name: the loading skeleton
  /// uses them to repeat the geometry of the loaded header (OBS-1).
  final MealEntity? preview;
  final String? previewName;

  /// Where the name, calories and macros block ends in the content (L5-D63).
  final ValueChanged<double>? onLeadBottom;

  /// Height of the pinned foot (L5-D63).
  final ValueChanged<double>? onFootHeight;

  /// The same two measurements, taken on the loading skeleton (OBS-1).
  final ValueChanged<double>? onLoadingLeadBottom;
  final ValueChanged<double>? onLoadingFootHeight;

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
        preview: preview,
        previewName: previewName,
        onLeadBottom: onLeadBottom,
        onFootHeight: onFootHeight,
        onLoadingLeadBottom: onLoadingLeadBottom,
        onLoadingFootHeight: onLoadingFootHeight,
      ),
    );
  }
}

class _MealDetailSheetContent extends StatelessWidget {
  const _MealDetailSheetContent({
    required this.mealId,
    required this.selectedDate,
    required this.scrollController,
    required this.preview,
    required this.previewName,
    required this.onLeadBottom,
    required this.onFootHeight,
    required this.onLoadingLeadBottom,
    required this.onLoadingFootHeight,
  });

  final String mealId;
  final String? selectedDate;
  final ScrollController scrollController;
  final MealEntity? preview;
  final String? previewName;
  final ValueChanged<double>? onLeadBottom;
  final ValueChanged<double>? onFootHeight;
  final ValueChanged<double>? onLoadingLeadBottom;
  final ValueChanged<double>? onLoadingFootHeight;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DietBloc, DietState>(
      builder: (context, state) {
        if (state is DietLoading || state is DietInitial) {
          return _MealDetailLoading(
            scrollController: scrollController,
            preview: preview,
            previewName: previewName,
            onLeadBottom: onLoadingLeadBottom,
            onFootHeight: onLoadingFootHeight,
          );
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
            onLeadBottom: onLeadBottom,
            onFootHeight: onFootHeight,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

const BorderRadius _skeletonRadius = BorderRadius.all(Radius.circular(4));

/// Loading skeleton. Its header and foot are the loaded ones, laid out but
/// hidden under shimmer, so they measure the same and the sheet can settle
/// its size before the meal arrives (OBS-1). It uses the meal the caller
/// already has, or its name; whatever is unknown takes one line, calories
/// and three macros, the usual case.
class _MealDetailLoading extends StatelessWidget {
  const _MealDetailLoading({
    required this.scrollController,
    required this.preview,
    required this.previewName,
    required this.onLeadBottom,
    required this.onFootHeight,
  });

  final ScrollController scrollController;
  final MealEntity? preview;
  final String? previewName;
  final ValueChanged<double>? onLeadBottom;
  final ValueChanged<double>? onFootHeight;

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    final standIn =
        preview ??
        MealEntity(
          id: '',
          type: 'LUNCH',
          name: previewName ?? 'M',
          calories: 0,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          nutritionalBadges: const [],
          ingredients: const [],
          variants: const [],
        );
    final onFootHeight = this.onFootHeight;
    const foot = _MealSheetFoot(completed: false, masked: true);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _MealHead(
                meal: standIn,
                optionsCount: 1 + (preview?.variants.length ?? 0),
                onLeadBottom: onLeadBottom,
                masked: true,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: ShimmerCard(height: 64, borderRadius: _skeletonRadius),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: ShimmerCard(height: 120, borderRadius: _skeletonRadius),
              ),
            ],
          ),
        ),
        onFootHeight == null
            ? foot
            : ExomHeightReporter(onHeight: onFootHeight, child: foot),
      ],
    );
  }
}

/// Lays out [child] without showing it and covers its box with shimmer, so a
/// skeleton part takes exactly the room of the real one.
class _SkeletonMask extends StatelessWidget {
  const _SkeletonMask({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Visibility(
          visible: false,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: child,
        ),
        const Positioned.fill(
          child: ShimmerCard(height: 0, borderRadius: _skeletonRadius),
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
    this.onLeadBottom,
    this.onFootHeight,
  });

  final MealEntity meal;
  final bool isCompleted;
  final ScrollController scrollController;
  final ValueChanged<double>? onLeadBottom;
  final ValueChanged<double>? onFootHeight;

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

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final dietState = context.watch<DietBloc>().state;
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

    final onFootHeight = widget.onFootHeight;
    Widget measuredFoot(Widget foot) => onFootHeight == null
        ? foot
        : ExomHeightReporter(onHeight: onFootHeight, child: foot);

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
              _MealHead(
                meal: _selectedMeal,
                optionsCount: mealOptions.length,
                heroTag: 'meal-${widget.meal.id}-title',
                onLeadBottom: widget.onLeadBottom,
              ),
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
        measuredFoot(
          _MealSheetFoot(
            completed: resolvedCompleted,
            onToggle: toggleCompleted,
            onRecipe: () => _launchRecipe(context),
          ),
        ),
      ],
    );
  }
}

/// Up to two decimals, with the separator of the app locale; no thousands
/// grouping (L5-D33).
String _formatNumber(BuildContext context, double value) =>
    NumberFormat('0.##', AppLocalizations.of(context).localeName).format(value);

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

List<ExomFigure> _macroFigures(BuildContext context, MealEntity meal) {
  final l10n = AppLocalizations.of(context);
  return [
    if (meal.proteinG != null)
      ExomFigure(
        label: l10n.proteinLabel,
        value: _formatNumber(context, meal.proteinG!),
        unit: 'g',
      ),
    if (meal.carbsG != null)
      ExomFigure(
        label: l10n.carbsLabel,
        value: _formatNumber(context, meal.carbsG!),
        unit: 'g',
      ),
    if (meal.fatG != null)
      ExomFigure(
        label: l10n.fatsLabel,
        value: _formatNumber(context, meal.fatG!),
        unit: 'g',
      ),
  ];
}

/// Top bar, photo, name, calories and macros of the sheet: the lead block of
/// L5-D63, one list child so the lazy list always lays it out and it can be
/// measured however tall it gets. The loading skeleton builds the same block
/// [masked], so both measure the same (OBS-1).
class _MealHead extends StatelessWidget {
  const _MealHead({
    required this.meal,
    required this.optionsCount,
    required this.onLeadBottom,
    this.heroTag,
    this.masked = false,
  });

  final MealEntity meal;
  final int optionsCount;
  final ValueChanged<double>? onLeadBottom;
  final String? heroTag;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final figures = _macroFigures(context, meal);
    final calories = meal.calories;

    Widget mask(Widget child) => masked ? _SkeletonMask(child: child) : child;

    // The last part of the block reports where it ends (L5-D63); without a
    // listener nothing is wrapped.
    final onLeadBottom = this.onLeadBottom;
    Widget lead(Widget child, {required bool isLast}) =>
        isLast && onLeadBottom != null
        ? ExomScrollContentBottomReporter(onBottom: onLeadBottom, child: child)
        : child;

    final titleText = Text(
      meal.name,
      style: ExomType.section.copyWith(
        color: palette.textPrimary,
        fontSize: 30,
        height: 1.05,
      ),
    );
    final heroTag = this.heroTag;
    final title = heroTag == null
        ? titleText
        : Hero(
            tag: heroTag,
            flightShuttleBuilder: (flightCtx, anim, dir, fromCtx, toCtx) {
              return Material(
                color: Colors.transparent,
                child: Text(
                  meal.name,
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
            child: Material(color: Colors.transparent, child: titleText),
          );

    // Stretched, each part gets the full width, as when they were separate
    // list children.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetTopBar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: masked
              ? const ShimmerCard(height: 168, borderRadius: _skeletonRadius)
              : _MealPhoto(meal: meal),
        ),
        lead(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                mask(ExomKicker(_mealTypeLabel(l10n, meal.type))),
                const SizedBox(height: 8),
                mask(title),
              ],
            ),
          ),
          isLast: calories == null && figures.isEmpty,
        ),
        if (calories != null)
          lead(
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: mask(
                ExomNumeral(
                  value: '$calories',
                  unit: 'kcal',
                  size: ExomNumeralSize.hero96,
                  side: optionsCount > 1
                      ? Text(
                          l10n.optionsCount(optionsCount),
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
            ),
            isLast: figures.isEmpty,
          ),
        if (figures.isNotEmpty) ...[
          const SizedBox(height: 16),
          lead(
            mask(ExomFigureColumns(items: figures, numbered: false)),
            isLast: true,
          ),
        ],
      ],
    );
  }
}

/// Pinned foot: «Completar» (or «Completada») and «Receta». [masked], it is
/// the skeleton foot: same room, shimmer instead of the buttons (OBS-1).
class _MealSheetFoot extends StatelessWidget {
  const _MealSheetFoot({
    required this.completed,
    this.onToggle,
    this.onRecipe,
    this.masked = false,
  });

  final bool completed;
  final VoidCallback? onToggle;
  final VoidCallback? onRecipe;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    Widget mask(Widget child) => masked ? _SkeletonMask(child: child) : child;
    void noop() {}

    return DecoratedBox(
      key: masked ? null : const Key('meal-detail-foot'),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.borderSoft, width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 8 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            mask(
              completed
                  ? ExomSecondaryButton(
                      label: l10n.mealCompletedButton,
                      icon: ExomIcons.check,
                      onPressed: onToggle ?? noop,
                    )
                  : ExomPrimaryButton(
                      label: l10n.completeButton,
                      trailingIcon: ExomIcons.check,
                      onPressed: onToggle ?? noop,
                    ),
            ),
            const SizedBox(height: 4),
            Center(
              child: mask(
                ExomQuietButton(
                  label: l10n.recipeButton,
                  onPressed: onRecipe ?? noop,
                ),
              ),
            ),
          ],
        ),
      ),
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
              icon: Icon(ExomIcons.close, color: palette.textPrimary, size: 22),
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
            ExomIcons.diet,
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
