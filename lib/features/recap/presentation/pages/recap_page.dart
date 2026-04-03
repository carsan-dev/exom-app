import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:exom_app/core/theme/app_theme.dart';
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
          floatingActionButton: state is RecapListLoaded
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
          if (recap.isReviewed) {
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
    final actionLabel = recap.isReviewed
        ? l10n.viewSummary
        : recap.isSubmitted
        ? l10n.update
        : l10n.continueButton;
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
