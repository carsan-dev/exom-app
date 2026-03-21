import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_general.dart';
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
  static const _stepTitles = [
    'Entreno',
    'Nutrición',
    'Recuperación',
    'General',
  ];

  final PageController _pageController = PageController();
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd MMM', 'es');

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecapBloc, RecapState>(
      listener: (context, state) {
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
              content: const Text('Recap enviado correctamente'),
              backgroundColor: AppColors.success,
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
              backgroundColor: AppColors.error,
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

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              isFormActive
                  ? formState.recapId == null
                        ? 'Nuevo recap'
                        : 'Editar recap'
                  : 'Recap semanal',
            ),
            backgroundColor: AppColors.background,
            leading: isFormActive
                ? IconButton(
                    onPressed: () => context.read<RecapBloc>().add(
                      const RecapFormCancelled(),
                    ),
                    icon: const Icon(Icons.close),
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo recap'),
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
    if (state is RecapLoading || state is RecapInitial) {
      return const Center(
        key: ValueKey('recap-loading'),
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state is RecapFormActive) {
      return _RecapFormView(
        key: const ValueKey('recap-form'),
        pageController: _pageController,
        stepTitles: _stepTitles,
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
        onOpenRecap: (recap) {
          if (recap.isReviewed) {
            _showRecapSummary(context, recap);
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
      return Center(
        key: const ValueKey('recap-error'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 42),
              const SizedBox(height: 16),
              Text(
                'No se pudo cargar el recap',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    context.read<RecapBloc>().add(const RecapLoadRequested()),
                child: const Text('Reintentar'),
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
    final start = formData['week_start_date'] as String?;
    final end = formData['week_end_date'] as String?;
    if (start == null || end == null) return 'Semana sin fechas';

    final startDate = DateTime.tryParse(start);
    final endDate = DateTime.tryParse(end);
    if (startDate == null || endDate == null) return 'Semana sin fechas';

    return '${_displayDateFormat.format(startDate)} - ${_displayDateFormat.format(endDate)}';
  }

  void _showRecapSummary(BuildContext context, RecapEntity recap) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatWeekRange(_buildInitialData(recap)),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _StatusChip(status: recap.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SummarySection(
                    title: 'Entreno',
                    children: [
                      _SummaryItem(
                        'Esfuerzo',
                        recap.trainingEffort?.toString() ?? '—',
                      ),
                      _SummaryItem(
                        'Sesiones',
                        recap.trainingSessions?.toString() ?? '—',
                      ),
                      _SummaryItem(
                        'Progreso',
                        recap.trainingProgress != null
                            ? formatRecapOption(recap.trainingProgress!)
                            : '—',
                      ),
                      _SummaryItem('Notas', recap.trainingNotes ?? '—'),
                    ],
                  ),
                  _SummarySection(
                    title: 'Nutrición',
                    children: [
                      _SummaryItem(
                        'Calidad',
                        recap.nutritionQuality != null
                            ? formatRecapOption(recap.nutritionQuality!)
                            : '—',
                      ),
                      _SummaryItem(
                        'Hidratación',
                        recap.hydrationEnabled
                            ? formatRecapOption(
                                recap.hydrationLevel ?? 'ACTIVA',
                              )
                            : 'No valorada',
                      ),
                      _SummaryItem(
                        'Comidas',
                        recap.foodQuality?.toString() ?? '—',
                      ),
                      _SummaryItem('Notas', recap.nutritionNotes ?? '—'),
                    ],
                  ),
                  _SummarySection(
                    title: 'Recuperación',
                    children: [
                      _SummaryItem(
                        'Sueño',
                        recap.sleepHoursRange != null
                            ? formatRecapOption(recap.sleepHoursRange!)
                            : '—',
                      ),
                      _SummaryItem(
                        'Fatiga',
                        recap.fatigueLevel != null
                            ? formatRecapOption(recap.fatigueLevel!)
                            : '—',
                      ),
                      _SummaryItem(
                        'Molestias',
                        recap.musclePainZones.isEmpty
                            ? 'Sin zonas marcadas'
                            : recap.musclePainZones
                                  .map(formatRecapOption)
                                  .join(', '),
                      ),
                      _SummaryItem('Notas', recap.recoveryNotes ?? '—'),
                    ],
                  ),
                  _SummarySection(
                    title: 'General',
                    children: [
                      _SummaryItem(
                        'Ánimo',
                        recap.mood != null
                            ? formatRecapOption(recap.mood!)
                            : '—',
                      ),
                      _SummaryItem(
                        'Estrés',
                        recap.stressEnabled
                            ? '${recap.stressLevel ?? 0}/5'
                            : 'No valorado',
                      ),
                      _SummaryItem(
                        'Valoración app',
                        recap.improvementAppRating != null
                            ? '${recap.improvementAppRating}/5'
                            : '—',
                      ),
                      _SummaryItem(
                        'Valoración servicio',
                        recap.improvementServiceRating != null
                            ? '${recap.improvementServiceRating}/5'
                            : '—',
                      ),
                      _SummaryItem(
                        'Áreas a mejorar',
                        recap.improvementAreas.isEmpty
                            ? 'Sin áreas seleccionadas'
                            : recap.improvementAreas
                                  .map(formatRecapOption)
                                  .join(', '),
                      ),
                      _SummaryItem(
                        'Notas generales',
                        recap.generalNotes ?? '—',
                      ),
                      _SummaryItem(
                        'Feedback',
                        recap.improvementFeedbackText ?? '—',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecapListView extends StatelessWidget {
  final List<RecapEntity> recaps;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;
  final ValueChanged<RecapEntity> onOpenRecap;
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
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.edit_calendar_outlined,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Todavía no has enviado ningún recap',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Usa este espacio para resumir tu semana y dar contexto útil a tu coach.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Crear mi primer recap'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu histórico semanal',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Mantén trazabilidad de tus semanas, revisa recaps anteriores y continúa borradores pendientes.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
              onPressed: () => onOpenRecap(recap),
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
    final actionLabel = recap.isReviewed
        ? 'Ver resumen'
        : recap.isSubmitted
        ? 'Actualizar'
        : 'Continuar';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Creado ${DateFormat('dd/MM/yyyy').format(recap.createdAt)}',
                      style: const TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 12,
                      ),
                    ),
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
                label: recap.trainingProgress != null
                    ? formatRecapOption(recap.trainingProgress!)
                    : 'Entreno sin valorar',
              ),
              _InfoPill(
                icon: Icons.restaurant,
                label: recap.nutritionQuality != null
                    ? formatRecapOption(recap.nutritionQuality!)
                    : 'Nutrición sin valorar',
              ),
              _InfoPill(
                icon: Icons.mood,
                label: recap.mood != null
                    ? formatRecapOption(recap.mood!)
                    : 'Ánimo sin valorar',
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

  @override
  Widget build(BuildContext context) {
    final isLastStep = state.step == stepTitles.length - 1;

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatWeekRange(state.formData),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Completa los cuatro bloques y envía tu resumen semanal.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: List.generate(stepTitles.length, (index) {
                  final isActive = index == state.step;
                  final isCompleted = index < state.step;
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
        Expanded(
          child: PageView(
            controller: pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
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
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    if (state.step == 0)
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancelar'),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => onStepChanged(state.step - 1),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Anterior'),
                      ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: onSaveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLastStep
                        ? onSubmit
                        : () => onStepChanged(state.step + 1),
                    icon: Icon(
                      isLastStep ? Icons.send_rounded : Icons.arrow_forward,
                    ),
                    label: Text(
                      isLastStep
                          ? 'Enviar recap'
                          : 'Continuar al siguiente paso',
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
    final color = isCompleted || isActive
        ? AppColors.primary
        : AppColors.textDisabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.16)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.divider,
        ),
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
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
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
    final color = switch (status) {
      'REVIEWED' => AppColors.success,
      'SUBMITTED' => AppColors.primary,
      _ => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatRecapOption(status),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SummarySection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textDisabled,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
