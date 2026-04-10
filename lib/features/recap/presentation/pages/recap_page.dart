import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:exom_app/core/services/feature_gate_service.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/premium_locked_overlay.dart';
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
  final PageController _pageController = PageController();
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecapBloc, RecapState>(
      listener: (context, state) {
        final palette = context.exomPalette;
        final semantic = context.exomSemantic;
        final l10n = AppLocalizations.of(context);
        if (state is RecapFormActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_pageController.hasClients) return;
            _pageController.animateToPage(
              state.step,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
            );
          });
        }

        if (state is RecapSubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.recapSentSuccessfully),
              backgroundColor: semantic.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }

        if (state is RecapError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: palette.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final formState = state is RecapFormActive ? state : null;
        final isFormActive = formState != null;
        final theme = Theme.of(context);
        final palette = context.exomPalette;
        final l10n = AppLocalizations.of(context);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              isFormActive
                  ? formState.step == 5
                        ? l10n.recapImprovementTitle
                        : formState.recapId == null
                        ? l10n.newRecap
                        : l10n.editRecap
                  : l10n.weeklyRecapTitle,
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: isFormActive
                ? IconButton(
                    onPressed: () => context.read<RecapBloc>().add(
                      const RecapFormCancelled(),
                    ),
                    icon: const Icon(Icons.close),
                  )
                : context.canPop()
                ? IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            actions: isFormActive
                ? null
                : [
                    IconButton(
                      onPressed: () => context.read<RecapBloc>().add(
                        const RecapLoadRequested(),
                      ),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
          ),
          floatingActionButton:
              state is RecapListLoaded &&
                  GetIt.I<FeatureGateService>().canSeeRecapHistory
              ? FloatingActionButton.extended(
                  onPressed: () => context.read<RecapBloc>().add(
                    const RecapCreateRequested(),
                  ),
                  backgroundColor: palette.primary,
                  foregroundColor: palette.onPrimary,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newRecap),
                )
              : null,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildBody(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, RecapState state) {
    final l10n = AppLocalizations.of(context);
    final gate = GetIt.I<FeatureGateService>();
    final stepTitles = [
      l10n.recapTraining,
      l10n.recapNutrition,
      l10n.recapRecovery,
      l10n.recapGeneral,
    ];

    if (state is RecapLoading || state is RecapInitial) {
      return Center(
        key: ValueKey('recap-loading'),
        child: CircularProgressIndicator(color: context.exomPalette.primary),
      );
    }

    if (state is RecapFormActive) {
      if (!gate.canUseDetailedRecap) {
        return _SimplifiedRecapForm(
          key: const ValueKey('recap-form-simple'),
          state: state,
          onFieldChanged: (field, value) => context.read<RecapBloc>().add(
            RecapFieldUpdated(field: field, value: value),
          ),
          onSaveDraft: () =>
              context.read<RecapBloc>().add(const RecapSaveRequested()),
          onSubmit: () => context.read<RecapBloc>().add(
            RecapSubmitRequested(recapId: state.recapId),
          ),
          onCancel: () =>
              context.read<RecapBloc>().add(const RecapFormCancelled()),
          formatWeekRange: _formatWeekRange,
        );
      }
      return _RecapFormView(
        key: const ValueKey('recap-form'),
        pageController: _pageController,
        stepTitles: stepTitles,
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
        onCancel: () =>
            context.read<RecapBloc>().add(const RecapFormCancelled()),
        formatWeekRange: _formatWeekRange,
      );
    }

    // LOW_TICKET: history is blocked — show landing with create button
    if (!gate.canSeeRecapHistory) {
      return _RecapLowTicketLanding(
        key: const ValueKey('recap-low-ticket'),
        onCreate: () =>
            context.read<RecapBloc>().add(const RecapCreateRequested()),
      );
    }

    if (state is RecapListLoaded) {
      return _RecapListView(
        key: const ValueKey('recap-list'),
        recaps: state.recaps,
        onRefresh: () async {
          context.read<RecapBloc>().add(const RecapLoadRequested());
        },
        onCreate: () =>
            context.read<RecapBloc>().add(const RecapCreateRequested()),
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
      final palette = context.exomPalette;
      return Center(
        key: const ValueKey('recap-error'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: palette.error, size: 42),
              const SizedBox(height: 16),
              Text(
                l10n.couldNotLoadRecap,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    context.read<RecapBloc>().add(const RecapLoadRequested()),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink(key: ValueKey('recap-empty'));
  }

  Map<String, dynamic> _buildInitialData(RecapEntity recap) {
    return {
      'week_start_date': _apiDateFormat.format(recap.weekStartDate),
      'week_end_date': _apiDateFormat.format(recap.weekEndDate),
      'training_effort': recap.trainingEffort,
      'training_sessions': recap.trainingSessions,
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

class _RecapListView extends StatelessWidget {
  final List<RecapEntity> recaps;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;
  final Future<void> Function(RecapEntity recap) onOpenRecap;
  final String Function(RecapEntity recap) formatWeekRange;

  const _RecapListView({
    super.key,
    required this.recaps,
    required this.onRefresh,
    required this.onCreate,
    required this.onOpenRecap,
    required this.formatWeekRange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    if (recaps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.edit_calendar_outlined,
                  color: palette.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.youHaveNotSentAnyRecapYet,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.useThisSpaceToSummarizeYourWeek,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(l10n.createMyFirstRecap),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.yourWeeklyHistory,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  l10n.trackYourWeeksReviewPreviousRecaps,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          ...recaps.map(
            (recap) => _RecapHistoryCard(
              recap: recap,
              weekLabel: formatWeekRange(recap),
              onPressed: () async {
                await onOpenRecap(recap);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapHistoryCard extends StatelessWidget {
  final RecapEntity recap;
  final String weekLabel;
  final VoidCallback onPressed;

  const _RecapHistoryCard({
    required this.recap,
    required this.weekLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final trainingProgress = recap.trainingProgress;
    final nutritionQuality = recap.nutritionQuality;
    final mood = recap.mood;
    final actionLabel = recap.isDraft ? l10n.continueButton : l10n.viewSummary;
    final hasUnread = recap.hasUnreadClientFeedback;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasUnread
            ? palette.primary.withValues(alpha: 0.06)
            : palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasUnread
              ? palette.primary.withValues(alpha: 0.35)
              : palette.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.created} ${DateFormat('dd/MM/yyyy').format(recap.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textDisabled,
                        fontSize: 12,
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.mark_chat_unread_outlined,
                            size: 13,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Nuevo comentario de tu entrenador',
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _StatusChip(status: recap.status),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.fitness_center,
                label: trainingProgress != null
                    ? formatRecapOption(trainingProgress)
                    : l10n.trainingNotRated,
              ),
              _InfoPill(
                icon: Icons.restaurant,
                label: nutritionQuality != null
                    ? formatRecapOption(nutritionQuality)
                    : l10n.nutritionNotRated,
              ),
              _InfoPill(
                icon: Icons.mood,
                label: mood != null
                    ? formatRecapOption(mood)
                    : l10n.moodNotRated,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapFormView extends StatelessWidget {
  final PageController pageController;
  final List<String> stepTitles;
  final RecapFormActive state;
  final void Function(String field, dynamic value) onFieldChanged;
  final ValueChanged<int> onStepChanged;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String Function(Map<String, dynamic> formData) formatWeekRange;

  const _RecapFormView({
    super.key,
    required this.pageController,
    required this.stepTitles,
    required this.state,
    required this.onFieldChanged,
    required this.onStepChanged,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onCancel,
    required this.formatWeekRange,
  });

  // step 0 = start view, steps 1-4 = core form, step 5 = improvement
  static const int _stepStart = 0;
  static const int _stepImprovement = 5;

  bool get _isStartStep => state.step == _stepStart;
  bool get _isImprovementStep => state.step == _stepImprovement;
  bool get _isCoreStep => state.step >= 1 && state.step <= 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Header with badges — only for core steps 1-4
        if (_isCoreStep) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatWeekRange(state.formData),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.completeTheFourBlocksAndSendYourWeeklySummary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: List.generate(stepTitles.length, (index) {
                    // state.step 1-4 maps to badge index 0-3
                    final badgeStep = state.step - 1;
                    final isActive = index == badgeStep;
                    final isCompleted = index < badgeStep;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == stepTitles.length - 1 ? 0 : 8,
                        ),
                        child: _StepBadge(
                          label: stepTitles[index],
                          index: index + 1,
                          isActive: isActive,
                          isCompleted: isCompleted,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Page content
        Expanded(
          child: PageView(
            controller: pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // step 0: start view
              RecapStartView(
                formData: state.formData,
                weekLabel: formatWeekRange(state.formData),
                onStart: () => onStepChanged(1),
                onReviewAndSend: () => onStepChanged(5),
                onCancel: onCancel,
              ),
              // steps 1-4: core form
              RecapStepTraining(
                formData: state.formData,
                onChanged: onFieldChanged,
              ),
              RecapStepNutrition(
                formData: state.formData,
                onChanged: onFieldChanged,
              ),
              RecapStepRecovery(
                formData: state.formData,
                onChanged: onFieldChanged,
              ),
              RecapStepGeneral(
                formData: state.formData,
                onChanged: onFieldChanged,
              ),
              // step 5: improvement
              RecapStepImprovement(
                formData: state.formData,
                onChanged: onFieldChanged,
              ),
            ],
          ),
        ),
        // Bottom navigation — hidden on start view (it has its own buttons)
        if (!_isStartStep)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: palette.divider)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => onStepChanged(state.step - 1),
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          state.step == 1 ? l10n.cancel : l10n.previous,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: onSaveDraft,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(l10n.save),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isImprovementStep
                          ? onSubmit
                          : () => onStepChanged(state.step + 1),
                      icon: Icon(
                        _isImprovementStep
                            ? Icons.send_rounded
                            : Icons.arrow_forward,
                      ),
                      label: Text(
                        _isImprovementStep
                            ? l10n.sendRecap
                            : state.step == 4
                            ? l10n.recapImprovementTitle
                            : l10n.continueToNextStep,
                      ),
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

class _StepBadge extends StatelessWidget {
  final String label;
  final int index;
  final bool isActive;
  final bool isCompleted;

  const _StepBadge({
    required this.label,
    required this.index,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final color = isCompleted || isActive
        ? palette.primary
        : palette.textDisabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? palette.primary.withValues(alpha: 0.16)
            : palette.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? palette.primary : palette.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? palette.textPrimary : palette.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final color = switch (status) {
      'REVIEWED' => semantic.success,
      'SUBMITTED' => palette.primary,
      _ => semantic.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        recapCopy(context, status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── LOW_TICKET landing: history blocked, create allowed ──────────────────────

class _RecapLowTicketLanding extends StatelessWidget {
  final VoidCallback onCreate;

  const _RecapLowTicketLanding({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          // Create recap card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.edit_calendar_outlined,
                    color: palette.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.weeklyRecapTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.useThisSpaceToSummarizeYourWeek,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.newRecap),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // History locked
          PremiumLockedSection(
            isLocked: true,
            label: 'Histórico de recaps',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.yourWeeklyHistory,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.trackYourWeeksReviewPreviousRecaps,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Placeholder recap cards (blurred)
                  for (var i = 0; i < 2; i++) ...[
                    Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        color: palette.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    if (i == 0) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Simplified recap form for LOW_TICKET ─────────────────────────────────────

class _SimplifiedRecapForm extends StatelessWidget {
  final RecapFormActive state;
  final void Function(String field, dynamic value) onFieldChanged;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String Function(Map<String, dynamic> formData) formatWeekRange;

  const _SimplifiedRecapForm({
    super.key,
    required this.state,
    required this.onFieldChanged,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onCancel,
    required this.formatWeekRange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final formData = state.formData;

    final trainingEffort = (formData['training_effort'] as num?)?.toInt() ?? 3;
    final trainingSessions =
        (formData['training_sessions'] as num?)?.toInt() ?? 2;
    final dietAdherence = (formData['food_quality'] as num?)?.toInt() ?? 4;
    final weeklyState = formData['mood'] as String? ?? 'BIEN';
    final weekDifficulty = (formData['stress_level'] as num?)?.toInt() ?? 3;
    final painChoice = formData['pain_intensity'] as String? ?? 'NO';
    final appRating =
        (formData['improvement_app_rating'] as num?)?.toInt() ?? 4;
    final serviceRating =
        (formData['improvement_service_rating'] as num?)?.toInt() ?? 4;
    final improvementAreas =
        (formData['improvement_areas'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Week range header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: palette.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatWeekRange(formData),
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Training ──
                RecapSectionCard(
                  title: l10n.recapTraining,
                  subtitle: 'Cuéntanos qué tal fue tu semana de entrenos.',
                  icon: Icons.fitness_center,
                  child: Column(
                    children: [
                      RecapSliderField(
                        label: l10n.completedSessions,
                        helperText:
                            '¿Cuántos entrenos completaste esta semana?',
                        value: trainingSessions.toDouble().clamp(0, 5),
                        min: 0,
                        max: 5,
                        divisions: 5,
                        valueLabelBuilder: (value) => value.round().toString(),
                        onChanged: (value) =>
                            onFieldChanged('training_sessions', value.round()),
                      ),
                      const SizedBox(height: 20),
                      RecapStarRatingField(
                        label: l10n.overallEffort,
                        helperText:
                            'Valora del 1 al 5 el esfuerzo general de la semana.',
                        value: trainingEffort.clamp(1, 5),
                        onChanged: (value) =>
                            onFieldChanged('training_effort', value),
                      ),
                    ],
                  ),
                ),

                // ── Nutrition ──
                RecapSectionCard(
                  title: l10n.recapNutrition,
                  subtitle:
                      'Solo necesitamos tu adherencia general a la dieta.',
                  icon: Icons.restaurant_menu,
                  child: RecapStarRatingField(
                    label: 'Adherencia a la dieta',
                    helperText:
                        '¿Hasta qué punto seguiste tu plan nutricional?',
                    value: dietAdherence.clamp(1, 5),
                    onChanged: (value) => onFieldChanged('food_quality', value),
                  ),
                ),

                // ── Recovery ──
                RecapSectionCard(
                  title: l10n.recapRecovery,
                  subtitle: 'Resume cómo respondió tu cuerpo esta semana.',
                  icon: Icons.hotel_outlined,
                  child: Column(
                    children: [
                      RecapChoiceChipsField(
                        label: 'Recuperación general',
                        helperText:
                            '¿Cómo te has sentido a nivel de recuperación?',
                        value: formData['fatigue_level'] as String?,
                        options: const ['CANSADO', 'NORMAL', 'BIEN', 'FUERTE'],
                        onSelected: (value) =>
                            onFieldChanged('fatigue_level', value),
                      ),
                      const SizedBox(height: 20),
                      RecapChoiceChipsField(
                        label: '¿Has tenido molestias o dolor?',
                        helperText:
                            'Indícanos si hubo molestias generales durante la semana.',
                        value: painChoice,
                        options: const ['NO', 'SI'],
                        onSelected: (value) =>
                            onFieldChanged('pain_intensity', value),
                      ),
                      const SizedBox(height: 20),
                      RecapTextAreaField(
                        label: 'Más contexto sobre tus molestias',
                        hintText:
                            'Ej: noté carga en lumbares después del viernes.',
                        initialValue:
                            formData['recovery_notes'] as String? ?? '',
                        onChanged: (value) =>
                            onFieldChanged('recovery_notes', value),
                      ),
                    ],
                  ),
                ),

                // ── General ──
                RecapSectionCard(
                  title: l10n.recapGeneral,
                  subtitle:
                      'Queremos entender cómo ha sido tu semana en general.',
                  icon: Icons.mood,
                  child: Column(
                    children: [
                      RecapEmojiRatingField(
                        label: 'Estado semanal',
                        helperText:
                            '¿Con qué sensación general te quedas esta semana?',
                        value: const [
                          'MUY_MAL',
                          'MAL',
                          'NORMAL',
                          'BIEN',
                          'MUY_BIEN',
                        ].indexOf(weeklyState).clamp(0, 4),
                        onChanged: (value) => onFieldChanged(
                          'mood',
                          const [
                            'MUY_MAL',
                            'MAL',
                            'NORMAL',
                            'BIEN',
                            'MUY_BIEN',
                          ][value],
                        ),
                      ),
                      const SizedBox(height: 20),
                      RecapStarRatingField(
                        label: 'Dificultad de la semana',
                        helperText:
                            'Valora del 1 al 5 qué tan difícil se te ha hecho seguir el plan.',
                        value: weekDifficulty.clamp(1, 5),
                        onChanged: (value) =>
                            onFieldChanged('stress_level', value),
                      ),
                      const SizedBox(height: 20),
                      RecapTextAreaField(
                        label: '¿Qué ha sido lo más difícil?',
                        hintText:
                            'Cuéntanos qué fue lo que más te costó esta semana.',
                        initialValue:
                            formData['general_notes'] as String? ?? '',
                        onChanged: (value) =>
                            onFieldChanged('general_notes', value),
                      ),
                    ],
                  ),
                ),

                // ── Improvement (same as HIGH_TICKET) ──
                RecapSectionCard(
                  title: l10n.recapImprovementRatingsTitle,
                  subtitle: l10n.recapImprovementRatingsSubtitle,
                  icon: Icons.star_outline_rounded,
                  child: Column(
                    children: [
                      RecapStarRatingField(
                        label: l10n.rateTheService,
                        helperText: l10n.howYouRateTheSupportReceivedThisWeek,
                        value: serviceRating.clamp(1, 5),
                        onChanged: (value) =>
                            onFieldChanged('improvement_service_rating', value),
                      ),
                      const SizedBox(height: 20),
                      RecapStarRatingField(
                        label: l10n.rateTheApp,
                        helperText: l10n.yourOverallExperienceWithTheApp,
                        value: appRating.clamp(1, 5),
                        onChanged: (value) =>
                            onFieldChanged('improvement_app_rating', value),
                      ),
                    ],
                  ),
                ),
                RecapSectionCard(
                  title: l10n.recapWhatCanWeImprove,
                  subtitle: l10n.selectThePointsWhereYouWantMoreSupport,
                  icon: Icons.tune_rounded,
                  child: RecapMultiSelectField(
                    label: l10n.selectThePointsWhereYouWantMoreSupport,
                    helperText: l10n.selectThePointsWhereYouWantMoreSupport,
                    values: improvementAreas,
                    options: const [
                      'ENTRENAMIENTO',
                      'NUTRICION',
                      'ADHERENCIA',
                      'RECUPERACION',
                      'MOTIVACION',
                      'APP',
                    ],
                    onChanged: (value) =>
                        onFieldChanged('improvement_areas', value),
                  ),
                ),
                RecapSectionCard(
                  title: l10n.recapTellUsMore,
                  subtitle: l10n.closeTheWeekWithWhatMattersForYourCoach,
                  icon: Icons.chat_bubble_outline_rounded,
                  child: RecapTextAreaField(
                    label: l10n.suggestionsOrImprovements,
                    hintText: l10n.egIWouldLikeMoreContextInTheSessions,
                    initialValue:
                        formData['improvement_feedback_text'] as String? ?? '',
                    onChanged: (value) =>
                        onFieldChanged('improvement_feedback_text', value),
                  ),
                ),

                // ── Premium teaser: detailed recap ──
                PremiumLockedSection(
                  isLocked: true,
                  label: 'Recap detallado',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recap detallado',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final step in [
                          l10n.recapTraining,
                          l10n.recapNutrition,
                          l10n.recapRecovery,
                          l10n.recapGeneral,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: palette.textDisabled,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$step completo',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom bar: save draft + submit
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: palette.divider)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      label: Text(l10n.cancel),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: onSaveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(l10n.save),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(l10n.sendRecap),
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
