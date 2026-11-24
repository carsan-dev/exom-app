import 'dart:math' as math;

import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_step_transition.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_start_view.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_general.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_improvement.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_nutrition.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_recovery.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_training.dart';
import 'package:exom_app/injection_container.dart';

class RecapPage extends StatelessWidget {
  const RecapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RecapBloc>()..add(const RecapLoadRequested()),
      child: const _RecapView(),
    );
  }
}

class _RecapView extends StatefulWidget {
  const _RecapView();

  @override
  State<_RecapView> createState() => _RecapViewState();
}

class _RecapViewState extends State<_RecapView> {
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  /// The form was open since the list was last shown. Saving and sending go
  /// through `RecapLoading` before they fail, so the previous state alone
  /// cannot tell a failed save from a failed load of the list.
  bool _formOpen = false;

  /// Leaving the form towards the list: the reload that follows is a load of
  /// the list, so its failure is shown in line and not as a failed save.
  void _cancelForm(BuildContext context) {
    _formOpen = false;
    context.read<RecapBloc>().add(const RecapFormCancelled());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecapBloc, RecapState>(
      listener: (context, state) {
        final palette = context.exomPalette;
        final semantic = context.exomSemantic;
        final l10n = AppLocalizations.of(context);

        // D14-3: a failed load of the list is shown in line (the error view);
        // the SnackBar is only for a save or send that fails in the form.
        final errorFromForm = state is RecapError && _formOpen;
        if (state is RecapFormActive) {
          _formOpen = true;
        } else if (state is! RecapLoading) {
          _formOpen = false;
        }

        if (state is RecapSubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.recapSentSuccessfully,
                style: TextStyle(color: palette.background),
              ),
              backgroundColor: semantic.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ExomRadius.control),
              ),
            ),
          );
        }

        if (errorFromForm) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizedErrorTextOf(
                  context,
                  state.message,
                  fallback: (l10n) => l10n.recapSaveError,
                ),
                style: TextStyle(color: palette.background),
              ),
              backgroundColor: palette.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ExomRadius.control),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final formState = state is RecapFormActive ? state : null;
        final isFormActive = formState != null;
        final palette = context.exomPalette;
        final l10n = AppLocalizations.of(context);

        return ExomStaticBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            // Sketch C3: on the list the bar only carries «Volver» and the
            // reload action; the screen title is the first line of the body.
            appBar: AppBar(
              title: isFormActive
                  ? Text(
                      formState.step == 5
                          ? l10n.recapImprovementTitle
                          : formState.recapId == null
                          ? l10n.newRecap
                          : l10n.editRecap,
                    )
                  : null,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              leading: isFormActive
                  ? IconButton(
                      onPressed: () => _cancelForm(context),
                      tooltip: l10n.cancel,
                      icon: Icon(ExomIcons.close, color: palette.textPrimary),
                    )
                  : context.canPop()
                  ? IconButton(
                      onPressed: () => context.pop(),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: Icon(ExomIcons.back, color: palette.textPrimary),
                    )
                  : null,
              actions: isFormActive
                  ? null
                  : [
                      IconButton(
                        onPressed: () => context.read<RecapBloc>().add(
                          const RecapLoadRequested(),
                        ),
                        tooltip: l10n.retry,
                        icon: Icon(ExomIcons.retry, color: palette.textPrimary),
                      ),
                    ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildBody(context, state),
                  ),
                ),
                if (state is RecapListLoaded)
                  _buildFooter(context, state.recaps),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pinned action of the list (D14-1): «Nuevo recap», «Continuar borrador»
  /// (draft of this week) or «Crear mi primer recap» (empty list). With a recap
  /// already sent this week and no draft the action is blocked: no lime, and
  /// the reason in line above it instead of a SnackBar.
  Widget _buildFooter(BuildContext context, List<RecapEntity> recaps) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final currentWeekDraft = _findCurrentWeekDraft(recaps);
    final isBlocked =
        _hasSubmittedRecapThisWeek(recaps) && currentWeekDraft == null;
    final label = currentWeekDraft != null
        ? l10n.continueDraftRecap
        : recaps.isEmpty
        ? l10n.createMyFirstRecap
        : l10n.newRecap;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ExomPinnedFooter(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBlocked) ...[
            Text(
              l10n.recapAlreadySubmittedThisWeek,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 14,
                height: 1.4,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: ExomSpacing.sm),
          ],
          ExomPrimaryButton(
            key: const ValueKey('recap-new'),
            label: label,
            trailingIcon: ExomIcons.forward,
            onPressed: isBlocked
                ? null
                : () {
                    if (currentWeekDraft != null) {
                      _openDraftRecap(currentWeekDraft);
                      return;
                    }
                    context.read<RecapBloc>().add(const RecapCreateRequested());
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, RecapState state) {
    if (state is RecapLoading || state is RecapInitial) {
      return _RecapLoadingView(
        key: const ValueKey('recap-loading'),
        header: _buildListHeader(context),
      );
    }

    if (state is RecapFormActive) {
      return _RecapFormView(
        key: const ValueKey('recap-form'),
        state: state,
        onFieldChanged: (field, value) => context.read<RecapBloc>().add(
          RecapFieldUpdated(field: field, value: value),
        ),
        onStepChanged: (step) =>
            context.read<RecapBloc>().add(RecapStepChanged(step)),
        onSaveDraft: () =>
            context.read<RecapBloc>().add(const RecapSaveRequested()),
        onSubmit: () => context.read<RecapBloc>().add(
          RecapSubmitRequested(recapId: state.recapId),
        ),
        onCancel: () => _cancelForm(context),
        formatWeekRange: _formatWeekRange,
      );
    }

    if (state is RecapListLoaded) {
      return _RecapListView(
        key: const ValueKey('recap-list'),
        header: _buildListHeader(context),
        recaps: state.recaps,
        onRefresh: () async {
          context.read<RecapBloc>().add(const RecapLoadRequested());
        },
        onOpenRecap: (recap) async {
          if (!recap.isDraft) {
            await context.push(AppRoutes.recapDetail(recap.id));
            if (!context.mounted) return;

            context.read<RecapBloc>().add(const RecapLoadRequested());
            return;
          }

          context.read<RecapBloc>().add(
            RecapFormStarted(
              recapId: recap.id,
              initialData: _buildInitialData(recap),
            ),
          );
        },
        formatWeekRange: (recap) => _formatWeekRange(_buildInitialData(recap)),
      );
    }

    if (state is RecapError) {
      return _RecapErrorView(
        key: const ValueKey('recap-error'),
        header: _buildListHeader(context),
        message: localizedErrorTextOf(
          context,
          state.message,
          fallback: (l10n) => l10n.recapLoadError,
        ),
        onRetry: () =>
            context.read<RecapBloc>().add(const RecapLoadRequested()),
      );
    }

    return const SizedBox.shrink(key: ValueKey('recap-empty'));
  }

  /// Title and current week (sketch `.t1` + `.sec`), shared by every state of
  /// the list. The week comes from the screen clock ([HomeClock]).
  Widget _buildListHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final languageCode = Localizations.localeOf(context).languageCode;
    final today = _today(context);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final format = DateFormat.MMMMd(languageCode);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeTitle(l10n.weeklyRecapTitle),
          const SizedBox(height: ExomSpacing.sm),
          Text(
            l10n.recapListWeekSubtitle(
              format.format(weekStart),
              format.format(weekEnd),
            ),
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 15,
              height: 1.35,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _today(BuildContext context) => HomeClock.todayOf(context);

  RecapEntity? _findCurrentWeekDraft(List<RecapEntity> recaps) {
    for (final recap in recaps) {
      if (_isCurrentWeekRecap(recap) && recap.isDraft) {
        return recap;
      }
    }
    return null;
  }

  bool _hasSubmittedRecapThisWeek(List<RecapEntity> recaps) {
    for (final recap in recaps) {
      if (_isCurrentWeekRecap(recap) && !recap.isDraft) {
        return true;
      }
    }
    return false;
  }

  bool _isCurrentWeekRecap(RecapEntity recap) {
    final today = _today(context);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return _isSameDate(recap.weekStartDate, weekStart) &&
        _isSameDate(recap.weekEndDate, weekEnd);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _openDraftRecap(RecapEntity draft) {
    context.read<RecapBloc>().add(
      RecapFormStarted(
        recapId: draft.id,
        initialData: _buildInitialData(draft),
      ),
    );
  }

  Map<String, dynamic> _buildInitialData(RecapEntity recap) {
    return {
      'week_start_date': _apiDateFormat.format(recap.weekStartDate),
      'week_end_date': _apiDateFormat.format(recap.weekEndDate),
      'training_effort': recap.trainingEffort,
      'training_sessions': recap.trainingSessions,
      'average_daily_steps': recap.averageDailySteps,
      'training_progress': recap.trainingProgress,
      'training_notes': recap.trainingNotes,
      'nutrition_quality': recap.nutritionQuality,
      'hydration_enabled': recap.hydrationEnabled,
      'hydration_level': recap.hydrationLevel,
      'food_quality': recap.foodQuality,
      'nutrition_notes': recap.nutritionNotes,
      'sleep_hours_range': recap.sleepHoursRange,
      'fatigue_level': recap.fatigueLevel,
      'muscle_pain_zones': List<String>.from(recap.musclePainZones),
      'pain_intensity': recap.painIntensity,
      'recovery_notes': recap.recoveryNotes,
      'mood': recap.mood,
      'stress_enabled': recap.stressEnabled,
      'stress_level': recap.stressLevel,
      'hunger_level': recap.hungerLevel,
      'energy_level': recap.energyLevel,
      'digestion_level': recap.digestionLevel,
      'general_notes': recap.generalNotes,
      'improvement_app_rating': recap.improvementAppRating,
      'improvement_service_rating': recap.improvementServiceRating,
      'improvement_areas': List<String>.from(recap.improvementAreas),
      'improvement_feedback_text': recap.improvementFeedbackText,
    }..removeWhere((_, value) => value == null);
  }

  String _formatWeekRange(Map<String, dynamic> formData) {
    final l10n = AppLocalizations.of(context);
    final start = formData['week_start_date'] as String?;
    final end = formData['week_end_date'] as String?;
    if (start == null || end == null) {
      return l10n.weekWithoutDates;
    }

    final startDate = DateTime.tryParse(start);
    final endDate = DateTime.tryParse(end);
    if (startDate == null || endDate == null) {
      return l10n.weekWithoutDates;
    }

    final format = DateFormat(
      'dd MMM',
      Localizations.localeOf(context).languageCode,
    );
    return '${format.format(startDate)} - ${format.format(endDate)}';
  }
}

/// Loading: the header and skeleton rows with the shape of the final rows.
class _RecapLoadingView extends StatelessWidget {
  const _RecapLoadingView({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        header,
        const SizedBox(height: ExomSpacing.xxl),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              ExomSkeleton.row(),
              ExomSkeleton.row(),
              ExomSkeleton.row(),
              ExomSkeleton.row(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The list: header, the count of new trainer comments (or the headline alone)
/// and one row per week. Empty, the invitation of the trainer.
class _RecapListView extends StatelessWidget {
  final Widget header;
  final List<RecapEntity> recaps;
  final Future<void> Function() onRefresh;
  final Future<void> Function(RecapEntity recap) onOpenRecap;
  final String Function(RecapEntity recap) formatWeekRange;

  const _RecapListView({
    super.key,
    required this.header,
    required this.recaps,
    required this.onRefresh,
    required this.onOpenRecap,
    required this.formatWeekRange,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    if (recaps.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          header,
          const SizedBox(height: ExomSpacing.sm),
          ExomEmptyState(
            first: l10n.recapListEmptyHeadlineFirst,
            second: l10n.recapListEmptyHeadlineSecond,
            lead: l10n.youHaveNotSentAnyRecapYet,
            body: l10n.useThisSpaceToSummarizeYourWeek,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ExomCoachBlock(
              // D16: the model carries no trainer name.
              author: l10n.recapListCoachAuthor,
              text: l10n.recapListEmptyCoachText,
            ),
          ),
        ],
      );
    }

    final unread = recaps
        .where((recap) => recap.hasUnreadClientFeedback)
        .length;
    final trioNeeded = _RecapTrio.neededWidth(context, [
      for (final recap in recaps) _RecapWeekRow.trioItems(l10n, recap),
    ]);

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          header,
          const SizedBox(height: ExomSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: unread > 0
                ? _UnreadHero(
                    value: NumberFormat.decimalPattern(
                      l10n.localeName,
                    ).format(unread),
                    label: l10n.recapListNewCommentsCount(unread),
                  )
                : ExomTwoLineHeadline(
                    first: l10n.recapListHeadlineFirst,
                    second: l10n.recapListHeadlineSecond,
                  ),
          ),
          const SizedBox(height: ExomSpacing.xxl),
          ExomFlatRowGroup(
            children: [
              for (final recap in recaps)
                _RecapWeekRow(
                  key: ValueKey('recap-row-${recap.id}'),
                  recap: recap,
                  weekLabel: formatWeekRange(recap),
                  trioNeeded: trioNeeded,
                  onTap: () async {
                    await onOpenRecap(recap);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hero of the list with unread trainer comments: the headline first and, under
/// it, the numeral with its label stuck below, read together as one node
/// («1 comentario nuevo de tu entrenador»), so the headline never sits between
/// the figure and what it counts.
class _UnreadHero extends StatelessWidget {
  const _UnreadHero({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExomTwoLineHeadline(
          first: l10n.recapListHeadlineFirst,
          second: l10n.recapListHeadlineSecond,
        ),
        const SizedBox(height: ExomSpacing.md),
        Semantics(
          key: const ValueKey('recap-unread-hero'),
          container: true,
          label: '$value $label',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExomNumeral(value: value, size: ExomNumeralSize.hero96),
              const SizedBox(height: ExomSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 14,
                  height: 1.35,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One week (sketch `.x-row`): its range, its state, three values and a
/// chevron. A recap with a new trainer comment is a featured block with the
/// notice under the row (`.x-feat`).
class _RecapWeekRow extends StatelessWidget {
  final RecapEntity recap;
  final String weekLabel;
  final VoidCallback onTap;

  /// Widest word of the whole list, so every row shares its trio columns.
  final double trioNeeded;

  const _RecapWeekRow({
    super.key,
    required this.recap,
    required this.weekLabel,
    required this.onTap,
    required this.trioNeeded,
  });

  /// Label and raw value of the three cells of a week.
  static List<(String, String?)> trioItems(
    AppLocalizations l10n,
    RecapEntity recap,
  ) => [
    (l10n.recapTraining, recap.trainingProgress),
    (l10n.recapNutrition, recap.nutritionQuality),
    (l10n.mood, recap.mood),
  ];

  static const EdgeInsetsGeometry _padding = EdgeInsetsDirectional.fromSTEB(
    20,
    12,
    12,
    12,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final featured = recap.hasUnreadClientFeedback;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    weekLabel,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: palette.textPrimary,
                    ),
                  ),
                  _statusOf(context),
                ],
              ),
              const SizedBox(height: 6),
              _RecapTrio(items: trioItems(l10n, recap), needed: trioNeeded),
            ],
          ),
        ),
        Icon(ExomIcons.next, size: 22, color: palette.textSecondary),
      ],
    );

    final row = MergeSemantics(
      child: Semantics(
        button: true,
        child: featured
            ? _FeaturedRowSurface(
                onTap: onTap,
                padding: _padding,
                child: content,
              )
            : ExomRowSurface(
                onTap: onTap,
                minHeight: 72,
                padding: _padding,
                child: content,
              ),
      ),
    );

    if (!featured) return row;
    // The bar belongs to its row: 16 dp of air above it (plus the 12 dp of the
    // row before) and none between it and the row's own padding (12 dp).
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ExomFeatureBlock(
        topPadding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: ExcludeSemantics(
                      child: Icon(
                        ExomIcons.notifications,
                        size: MediaQuery.textScalerOf(context).scale(18),
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.recapNewCoachComment,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// D19: the list comes from the server, so a sent («Enviado») and a reviewed
  /// recap are both confirmed (text colour with a check, never the «sending»
  /// cloud, which means «uploading now»); a draft is pending (clock).
  Widget _statusOf(BuildContext context) {
    final state = switch (recap.status) {
      'REVIEWED' || 'SUBMITTED' => ExomSyncState.confirmada,
      _ => ExomSyncState.pendiente,
    };
    return ExomSyncStatus(
      state: state,
      label: recapCopy(context, recap.status),
    );
  }
}

/// Row surface of a featured recap: like [ExomRowSurface] without the top
/// hairline, which the bar of the featured block replaces.
class _FeaturedRowSurface extends StatelessWidget {
  const _FeaturedRowSurface({
    required this.child,
    required this.onTap,
    required this.padding,
  });

  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: palette.surfaceElevated,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The three values of a week (`.c-trio`): label and value per cell, in as many
/// columns as the width allows for the widest word of the whole list (measured
/// once, with the real styles and the text scaler), so every row of the list
/// shares its columns and no word is ever split.
class _RecapTrio extends StatelessWidget {
  const _RecapTrio({required this.items, required this.needed});

  /// Label and raw value; a null or blank value is «Sin valorar».
  final List<(String, String?)> items;

  /// Width of the longest word of every visible row, from [neededWidth].
  final double needed;

  static const double _gap = 12;

  static TextStyle _labelStyle(ExomThemePalette palette) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 13,
    height: 1.3,
    color: palette.textSecondary,
  );

  static TextStyle _notRatedStyle(ExomThemePalette palette) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 15,
    height: 1.35,
    color: palette.textSecondary,
  );

  static TextStyle _valueStyle(ExomThemePalette palette) => TextStyle(
    fontFamily: AppTheme.displayFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -0.24,
    color: palette.textPrimary,
  );

  static List<(String, String?)> _shown(
    BuildContext context,
    List<(String, String?)> items,
  ) => [
    for (final (label, value) in items)
      (
        label,
        (value == null || value.trim().isEmpty)
            ? null
            : recapCopy(context, value).toUpperCase(),
      ),
  ];

  /// Width of the longest word among the cells of all [rows].
  static double neededWidth(
    BuildContext context,
    Iterable<List<(String, String?)>> rows,
  ) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final labelStyle = _labelStyle(palette);
    final notRatedStyle = _notRatedStyle(palette);
    final valueStyle = _valueStyle(palette);

    // Words split on plain whitespace only: a no-break space keeps its words.
    double longestWord(String text, TextStyle style) {
      var longest = 0.0;
      for (final word in text.split(RegExp(r'[ \t\n]+'))) {
        if (word.isEmpty) continue;
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        longest = math.max(longest, painter.width);
        painter.dispose();
      }
      return longest;
    }

    var needed = 0.0;
    for (final row in rows) {
      for (final (label, value) in _shown(context, row)) {
        needed = math.max(needed, longestWord(label, labelStyle));
        needed = math.max(
          needed,
          value == null
              ? longestWord(l10n.recapListNotRated, notRatedStyle)
              : longestWord(value, valueStyle),
        );
      }
    }
    return needed;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final labelStyle = _labelStyle(palette);
    final notRatedStyle = _notRatedStyle(palette);
    final valueStyle = _valueStyle(palette);
    final shown = _shown(context, items);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Columns are as many as every word fits in whole; never a split word.
        var columns = items.length;
        while (columns > 1 &&
            (width - _gap * (columns - 1)) / columns < needed + 1) {
          columns--;
        }
        final cell = (width - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: ExomSpacing.sm,
          children: [
            for (final (label, value) in shown)
              SizedBox(
                width: cell,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: labelStyle),
                    if (value == null)
                      Text(l10n.recapListNotRated, style: notRatedStyle)
                    else
                      Text(value, style: valueStyle),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Load error in line (sketch C3 «Error»): headline with the second line in the
/// error colour, the cause and «Reintentar».
class _RecapErrorView extends StatelessWidget {
  const _RecapErrorView({
    super.key,
    required this.header,
    required this.message,
    required this.onRetry,
  });

  final Widget header;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        header,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExomTwoLineHeadline(
                first: l10n.recapListErrorHeadlineFirst,
                second: l10n.recapListErrorHeadlineSecond,
                isError: true,
              ),
              const SizedBox(height: 14),
              ExomInlineMessage(
                kind: ExomMessageKind.error,
                title: l10n.couldNotLoadRecap,
                body: message,
              ),
              const SizedBox(height: 14),
              ExomSecondaryButton(
                key: const ValueKey('recap-retry'),
                label: l10n.retry,
                icon: ExomIcons.retry,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The step form (L5-C5a, sketch «C4 · Recap, formulario por pasos»): the start
/// view and the five steps inside an [ExomStepTransition] (M9), with the
/// action of the step pinned below. A failed save or send still shows its own
/// SnackBar (it is not a validation); an invalid value is explained under its
/// field and in a line above the buttons.
class _RecapFormView extends StatelessWidget {
  final RecapFormActive state;
  final void Function(String field, dynamic value) onFieldChanged;
  final ValueChanged<int> onStepChanged;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String Function(Map<String, dynamic> formData) formatWeekRange;

  const _RecapFormView({
    super.key,
    required this.state,
    required this.onFieldChanged,
    required this.onStepChanged,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onCancel,
    required this.formatWeekRange,
  });

  static const int _stepStart = 0;
  static const int _stepImprovement = 5;

  bool get _isStartStep => state.step == _stepStart;
  bool get _isImprovementStep => state.step == _stepImprovement;
  bool get _hasValidationErrors =>
      !isValidRecapAverageDailySteps(state.formData['average_daily_steps']);

  Widget _stepBody() {
    switch (state.step) {
      case 1:
        return RecapStepTraining(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      case 2:
        return RecapStepNutrition(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      case 3:
        return RecapStepRecovery(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      case 4:
        return RecapStepGeneral(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      case 5:
        return RecapStepImprovement(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      default:
        return RecapStartView(
          formData: state.formData,
          weekLabel: formatWeekRange(state.formData),
          onStart: () => onStepChanged(1),
          onReviewAndSend: () => onStepChanged(5),
          onCancel: onCancel,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Expanded(
          child: RecapWeekScope(
            label: formatWeekRange(state.formData),
            child: ExomStepTransition(step: state.step, child: _stepBody()),
          ),
        ),
        if (!_isStartStep)
          ExomPinnedFooter(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasValidationErrors) ...[
                  ExomInlineMessage(
                    kind: ExomMessageKind.error,
                    title: l10n.correctInvalidRecapFields,
                  ),
                  const SizedBox(height: ExomSpacing.md),
                ],
                ExomPrimaryButton(
                  key: const ValueKey('recap-step-action'),
                  label: _isImprovementStep
                      ? l10n.sendRecap
                      : l10n.recapNextStep,
                  trailingIcon: _isImprovementStep
                      ? ExomIcons.send
                      : ExomIcons.forward,
                  onPressed: _isImprovementStep
                      ? (_hasValidationErrors ? null : onSubmit)
                      : () => onStepChanged(state.step + 1),
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ExomQuietButton(
                      label: l10n.previous,
                      onPressed: () => onStepChanged(state.step - 1),
                    ),
                    ExomQuietButton(
                      label: l10n.recapSaveDraft,
                      onPressed: _hasValidationErrors ? null : onSaveDraft,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
