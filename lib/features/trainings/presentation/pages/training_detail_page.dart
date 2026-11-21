import 'dart:async';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/navigation/page_aware_bottom_sheet.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/utils/training_type_utils.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/planned_sets.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_sync_state.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/features/home/presentation/pages/home_page.dart';

bool _hasRequiredSetPerformance(
  TrainingExerciseEntity exercise,
  List<SetPerformance>? performances,
) {
  if (!exercise.requestSetTracking) return true;
  final bySet = {
    for (final performance in performances ?? const <SetPerformance>[])
      performance.setNumber: performance,
  };
  final timeBased = timePerformanceUnitForExercise(exercise) != null;
  final requiredSets = exercise.blockRounds ?? exercise.sets;
  return List.generate(requiredSets, (index) => index + 1).every((setNumber) {
    final performance = bySet[setNumber];
    return timeBased ? performance?.seconds != null : performance?.reps != null;
  });
}

class TrainingCompletionInput {
  const TrainingCompletionInput({this.rpe, this.notes});
  final int? rpe;
  final String? notes;
}

Future<TrainingCompletionInput?> _confirmCompleteTraining(
  BuildContext context,
  AppLocalizations l10n, {
  required LocalStorage storage,
  required String trainingId,
  required String date,
  required String executionId,
  required String? sessionStamp,
  String? initialNote,
}) => showDialog<TrainingCompletionInput>(
  context: context,
  builder: (_) => CompleteTrainingConfirmationDialog(
    l10n: l10n, storage: storage, trainingId: trainingId, date: date,
    executionId: executionId, sessionStamp: sessionStamp, initialNote: initialNote,
  ),
);

class CompleteTrainingConfirmationDialog extends StatefulWidget {
  const CompleteTrainingConfirmationDialog({super.key, required this.l10n,
    required this.storage, required this.trainingId, required this.date,
    required this.executionId, required this.sessionStamp, this.initialNote});

  final AppLocalizations l10n;
  final LocalStorage storage;
  final String trainingId;
  final String date;
  final String executionId;
  final String? sessionStamp;
  final String? initialNote;

  @override
  State<CompleteTrainingConfirmationDialog> createState() =>
      _CompleteTrainingConfirmationDialogState();
}

class _CompleteTrainingConfirmationDialogState extends State<CompleteTrainingConfirmationDialog> {
  late final TextEditingController _note;
  int? _rpe;
  bool _saving = false;
  Future<void> _pendingSave = Future<void>.value();

  void _saveDraft() {
    _pendingSave = _pendingSave.then((_) => _persist()).catchError((Object _) {
      // The confirm path retries persistence and stays open if it fails.
    });
  }

  @override
  void initState() {
    super.initState();
    final draft = widget.storage.getTrainingCompletionDraft(
      widget.trainingId, widget.date, widget.executionId);
    _rpe = draft?['rpe'] as int?;
    _note = TextEditingController(text: draft?['notes'] as String? ?? widget.initialNote);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    if (widget.sessionStamp == null || widget.storage.sessionStamp != widget.sessionStamp) {
      throw const LocalSessionChanged();
    }
    await widget.storage.saveTrainingCompletionDraft(
      widget.trainingId, widget.date, widget.executionId,
      rpe: _rpe, notes: _note.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('complete-training-confirmation'),
      title: Text(widget.l10n.completeTrainingConfirmTitle),
      content: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.l10n.completeTrainingConfirmMessage),
          const SizedBox(height: 12),
          Text(widget.l10n.completeTrainingRpeLabel),
          const SizedBox(height: 4),
          Text(widget.l10n.completeTrainingRpeExplanation,
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (_rpe != null) const SizedBox(key: Key('completion-rpe-selected')),
          Wrap(spacing: 4, children: [
            for (var value = 1; value <= 10; value++)
              ChoiceChip(
                key: Key('completion-rpe-$value'),
                label: Text('$value'),
                selected: _rpe == value,
                onSelected: _saving ? null : (_) {
                  setState(() => _rpe = _rpe == value ? null : value);
                  _saveDraft();
                },
              ),
          ]),
          TextField(
            key: const Key('completion-note'),
            controller: _note,
            onChanged: (_) => _saveDraft(),
            maxLines: 2,
            decoration: InputDecoration(labelText: widget.l10n.addQuickNoteOptional),
          ),
        ],
      )),
      actions: [
        TextButton(
          key: const Key('cancel-complete-training'),
          onPressed: _saving ? null : () async {
            setState(() => _saving = true);
            try {
              await _pendingSave;
              await _persist();
              if (context.mounted) Navigator.of(context).pop();
            } catch (_) {
              if (mounted) setState(() => _saving = false);
            }
          },
          child: Text(widget.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-complete-training'),
          onPressed: _saving || _rpe == null ? null : () async {
            setState(() => _saving = true);
            try {
              await _pendingSave;
              await _persist();
              if (context.mounted) {
                Navigator.of(context).pop(TrainingCompletionInput(
                  rpe: _rpe, notes: _note.text.trim().isEmpty ? null : _note.text.trim()));
              }
            } catch (_) {
              if (mounted) setState(() => _saving = false);
            }
          },
          child: Text(widget.l10n.completeTrainingConfirmAction),
        ),
      ],
    );
  }
}

class TrainingDetailPage extends StatefulWidget {
  final String trainingId;
  final String? selectedDate;
  final String? selectedExecutionId;
  final bool finalizeSelected;

  const TrainingDetailPage({
    super.key,
    required this.trainingId,
    this.selectedDate,
    this.selectedExecutionId,
    this.finalizeSelected = false,
  });

  @override
  State<TrainingDetailPage> createState() => _TrainingDetailPageState();
}

class _TrainingDetailPageState extends State<TrainingDetailPage> {
  late final String? _sessionStamp;

  @override
  void initState() {
    super.initState();
    _sessionStamp = sl<LocalStorage>().sessionStamp;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<TrainingBloc>()
            ..add(TrainingDetailLoadRequested(widget.trainingId, date: widget.selectedDate)),
      child: _TrainingDetailView(
        sessionStamp: _sessionStamp,
        selectedExecutionId: widget.selectedExecutionId,
        finalizeSelected: widget.finalizeSelected,
      ),
    );
  }
}

class _TrainingDetailView extends StatelessWidget {
  const _TrainingDetailView({required this.sessionStamp,
    required this.selectedExecutionId, required this.finalizeSelected});

  final String? sessionStamp;
  final String? selectedExecutionId;
  final bool finalizeSelected;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrainingBloc, TrainingState>(
      listener: (context, state) {
        if (state is TrainingDetailLoaded && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizedErrorTextOf(context, state.errorMessage, fallback: (l10n) => l10n.trainingProgressSaveError)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is TrainingLoading || state is TrainingInitial) {
          return const _TrainingDetailLoadingScaffold();
        }
        if (state is TrainingError) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              title: Text(AppLocalizations.of(context).errorTitle),
            ),
            body: ErrorWidget2(
              message: state.apiException != null
                  ? localizedApiError(context, state.apiException!)
                  : AppLocalizations.of(context).errorServer,
              onRetry: null,
            ),
          );
        }
        if (state is TrainingDetailLoaded) {
          return _DetailScaffold(
            state: state, sessionStamp: sessionStamp,
            selectedExecutionId: selectedExecutionId,
            finalizeSelected: finalizeSelected,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _TrainingDetailLoadingScaffold extends StatelessWidget {
  const _TrainingDetailLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          leading: _DetailBackButton(onPressed: () => context.pop()),
          title: const ShimmerCard(
            height: 18,
            width: 164,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
        body: SizedBox.expand(
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.only(
                  bottom: 160 + MediaQuery.of(context).padding.bottom,
                ),
                children: const [
                  GlassCard(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(20),
                    borderRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ShimmerCard(
                              height: 24,
                              width: 72,
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                            ShimmerCard(
                              height: 24,
                              width: 68,
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                            ShimmerCard(
                              height: 24,
                              width: 84,
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ShimmerCard(
                              height: 18,
                              width: 54,
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            ShimmerCard(
                              height: 18,
                              width: 62,
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            ShimmerCard(
                              height: 18,
                              width: 58,
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _TrainingDetailSectionTitleSkeleton(showTrailing: false),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: ShimmerCard(
                      height: 92,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                  _TrainingDetailSectionTitleSkeleton(showTrailing: true),
                  _TrainingExerciseSkeletonCard(),
                  _TrainingExerciseSkeletonCard(),
                  _TrainingExerciseSkeletonCard(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ShimmerCard(
                      height: 78,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: _trainingStickyBarDecoration(context),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ShimmerCard(
                            height: 14,
                            width: 126,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          Spacer(),
                          ShimmerCard(
                            height: 14,
                            width: 38,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      ShimmerCard(
                        height: 8,
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      SizedBox(height: 12),
                      ShimmerCard(
                        height: 48,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingDetailSectionTitleSkeleton extends StatelessWidget {
  const _TrainingDetailSectionTitleSkeleton({required this.showTrailing});

  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          const ShimmerCard(
            height: 18,
            width: 118,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          const Spacer(),
          if (showTrailing)
            const ShimmerCard(
              height: 14,
              width: 86,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
        ],
      ),
    );
  }
}

class _TrainingExerciseSkeletonCard extends StatelessWidget {
  const _TrainingExerciseSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              ShimmerCard(
                height: 52,
                width: 52,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCard(
                      height: 18,
                      width: 164,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    SizedBox(height: 8),
                    ShimmerCard(
                      height: 14,
                      width: 118,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              ShimmerCard(
                height: 22,
                width: 22,
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
            ],
          ),
          SizedBox(height: 12),
          ShimmerCard(
            height: 14,
            width: 210,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ],
      ),
    );
  }
}

class _DetailScaffold extends StatefulWidget {
  final TrainingDetailLoaded state;
  final String? sessionStamp;
  final String? selectedExecutionId;
  final bool finalizeSelected;

  const _DetailScaffold({required this.state, required this.sessionStamp,
    required this.selectedExecutionId, required this.finalizeSelected});

  @override
  State<_DetailScaffold> createState() => _DetailScaffoldState();
}

class _DetailScaffoldState extends State<_DetailScaffold> {
  final _notesController = TextEditingController();
  bool _completeConfirmationOpen = false;
  String? _sessionId;
  String? _displaySessionId;
  String? _locallyConfirmedSessionId;
  String? _completionReturnSessionId;
  bool _completionAccepted = false;
  StreamSubscription<void>? _syncChanges;
  StreamSubscription<FeedbackUploadNotice>? _feedbackChanges;

  @override
  void initState() {
    super.initState();
    // A mounted detail reads queue state directly; sync events only invalidate it.
    if (sl.isRegistered<OfflineSyncService>()) {
      _syncChanges = sl<OfflineSyncService>().changes.listen((_) {
        if (!_sameSession) return;
        final id = widget.selectedExecutionId;
        if (id != null && _sessionId == null) {
          final storage = sl<LocalStorage>();
          if (storage.getTrainingExecutions(widget.state.training.id, widget.state.selectedDate)
              .any((entry) => entry['id'] == id && entry['status'] == 'failed')) {
            _sessionId = id;
          }
        }
        setState(() {});
        _returnAfterConfirmedCompletion();
      });
    }
    if (sl.isRegistered<FeedbackUploadQueueService>()) {
      _feedbackChanges = sl<FeedbackUploadQueueService>().notices.listen((_) {
        if (_sameSession) {
          setState(() {});
          _returnAfterConfirmedCompletion();
        }
      });
    }
    final id = widget.selectedExecutionId;
    final storage = sl<LocalStorage>();
    if (id != null && widget.sessionStamp != null &&
        storage.sessionStamp == widget.sessionStamp &&
        storage.getPendingTrainingExecutions().any((entry) =>
          entry['id'] == id && entry['training_id'] == widget.state.training.id &&
          entry['assignment_date'] == widget.state.selectedDate &&
          entry['status'] != 'pending-sync' && entry['status'] != 'conflict')) {
      _sessionId = id;
      if (widget.finalizeSelected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_sameSession) _completeSelectedTraining();
        });
      }
    } else {
      _hydrateSoleExecution();
    }
  }

  void _hydrateSoleExecution() {
    if (!_sameSession) return;
    final storage = sl<LocalStorage>();
    // Only an owned registry entry and its matching session progress can
    // identify a display session. This never chooses an execution for writes.
    final trainingId = widget.state.training.id;
    final date = widget.state.selectedDate;
    final matches = [
      ...storage.getPendingTrainingExecutions().where((entry) =>
        entry['training_id'] == trainingId &&
        entry['assignment_date'] == date &&
        const ['pending', 'pending-finalize', 'pending-sync', 'failed', 'conflict']
            .contains(entry['status'])),
      ...storage.getConfirmedTrainingExecutions(trainingId, date),
    ];
    final selected = widget.selectedExecutionId;
    final candidates = selected == null ? matches :
        matches.where((entry) => entry['id'] == selected).toList();
    if (selected == null && matches.length != 1 || candidates.length != 1) return;
    final entry = candidates.single;
    final id = entry['id'];
    if (id is! String || id.isEmpty || !widget.state.sessionProgress.containsKey(id)) {
      return;
    }
    if (const ['confirmed', 'completed'].contains(entry['status']) ||
        const ['pending', 'pending-finalize', 'failed'].contains(entry['status'])) {
      _displaySessionId = id;
    } else if (entry['status'] == 'pending-sync' &&
        storage.getPendingSyncActions().any((action) =>
          action['type'] == 'complete_training' &&
          action['training_id'] == trainingId &&
          action['date'] == date &&
          action['training_session_id'] == id &&
          const ['queued', 'uploading'].contains(action['status']))) {
      _displaySessionId = id;
    }
  }

  String? get _progressSessionId => _sessionId ?? _displaySessionId;
  TrainingDayProgress get _progress => !_sameSession || _progressSessionId == null
      ? const TrainingDayProgress()
      : widget.state.sessionProgress[_progressSessionId] ?? const TrainingDayProgress();
  bool get _sameSession => mounted && widget.sessionStamp != null &&
      sl<LocalStorage>().sessionStamp == widget.sessionStamp;

  Future<void> _toggleExercise(TrainingEntity training,
      TrainingExerciseEntity exercise, bool completed, double? weightUsed) async {
    final sessionId = await _selectExecution(training, widget.state.selectedDate);
    if (!mounted || !_sameSession || sessionId == null) return;
    context.read<TrainingBloc>().add(MarkExerciseCompleted(
      trainingExerciseId: exercise.id,
      exerciseId: exercise.exercise.id,
      completed: completed,
      weightUsed: weightUsed,
      sessionId: sessionId,
      sessionStamp: widget.sessionStamp,
    ));
  }

  Future<String?> _selectExecution(TrainingEntity training, String date,
      {String? legacyExerciseId}) async {
    if (!_sameSession) return null;
    final storage = sl<LocalStorage>();
    final legacy = legacyExerciseId != null &&
        storage.recoverableLegacyWorkout(training.id, legacyExerciseId, date) != null;
    if (_sessionId != null && !legacy) return _sessionId;
    final pending = storage.getTrainingExecutions(training.id, date);
    final hasPendingSync = storage.getPendingTrainingExecutions().any((entry) =>
      entry['training_id'] == training.id && entry['assignment_date'] == date &&
      entry['status'] == 'pending-sync');
    final hasCompleted = storage.hasCompletedTrainingExecution(training.id, date);
    final l10n = AppLocalizations.of(context);
    String? selected;
    if (pending.isNotEmpty || legacy || hasPendingSync || hasCompleted) {
      selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.selectTrainingExecution),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in pending)
                ListTile(
                  title: Text('${training.name} · $date'),
                  subtitle: Text(entry['id'] as String),
                  onTap: () => Navigator.of(dialogContext).pop(entry['id'] as String),
                ),
              if (legacy)
                ListTile(
                  key: const Key('recover-legacy-workout'),
                  title: Text(l10n.recoverSavedExerciseDraft),
                  subtitle: Text(l10n.restoreSavedSetsNewExecution),
                  onTap: () => Navigator.of(dialogContext).pop('recover'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop('new'),
                child: Text(l10n.newTrainingExecution)),
          ],
        ),
      );
      if (!_sameSession || selected == null) return null;
    }
    if (!_sameSession) return null;
    String id;
    try {
      id = selected == 'recover' && legacyExerciseId != null
          ? await storage.recoverLegacyWorkout(training.id, legacyExerciseId, date)
          : selected == null || selected == 'new'
              ? await storage.createTrainingExecution(training.id, date,
                  trainingName: training.name)
              : selected;
    } catch (_) {
      if (mounted && _sameSession) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).trainingDraftRecoveryFailed),
        ));
      }
      return null;
    }
    if (!_sameSession) return null;
    setState(() {
      _sessionId = id;
      _locallyConfirmedSessionId = null;
    });
    return id;
  }

  @override
  void didUpdateWidget(covariant _DetailScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.training.id != oldWidget.state.training.id ||
        widget.state.selectedDate != oldWidget.state.selectedDate) {
      _sessionId = null;
      _displaySessionId = null;
      _locallyConfirmedSessionId = null;
      _completionReturnSessionId = null;
      _completionAccepted = false;
      _hydrateSoleExecution();
    }
  }

  Future<void> _completeSelectedTraining() async {
    final training = widget.state.training;
    final storage = sl<LocalStorage>();
    final l10n = AppLocalizations.of(context);
    if (!_sameSession || _completeConfirmationOpen) return;
    setState(() => _completeConfirmationOpen = true);
    final sessionId = await _selectExecution(training, widget.state.selectedDate);
    if (!mounted || !_sameSession || sessionId == null) {
      if (mounted) setState(() => _completeConfirmationOpen = false);
      return;
    }
    final missingRequiredPerformance = training.exercises.any(
      (exercise) => !_hasRequiredSetPerformance(
        exercise, _progress.performances[exercise.id]));
    final execution = storage.getTrainingExecutions(
      training.id, widget.state.selectedDate)
        .where((entry) => entry['id'] == sessionId).firstOrNull;
    if (missingRequiredPerformance && execution?['status'] != 'failed') {
      setState(() => _completeConfirmationOpen = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.completeTrainingTrackingRequired)));
      return;
    }
    if (training.requiresLastSetVideo && training.exercises.any((exercise) =>
        !storage.getFeedbackUploadQueue().any((item) =>
          item['training_id'] == training.id &&
          item['assignment_date'] == widget.state.selectedDate &&
          item['training_session_id'] == sessionId &&
          item['training_exercise_id'] == exercise.id &&
          item['feedback_kind'] == 'LAST_SET' &&
          item['media_type'] == 'VIDEO' &&
          item['discard_requested'] != true &&
          const ['queued', 'uploading', 'processing', 'completed']
              .contains(item['status'])))) {
      setState(() => _completeConfirmationOpen = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.trainingLastSetVideoRequired)));
      return;
    }
    final saved = storage.getTrainingCompletionDraft(
      training.id, widget.state.selectedDate, sessionId);
    if (execution?['status'] == 'conflict' ||
        execution?['status'] == 'failed' && saved == null) {
      setState(() => _completeConfirmationOpen = false);
      return;
    }
    final input = execution?['status'] == 'failed'
        ? TrainingCompletionInput(
            rpe: saved?['rpe'] as int?, notes: saved?['notes'] as String?)
        : await _confirmCompleteTraining(context, l10n,
            storage: storage, trainingId: training.id,
            date: widget.state.selectedDate, executionId: sessionId,
            sessionStamp: widget.sessionStamp,
            initialNote: _notesController.text.trim());
    if (!mounted) return;
    setState(() => _completeConfirmationOpen = false);
    if (!_sameSession || input == null) return;
    final completion = Completer<void>();
    _completionReturnSessionId = sessionId;
    _completionAccepted = false;
    context.read<TrainingBloc>().add(CompleteTrainingRequested(
      sessionId: sessionId, sessionStamp: widget.sessionStamp,
      completion: completion, notes: input.notes, rpe: input.rpe));
    try {
      await completion.future;
      if (_sameSession) {
        _completionAccepted = true;
        setState(() {
          _locallyConfirmedSessionId = sessionId;
          _displaySessionId = sessionId;
          _sessionId = null;
        });
        _returnAfterConfirmedCompletion();
      }
    } catch (_) {
      _completionReturnSessionId = null;
      _completionAccepted = false;
      // The bloc exposes the save error; retain the execution for retry.
    }
  }

  void _returnAfterConfirmedCompletion() {
    final executionId = _completionReturnSessionId;
    if (!_sameSession || !_completionAccepted || executionId == null) return;
    final storage = sl<LocalStorage>();
    final trainingId = widget.state.training.id;
    final date = widget.state.selectedDate;
    final confirmed = storage
        .getConfirmedTrainingExecutions(trainingId, date)
        .any(
          (entry) =>
              entry['id'] == executionId &&
              entry['training_id'] == trainingId &&
              entry['assignment_date'] == date &&
              entry['status'] == 'confirmed',
        );
    if (!confirmed ||
        storage.getPendingSyncActions().any(
          (action) =>
              action['training_id'] == trainingId &&
              action['date'] == date &&
              action['training_session_id'] == executionId,
        )) {
      return;
    }
    final sync = sl.isRegistered<OfflineSyncService>()
        ? sl<OfflineSyncService>()
        : null;
    if (sync?.completionBlocker(trainingId, date, executionId) != null) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    _completionReturnSessionId = null;
    _completionAccepted = false;
    router.go(AppRoutes.home, extra: HomeCompletionRefresh());
  }

  @override
  void dispose() {
    _syncChanges?.cancel();
    _feedbackChanges?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  TrainingEntity? _groupedTraining;
  List<_ExerciseRowGroup> _groups = const [];
  bool _openingNext = false;

  /// Groups consecutive circuit members once per training revision instead of
  /// rescanning every exercise for each circuit on every build.
  List<_ExerciseRowGroup> _exerciseGroups(TrainingEntity training) {
    if (identical(_groupedTraining, training)) return _groups;
    final membersByBlock = <String, List<TrainingExerciseEntity>>{};
    final blockIds = <String?>[];
    for (final exercise in training.exercises) {
      final blockId = exercise.blockId;
      blockIds.add(blockId);
      if (blockId != null) {
        (membersByBlock[blockId] ??= <TrainingExerciseEntity>[]).add(exercise);
      }
    }
    for (final members in membersByBlock.values) {
      members.sort(
        (left, right) => (left.positionInBlock ?? left.order).compareTo(
          right.positionInBlock ?? right.order,
        ),
      );
    }
    final groups = <_ExerciseRowGroup>[];
    String? currentBlockId;
    for (var index = 0; index < training.exercises.length; index++) {
      final exercise = training.exercises[index];
      final blockId = blockIds[index];
      if (blockId == null) {
        groups.add(_ExerciseRowGroup(exercise));
        continue;
      }
      if (blockId == currentBlockId) continue;
      currentBlockId = blockId;
      groups.add(_ExerciseRowGroup(exercise, membersByBlock[blockId]));
    }
    _groupedTraining = training;
    return _groups = List<_ExerciseRowGroup>.unmodifiable(groups);
  }

  /// First exercise or circuit, in list order, that is not completed yet.
  _ExerciseRowGroup? _firstUnfinished(List<_ExerciseRowGroup> groups) {
    for (final group in groups) {
      final members = group.blockExercises ?? [group.leader];
      if (members.any((member) => !_progress.ids.contains(member.id))) {
        return group;
      }
    }
    return null;
  }

  /// Opens the active exercise exactly as the exercise sheet's start/resume
  /// action does (same execution selection and route arguments). Completes
  /// when that route is popped.
  Future<void> _openActiveExercise(
    BuildContext context,
    TrainingEntity training,
    TrainingExerciseEntity ex,
  ) async {
    final sessionId = await _selectExecution(
      training, widget.state.selectedDate,
      legacyExerciseId: ex.id);
    if (!mounted || !context.mounted || !_sameSession || sessionId == null) return;
    final selectedProgress = widget.state.sessionProgress[sessionId]
        ?? const TrainingDayProgress();
    await context.push<void>(
      AppRoutes.activeExercisePath(
        training.id,
        ex.id,
      ),
      extra: ActiveExercisePageArgs(
        trainingBloc: context.read<TrainingBloc>(),
        sessionId: sessionId,
        trainingExercise: ex,
        trainingName: training.name,
        trainingTypes: training.types,
        accentColorHex: training.accentColor,
        trainingLevel: training.level,
        initialWeightKg: selectedProgress.weights[ex.id],
        currentPerformances:
            selectedProgress.performances[ex.id],
        previousPerformances:
            widget.state.previousPerformances[ex.id],
        requiresLastSetVideo:
            training.requiresLastSetVideo,
        assignmentDate: widget.state.selectedDate,
      ),
    );
  }

  /// Opens the active circuit exactly as the circuit row's start action does.
  /// Completes when that route is popped.
  Future<void> _startCircuit(
    BuildContext context,
    TrainingEntity training,
    TrainingExerciseEntity ex,
    List<TrainingExerciseEntity> blockExercises,
  ) async {
    final blockId = ex.blockId!;
    final sessionId = await _selectExecution(
      training, widget.state.selectedDate);
    if (!mounted || !context.mounted || !_sameSession || sessionId == null) return;
    await context.push<void>(
      AppRoutes.activeCircuitPath(
        training.id,
        blockId,
      ),
      extra: ActiveCircuitPageArgs(
        trainingBloc: context.read<TrainingBloc>(),
        sessionId: sessionId,
        trainingName: training.name,
        trainingTypes: training.types,
        accentColorHex: training.accentColor,
        trainingLevel: training.level,
        blockId: blockId,
        blockName: ex.blockName ?? 'Circuito',
        rounds: ex.blockRounds ?? 1,
        restBetweenRoundsSeconds:
            ex.restBetweenRoundsSeconds ?? 60,
        exercises: blockExercises,
        previousPerformances: {
          for (final blockExercise in blockExercises)
            if (widget.state.previousPerformances[blockExercise.id] != null)
              blockExercise.id:
                  widget.state.previousPerformances[blockExercise.id]!,
        },
        requiresLastSetVideo:
            training.requiresLastSetVideo,
        assignmentDate: widget.state.selectedDate,
      ),
    );
  }

  /// Runs the pinned "next" action once: repeated taps while the execution is
  /// being selected, or while the opened route is on top, are ignored.
  Future<void> _runNext(Future<void> Function() action) async {
    if (_openingNext) return;
    setState(() => _openingNext = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _openingNext = false);
    }
  }

  ExomSyncState? _exerciseSync(
    List<Map<String, dynamic>> actions,
    TrainingExerciseEntity ex, {
    required bool hasLocalDraft,
  }) {
    return exerciseSyncState(
      ownedActions: actions,
      trainingId: widget.state.training.id,
      date: widget.state.selectedDate,
      trainingExerciseId: ex.id,
      sessionId: _progressSessionId,
      isCompleted: _progress.ids.contains(ex.id),
      hasLocalDraft: hasLocalDraft,
    );
  }

  Widget _buildCircuitRow(
    BuildContext context,
    TrainingEntity training,
    TrainingExerciseEntity ex,
    List<TrainingExerciseEntity> blockExercises,
    List<Map<String, dynamic>> actions,
  ) {
    final completedCount = blockExercises
        .where((blockExercise) => _progress.ids.contains(blockExercise.id))
        .length;
    return _CircuitCard(
      name: ex.blockName ?? 'Circuito',
      rounds: ex.blockRounds ?? 1,
      restBetweenRoundsSeconds: ex.restBetweenRoundsSeconds ?? 60,
      exerciseCount: blockExercises.length,
      completedCount: completedCount,
      syncState: circuitSyncState(
        [
          for (final blockExercise in blockExercises)
            _exerciseSync(actions, blockExercise, hasLocalDraft: false),
        ],
        allCompleted: completedCount == blockExercises.length,
      ),
      onFeedback: () {
        context.push(
          AppRoutes.feedback,
          extra: FeedbackPageArgs.circuit(
            circuitName: ex.blockName ?? 'Circuito',
            circuitExercises: blockExercises
                .map(
                  (blockExercise) => FeedbackExerciseTarget(
                    key: blockExercise.id,
                    exerciseId: blockExercise.exercise.id,
                    exerciseName: blockExercise.exercise.name,
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
      onStart: () => _startCircuit(context, training, ex, blockExercises),
      onMarkPending: completedCount == blockExercises.length
          ? () async {
              final sessionId = await _selectExecution(
                training, widget.state.selectedDate);
              if (!mounted || !context.mounted || !_sameSession || sessionId == null) return;
              for (final blockExercise in blockExercises) {
                context.read<TrainingBloc>().add(
                  MarkExerciseCompleted(
                    sessionId: sessionId,
                    sessionStamp: widget.sessionStamp,
                    trainingExerciseId: blockExercise.id,
                    exerciseId: blockExercise.exercise.id,
                    completed: false,
                  ),
                );
              }
            }
          : null,
    );
  }

  Widget _buildExerciseRow(
    BuildContext context,
    TrainingEntity training,
    TrainingExerciseEntity ex,
    List<Map<String, dynamic>> actions,
    _WeightText weightText,
  ) {
    final l10n = AppLocalizations.of(context);
    final isCompleted = _progress.ids.contains(ex.id);
    final storage = sl<LocalStorage>();
    final activeWorkout = _progressSessionId == null
        ? storage.recoverableLegacyWorkout(
            training.id, ex.id, widget.state.selectedDate)
        : storage.getActiveWorkout(
            '${ex.id}:${widget.state.selectedDate}:$_progressSessionId');
    final partialProgress =
        activeWorkout?.trainingId == training.id ? activeWorkout : null;
    final effectiveWeight =
        _progress.weights[ex.id] ?? partialProgress?.lastWeightKg;
    final hasPartialProgress = !isCompleted &&
        partialProgress != null &&
        partialProgress.completedSets > 0;
    final todaySets = _progress.performances[ex.id];
    final String? todayLabel;
    if (hasPartialProgress) {
      // RIR-only sets of earlier drafts are not registered (P3).
      final registered = partialProgress.completedSets -
          unregisteredSetNumbers(partialProgress.completedSets,
              partialProgress.completedSetData).length;
      final sets = l10n.trainingDetailSetsProgress(registered, ex.sets);
      todayLabel = effectiveWeight == null
          ? sets
          : '$sets · ${weightText(effectiveWeight)}';
    } else {
      final setsLabel = todaySets == null
          ? null
          : _todaySetsLabel(l10n, todaySets, weightText);
      todayLabel = setsLabel ??
          (isCompleted && effectiveWeight != null
              ? l10n.trainingDetailToday(weightText(effectiveWeight))
              : null);
    }

    return _ExerciseCard(
      trainingExercise: ex,
      trainingTypes: training.types,
      accentColorHex: training.accentColor,
      trainingLevel: training.level,
      isCompleted: isCompleted,
      weightUsed: effectiveWeight,
      weightText: weightText,
      currentPerformances: _progress.performances[ex.id],
      previousLabel: _previousLabel(
        l10n, widget.state.previousPerformances[ex.id], weightText),
      todayLabel: todayLabel,
      hasPartialProgress: hasPartialProgress,
      syncState: _exerciseSync(
        actions, ex, hasLocalDraft: hasPartialProgress),
      onOpenActive: () => _openActiveExercise(context, training, ex),
      onToggle: (val, {double? weightUsed}) {
        if (val && training.requiresLastSetVideo) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).completeLastSetOpenExercise,
              ),
            ),
          );
          return;
        }
        // Direct toggles still belong to a durable execution.
        _toggleExercise(training, ex, val, weightUsed);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final training = widget.state.training;
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final weightText = _WeightText.of(context);
    final completed = _progress.ids.length;
    final total = training.exercises.length;
    final allDone = total > 0 && completed == total;
    final storage = sl<LocalStorage>();
    final pendingActions = storage.getPendingSyncActions();
    final completionActions = pendingActions.where((action) =>
      action['type'] == 'complete_training' &&
      action['training_id'] == training.id &&
      action['date'] == widget.state.selectedDate).toList();
    final selectedCompletionId = widget.selectedExecutionId ?? _sessionId ??
        _locallyConfirmedSessionId ?? _displaySessionId;
    final sync = sl.isRegistered<OfflineSyncService>() ? sl<OfflineSyncService>() : null;
    final blocker = sync?.completionBlocker(training.id,
      widget.state.selectedDate, selectedCompletionId);
    final retryId = blocker?.retryActionId;
    final blockerLabel = switch (blocker?.kind) {
      CompletionSyncBlockerKind.conflict => l10n.trainingSyncConflict,
      CompletionSyncBlockerKind.receiptMissing => l10n.trainingSyncReceiptMissing,
      CompletionSyncBlockerKind.failed => retryId == null
          ? l10n.trainingSyncBlocked : l10n.trainingSyncFailed,
      CompletionSyncBlockerKind.feedbackMissing => l10n.trainingFeedbackMissing,
      CompletionSyncBlockerKind.feedbackFailed => l10n.trainingFeedbackFailed,
      CompletionSyncBlockerKind.feedbackWaiting => l10n.trainingFeedbackWaiting,
      null => null,
    };
    final pendingSync = completionActions.any((action) =>
      const ['queued', 'uploading'].contains(action['status']) &&
      action['training_session_id'] == selectedCompletionId);
    final executions = storage.getTrainingExecutions(
      training.id, widget.state.selectedDate);
    final needsConflictReview = completionActions.any((action) =>
      action['last_error'] == 'progress_conflict_review_required' &&
      (selectedCompletionId == null ||
        action['training_session_id'] == selectedCompletionId)) ||
        executions.any((entry) => entry['status'] == 'conflict' &&
          (selectedCompletionId == null || entry['id'] == selectedCompletionId));
    final hasFailedExecution = executions.any((entry) =>
      entry['status'] == 'failed' &&
      (_sessionId == null || entry['id'] == _sessionId));
    final writableCompletionId = widget.selectedExecutionId ?? _sessionId ?? _locallyConfirmedSessionId;
    final locallyCompleted = writableCompletionId != null &&
        storage.getConfirmedTrainingExecutions(training.id, widget.state.selectedDate)
            .any((entry) => entry['id'] == writableCompletionId &&
                const ['completed', 'confirmed'].contains(entry['status']));
    final activeWorkouts = sl<LocalStorage>().watchActiveWorkouts();
    final groups = _exerciseGroups(training);
    final next = _firstUnfinished(groups);

    // Status of the session completion next to its button (plan §6: pending
    // is amber + clock, failure is error colour + icon). A conflict keeps
    // today's treatment: only the button label.
    final ExomSyncStatus? completionStatus;
    if (needsConflictReview ||
        blocker?.kind == CompletionSyncBlockerKind.conflict) {
      completionStatus = null;
    } else if (blocker?.kind == CompletionSyncBlockerKind.feedbackWaiting) {
      completionStatus = const ExomSyncStatus(state: ExomSyncState.pendiente);
    } else if (blocker != null ||
        hasFailedExecution && !pendingSync && !locallyCompleted) {
      completionStatus = const ExomSyncStatus(state: ExomSyncState.fallida);
    } else if (pendingSync) {
      completionStatus = ExomSyncStatus(
        state: ExomSyncState.pendiente,
        label: l10n.trainingDetailCompletionSavedPending,
      );
    } else {
      completionStatus = null;
    }

    final completeOnPressed = widget.state.isCompleting || !_sameSession
        ? null
        : blocker?.kind == CompletionSyncBlockerKind.feedbackFailed &&
            sl.isRegistered<FeedbackUploadQueueService>()
            ? () async {
                if (!_sameSession) return;
                await Navigator.of(context).push<void>(MaterialPageRoute(
                  builder: (_) => PendingUploadsPage(
                    exerciseNames: {
                      for (final exercise in training.exercises)
                        exercise.id: exercise.exercise.name,
                    },
                  ),
                ));
                if (_sameSession) setState(() {});
              }
        : retryId != null && !locallyCompleted
            ? () async {
                if (!_sameSession) return;
                _completionReturnSessionId = selectedCompletionId;
                _completionAccepted = false;
                await sync!.retryAction(retryId);
                if (_sameSession) {
                  _completionAccepted = true;
                  setState(() {});
                  _returnAfterConfirmedCompletion();
                }
              }
            : pendingSync || blocker != null || needsConflictReview || locallyCompleted
                ? null : _completeSelectedTraining;
    final completeLabel = blockerLabel ?? (needsConflictReview ? l10n.trainingSyncConflict : pendingSync ? l10n.trainingPendingSync : locallyCompleted ? l10n.workoutCompletedMessage : hasFailedExecution ? l10n.trainingRetryCompletion : allDone && _sessionId != null
        ? l10n.workoutCompletedMessage
        : l10n.completeTrainingConfirmAction);
    // One lime action per state: "next" while work remains; once every
    // exercise is done the completion button takes the primary style.
    final completeIsPrimary = next == null;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: GlassAppBar(
        leading: _DetailBackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _DetailHeader(
            training: training,
            completedLabel: '$completed/$total ${l10n.completedExercisesLabel}',
          ),

          // Warmup
          if (training.warmupDescription != null) ...[
            _SectionTitle(title: l10n.warmUp),
            _DescriptionText(text: training.warmupDescription!),
          ],

          // Unscoped drafts are retained in Hive but never displayed as
          // this account's progress or submitted under its credentials.
          if (sl<LocalStorage>().hasQuarantinedWorkoutDrafts)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                AppLocalizations.of(context).quarantinedWorkoutNotice,
                key: const Key('quarantined-workout-notice'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  color: palette.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          // Exercise list: rule-separated rows straight under the header
          // (sketch «Detalle del entreno»); the header already counts them.
          for (final group in groups)
            ValueListenableBuilder(
              valueListenable: activeWorkouts,
              builder: (context, box, _) {
                final circuit = group.blockExercises;
                return circuit == null
                    ? _buildExerciseRow(
                        context, training, group.leader, pendingActions, weightText)
                    : _buildCircuitRow(
                        context,
                        training,
                        group.leader,
                        circuit,
                        pendingActions,
                      );
              },
            ),
          // Closing rule of the exercise list.
          Divider(height: 1, thickness: 1, color: palette.borderSoft),

          // Cooldown
          if (training.cooldownDescription != null) ...[
            _SectionTitle(title: l10n.cooldown),
            _DescriptionText(text: training.cooldownDescription!),
          ],

          if (widget.state.clientNote != null ||
              widget.state.adminReplyText != null)
            TrainingNoteReplyCard(
              note: widget.state.clientNote,
              reply: widget.state.adminReplyText,
              historicalDayNote: true,
            ),

          // Quick notes
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: TextField(
              controller: _notesController,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                color: palette.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: l10n.addQuickNoteOptional,
                hintStyle: TextStyle(color: palette.textSecondary),
                prefixIcon: Icon(
                  ExomIcons.editNote,
                  color: palette.textSecondary,
                ),
                filled: false,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: palette.textSecondary, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: palette.textPrimary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),

      // Pinned thumb-zone actions: the next exercise (lime) and the session
      // completion, which becomes the lime action once every exercise is done.
      bottomNavigationBar: ExomPinnedFooter(
        padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (completionStatus != null) ...[
                Align(alignment: Alignment.centerLeft, child: completionStatus),
                const SizedBox(height: 8),
              ],
              if (next != null) ...[
                ExomPrimaryButton(
                  key: const Key('training-next-button'),
                  label: l10n.trainingDetailNextAction(
                    next.blockExercises == null
                        ? next.leader.exercise.name
                        : next.leader.blockName ?? 'Circuito'),
                  trailingIcon: ExomIcons.forward,
                  busy: _openingNext,
                  onPressed: !_sameSession
                      ? null
                      : () => _runNext(() => next.blockExercises == null
                          ? _openActiveExercise(context, training, next.leader)
                          : _startCircuit(context, training, next.leader,
                              next.blockExercises!)),
                ),
                const SizedBox(height: 8),
              ],
              _CompleteTrainingButton(
                primary: completeIsPrimary,
                label: completeLabel,
                done: allDone,
                onPressed: completeOnPressed,
              ),
            ],
          ),
      ),
    );
  }
}

/// Formats kilograms in the user's unit for display only («62,5 kg»,
/// «137,79 lb»). Stored and sent values stay in kilograms (decision D5).
class _WeightText {
  const _WeightText(this.unitSystem, this.decimalSeparator);

  final UnitSystem unitSystem;
  final String decimalSeparator;

  /// Reads the unit preference when an [AppPreferencesCubit] is provided (it
  /// always is in the app, `lib/main.dart`); widget tests that pump the page
  /// alone fall back to kilograms, today's only unit.
  factory _WeightText.of(BuildContext context) {
    UnitSystem unitSystem;
    try {
      unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
        (cubit) => cubit.state.unitSystem,
      );
    } on ProviderNotFoundException {
      unitSystem = UnitSystem.metric;
    }
    return _WeightText(
      unitSystem,
      decimalSeparatorFor(Localizations.localeOf(context).languageCode),
    );
  }

  String call(double kg) =>
      '${formatWeightDisplay(kg, unitSystem, decimalSeparator: decimalSeparator)}'
      '\u00A0${weightUnitSymbol(unitSystem)}';
}

/// «8 × 60 kg», «45 s · 20 kg», «12 reps.» for one logged set.
String? _setValueLabel(
  AppLocalizations l10n,
  SetPerformance set,
  _WeightText weightText,
) {
  final weight = set.weightKg == null ? null : weightText(set.weightKg!);
  if (set.reps != null && weight != null) {
    return '${set.reps} × $weight';
  }
  final parts = [
    if (set.reps != null) l10n.trainingDetailReps(set.reps!),
    if (set.seconds != null) '${set.seconds} s',
    ?weight,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// «Anterior 8 × 60 kg» from the first logged set of the previous session.
String? _previousLabel(
  AppLocalizations l10n,
  List<SetPerformance>? previous,
  _WeightText weightText,
) {
  if (previous == null || previous.isEmpty) return null;
  final sorted = [...previous]
    ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
  for (final set in sorted) {
    final value = _setValueLabel(l10n, set, weightText);
    if (value != null) return l10n.trainingDetailPrevious(value);
  }
  return null;
}

/// «Hoy 4 series · 8 reps. · 62,5 kg» when every set of today is equal,
/// otherwise each set («Hoy 8 reps. · 60 kg | 6 reps. · 62,5 kg»).
String? _todaySetsLabel(
  AppLocalizations l10n,
  List<SetPerformance> sets,
  _WeightText weightText,
) {
  final labels = sets
      .map((set) => _todaySetLabel(l10n, set, weightText))
      .where((label) => label.isNotEmpty)
      .toList(growable: false);
  if (labels.isEmpty) return null;
  if (labels.length > 1 && labels.every((label) => label == labels.first)) {
    return l10n.trainingDetailToday(
      '${l10n.trainingDetailSets(labels.length)} · ${labels.first}');
  }
  return l10n.trainingDetailToday(labels.join(' | '));
}

/// One registered set of today in the exercise sheet, in the user's unit.
String _todaySetLabel(
  AppLocalizations l10n,
  SetPerformance set,
  _WeightText weightText,
) {
  final parts = [
    if (set.reps != null) l10n.trainingDetailReps(set.reps!),
    if (set.seconds != null) '${set.seconds} s',
    if (set.weightKg != null) weightText(set.weightKg!),
    if (set.rir != null) 'RIR ${set.rir}',
  ];
  return parts.join(' · ');
}

class TrainingNoteReplyCard extends StatelessWidget {
  const TrainingNoteReplyCard({super.key, this.note, this.reply,
    this.historicalDayNote = false});

  final String? note;
  final String? reply;
  final bool historicalDayNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null) ...[
            Row(
              children: [
                Icon(
                  ExomIcons.note,
                  size: 18,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    historicalDayNote
                        ? AppLocalizations.of(context).historicalDayNoteUnattributed
                        : AppLocalizations.of(context).yourTrainingNote,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(note!, style: theme.textTheme.bodyMedium),
          ],
          if (note != null && reply != null) const SizedBox(height: 16),
          if (reply != null) ...[
            Row(
              children: [
                Icon(
                  ExomIcons.chatRead,
                  size: 18,
                  color: palette.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).trainerReply,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(reply!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

BoxDecoration _trainingStickyBarDecoration(BuildContext context) {
  final palette = context.exomPalette;
  return BoxDecoration(
    color: palette.background,
    border: Border(top: BorderSide(color: palette.borderSoft, width: 1)),
  );
}

/// Back button of the detail with the platform's localized tooltip, which is
/// also its accessible label (L0 found it unlabeled).
class _DetailBackButton extends StatelessWidget {
  const _DetailBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(ExomIcons.back, color: context.exomPalette.textPrimary),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed,
    );
  }
}

/// Flat top of the detail (sketch «Detalle del entreno»): training name in
/// the display face, then muted meta lines and the progress line.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.training, required this.completedLabel});

  final TrainingEntity training;
  final String completedLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    // Same rule as Inicio (circuit exercises weigh sets x rounds).
    final totalSets = tallyPlannedSets(
      training.exercises,
      plannedSets: (item) => plannedSetsOf(
        sets: item.sets,
        inBlock: item.blockId != null,
        blockRounds: item.blockRounds,
      ),
      isCompleted: (_) => false,
    ).total;
    final duration = training.estimatedDurationMin;
    final kind = [
      ...trainingTypeLabels(context, training.types),
      if (training.level.trim().isNotEmpty)
        _trainingLevelLabel(l10n, training.level),
    ].join(' · ');
    final volume = [
      l10n.trainingDetailExercises(training.exercises.length),
      l10n.trainingDetailSets(totalSets),
      if (duration != null) l10n.trainingDetailDuration(duration),
      if (training.estimatedCalories != null)
        '${training.estimatedCalories} kcal',
    ].join(' · ');
    final mutedStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      color: palette.textSecondary,
      fontSize: 14,
      height: 1.4,
    );
    final titleStyle = TextStyle(
      fontFamily: AppTheme.displayFontFamily,
      fontSize: 44,
      fontWeight: FontWeight.w800,
      height: 0.95,
      letterSpacing: -0.88,
      color: palette.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'training-${training.id}-title',
            flightShuttleBuilder: (flightCtx, anim, dir, fromCtx, toCtx) {
              return Material(
                color: Colors.transparent,
                child: Text(
                  training.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.374,
                  ),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Semantics(
                header: true,
                child: Text(training.name.toUpperCase(), style: titleStyle),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (kind.isNotEmpty) Text(kind, style: mutedStyle),
          Text(volume, style: mutedStyle),
          if (training.tags.isNotEmpty)
            Text(
              training.tags.map((tag) => '#$tag').join(' '),
              style: mutedStyle.copyWith(fontSize: 13),
            ),
          const SizedBox(height: 12),
          Text(
            completedLabel,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Session completion action. Keeps the [ElevatedButton] and the
/// `complete-training-button` key the tests drive; it takes the primary
/// (lime) look only when it is the next step, otherwise the outlined
/// secondary look, so the screen never shows two lime actions.
class _CompleteTrainingButton extends StatelessWidget {
  const _CompleteTrainingButton({
    required this.primary,
    required this.label,
    required this.done,
    required this.onPressed,
  });

  final bool primary;
  final String label;
  final bool done;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    );
    const textStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0.32,
    );
    final style = primary
        ? ElevatedButton.styleFrom(
            elevation: 0,
            shape: shape,
            minimumSize: const Size.fromHeight(kExomButtonMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: textStyle,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            iconColor: AppColors.textOnPrimary,
            disabledBackgroundColor: palette.borderSoft,
            disabledForegroundColor:
                isDark ? palette.textDisabled : palette.textSecondary,
            disabledIconColor:
                isDark ? palette.textDisabled : palette.textSecondary,
            side: isDark || onPressed == null
                ? null
                : const BorderSide(color: AppColors.textOnPrimary, width: 1.5),
          )
        : ElevatedButton.styleFrom(
            elevation: 0,
            shape: shape,
            minimumSize: const Size.fromHeight(kExomButtonMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: textStyle,
            backgroundColor: Colors.transparent,
            foregroundColor: palette.textPrimary,
            iconColor: palette.textPrimary,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: palette.textDisabled,
            disabledIconColor: palette.textDisabled,
            shadowColor: Colors.transparent,
            side: BorderSide(
              color: onPressed == null ? palette.borderSoft : palette.textPrimary,
              width: 1.5,
            ),
          );
    return ElevatedButton.icon(
      key: const Key('complete-training-button'),
      onPressed: onPressed,
      style: style,
      icon: Icon(
        done ? ExomIcons.done : ExomIcons.complete,
        size: 20,
      ),
      label: Text(label),
    );
  }
}

/// Section heading (warm-up, exercises, cool-down): display face, uppercase.
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: AppTheme.displayFontFamily,
            color: palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// Warm-up / cool-down text, flat on the page (no card).
class _DescriptionText extends StatelessWidget {
  final String text;

  const _DescriptionText({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.bodyFontFamily,
          color: palette.textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Rule-separated list row: hairline on top, full-width tap target, at least
/// 56 high. The list closes with a [Divider] after the last row.
class _RuledRow extends StatelessWidget {
  const _RuledRow({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.exomPalette.borderSoft),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _rowNameStyle(BuildContext context, {required bool done}) =>
    TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      color: done
          ? context.exomPalette.textSecondary
          : context.exomPalette.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );

TextStyle _rowLineStyle(BuildContext context, {Color? color}) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  color: color ?? context.exomPalette.textSecondary,
  fontSize: 14,
  height: 1.4,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Trailing mark of a row: a check in text colour when done (never lime), a
/// chevron otherwise.
class _RowTrailing extends StatelessWidget {
  const _RowTrailing({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(
        done ? ExomIcons.check : ExomIcons.next,
        color: done ? palette.textPrimary : palette.textSecondary,
        size: 24,
      ),
    );
  }
}

class _CircuitCard extends StatelessWidget {
  final String name;
  final int rounds;
  final int restBetweenRoundsSeconds;
  final int exerciseCount;
  final int completedCount;
  final ExomSyncState? syncState;
  final VoidCallback onFeedback;
  final VoidCallback onStart;
  final VoidCallback? onMarkPending;

  const _CircuitCard({
    required this.name,
    required this.rounds,
    required this.restBetweenRoundsSeconds,
    required this.exerciseCount,
    required this.completedCount,
    required this.syncState,
    required this.onFeedback,
    required this.onStart,
    required this.onMarkPending,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final isCompleted = exerciseCount > 0 && completedCount == exerciseCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RuledRow(
          onTap: onStart,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: ExcludeSemantics(
                  child: Icon(
                    ExomIcons.repeat,
                    color: palette.textSecondary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: _rowNameStyle(context, done: isCompleted)),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.circuitSummary(rounds, exerciseCount)} · '
                      '${restBetweenRoundsSeconds}s ${l10n.rest}',
                      style: _rowLineStyle(context),
                    ),
                    if (syncState != null) ...[
                      const SizedBox(height: 4),
                      ExomSyncStatus(state: syncState!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$completedCount/$exerciseCount',
                style: _rowLineStyle(context, color: palette.textPrimary),
              ),
              _RowTrailing(done: isCompleted),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 12, 8),
          child: Row(
            children: [
              Flexible(
                child: TextButton.icon(
                  key: const ValueKey('circuit-feedback-button'),
                  onPressed: onFeedback,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.textPrimary,
                    minimumSize: const Size(kExomMinTapTarget, kExomMinTapTarget),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(ExomIcons.videoLibrary, size: 20),
                  label: Text(l10n.circuitFeedbackAction),
                ),
              ),
              if (onMarkPending != null) ...[
                const Spacer(),
                IconButton(
                  onPressed: onMarkPending,
                  color: palette.textPrimary,
                  icon: const Icon(ExomIcons.radioOff),
                  tooltip: l10n.markCircuitPendingButton,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final TrainingExerciseEntity trainingExercise;
  final List<String> trainingTypes;
  final String? accentColorHex;
  final String trainingLevel;
  final bool isCompleted;
  final double? weightUsed;
  final _WeightText weightText;
  final List<SetPerformance>? currentPerformances;
  final String? previousLabel;
  final String? todayLabel;
  final bool hasPartialProgress;
  final ExomSyncState? syncState;
  final VoidCallback onOpenActive;
  final void Function(bool completed, {double? weightUsed}) onToggle;

  const _ExerciseCard({
    required this.trainingExercise,
    required this.trainingTypes,
    required this.accentColorHex,
    required this.trainingLevel,
    required this.isCompleted,
    required this.weightText,
    required this.onOpenActive,
    required this.onToggle,
    this.weightUsed,
    this.currentPerformances,
    this.previousLabel,
    this.todayLabel,
    this.hasPartialProgress = false,
    this.syncState,
  });

  @override
  Widget build(BuildContext context) {
    final ex = trainingExercise.exercise;
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final thumbnailUrl = ex.thumbnailUrl?.trim();
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    const thumbnailSize = 56.0;

    return _RuledRow(
      onTap: () => _showExerciseDetail(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${trainingExercise.order}',
              style: TextStyle(
                fontFamily: AppTheme.displayFontFamily,
                color: isCompleted ? palette.textSecondary : palette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ex.name, style: _rowNameStyle(context, done: isCompleted)),
                const SizedBox(height: 2),
                Text(
                  l10n.trainingDetailPrescription(
                    trainingExercise.sets,
                    formatExercisePrescription(trainingExercise),
                    trainingExercise.restSeconds,
                  ),
                  style: _rowLineStyle(context),
                ),
                if (previousLabel != null)
                  Text(previousLabel!, style: _rowLineStyle(context)),
                if (todayLabel != null)
                  Text(
                    todayLabel!,
                    style: _rowLineStyle(context, color: palette.textPrimary),
                  ),
                if (syncState != null) ...[
                  const SizedBox(height: 4),
                  ExomSyncStatus(state: syncState!),
                ],
              ],
            ),
          ),
          if (hasThumbnail) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: thumbnailUrl,
                width: thumbnailSize,
                height: thumbnailSize,
                fit: BoxFit.cover,
                memCacheWidth: PerformanceProfile.imageCacheWidth(
                  context,
                  thumbnailSize,
                ),
                placeholder: (context, imageUrl) => _ThumbnailBackground(),
                errorWidget: (context, imageUrl, error) =>
                    _ThumbnailBackground(),
              ),
            ),
          ],
          _RowTrailing(done: isCompleted),
        ],
      ),
    );
  }

  void _showExerciseDetail(BuildContext context) async {
    final ex = trainingExercise.exercise;
    final result = await showPageAwareModalBottomSheet<_SheetCompletionResult>(
      context: context,
      backgroundColor: context.exomPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => _ExerciseDetailSheet(
          exercise: ex,
          trainingExercise: trainingExercise,
          scrollController: scrollController,
          isCompleted: isCompleted,
          weightUsed: weightUsed,
          weightText: weightText,
          trainingTypes: trainingTypes,
          accentColorHex: accentColorHex,
          trainingLevel: trainingLevel,
          hasPartialProgress: hasPartialProgress,
          currentPerformances: currentPerformances,
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    if (result.openFeedback) {
      GoRouter.of(context).push(
        AppRoutes.feedback,
        extra: FeedbackPageArgs.exercise(
          FeedbackExerciseTarget(
            key: trainingExercise.id,
            exerciseId: ex.id,
            exerciseName: ex.name,
          ),
        ),
      );
      return;
    }

    if (result.markPending) {
      onToggle(false);
      return;
    }

    if (result.openActiveExercise) {
      onOpenActive();
    }
  }
}

class _SheetCompletionResult {
  final bool openFeedback;
  final bool markPending;
  final bool openActiveExercise;

  const _SheetCompletionResult({
    this.openFeedback = false,
    this.markPending = false,
    this.openActiveExercise = false,
  });
}

/// Neutral square behind a loading or broken thumbnail.
class _ThumbnailBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.exomPalette.surfaceVariant,
      child: const SizedBox(width: 56, height: 56),
    );
  }
}

/// Localized label of a training level as sent by the API (same values as
/// onboarding: English enum or Spanish name); an unknown value is shown as is.
String _trainingLevelLabel(AppLocalizations l10n, String level) =>
    switch (level.trim().toUpperCase()) {
      'BEGINNER' || 'PRINCIPIANTE' => l10n.beginnerLevel,
      'INTERMEDIATE' || 'INTERMEDIO' => l10n.intermediateLevel,
      'ADVANCED' || 'AVANZADO' => l10n.advancedLevel,
      _ => level,
    };

class _ExerciseDetailSheet extends StatelessWidget {
  final ExerciseEntity exercise;
  final TrainingExerciseEntity trainingExercise;
  final ScrollController scrollController;
  final bool isCompleted;
  final double? weightUsed;
  final _WeightText weightText;
  final List<String> trainingTypes;
  final String? accentColorHex;
  final String trainingLevel;
  final bool hasPartialProgress;
  final List<SetPerformance>? currentPerformances;

  const _ExerciseDetailSheet({
    required this.exercise,
    required this.trainingExercise,
    required this.scrollController,
    required this.isCompleted,
    required this.weightText,
    required this.trainingTypes,
    required this.accentColorHex,
    required this.trainingLevel,
    this.weightUsed,
    this.hasPartialProgress = false,
    this.currentPerformances,
  });

  Color _typeColor(BuildContext context) {
    return trainingAccentColor(
      context,
      accentColor: accentColorHex,
      types: trainingTypes,
    );
  }

  String _buildMetadata(AppLocalizations l10n) {
    return l10n.exerciseMetadata(
      trainingExercise.sets,
      formatExercisePrescription(trainingExercise),
      trainingExercise.restSeconds,
    );
  }

  bool _hasContent(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  List<String> _extractBulletItems(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [];

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length > 1) {
      return lines.map(_stripBulletPrefix).toList();
    }

    if (normalized.contains('\u2022')) {
      final inlineItems = normalized
          .split('\u2022')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map(_stripBulletPrefix)
          .toList();
      if (inlineItems.length > 1) {
        return inlineItems;
      }
    }

    return const [];
  }

  String _stripBulletPrefix(String value) {
    return value
        .replaceFirst(RegExp(r'^[-*\u2022]+\s*'), '')
        .replaceFirst(RegExp(r'^\d+[.)-]?\s*'), '')
        .trim();
  }

  Future<void> _openVideo(BuildContext context) async {
    final videoUrl = exercise.videoUrl?.trim();
    if (videoUrl == null || videoUrl.isEmpty) return;

    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ExerciseVideoPlayerPage(title: exercise.name, videoUri: uri),
      ),
    );
  }

  void _openFeedback(BuildContext context) {
    Navigator.of(context).pop(const _SheetCompletionResult(openFeedback: true));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final typeColor = _typeColor(context);
    final thumbnailUrl = exercise.thumbnailUrl?.trim();
    final videoUrl = exercise.videoUrl?.trim();
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final muscleGroups = exercise.muscleGroups
        .map((group) => group.trim())
        .where((group) => group.isNotEmpty)
        .toList();
    final weightLabel = weightUsed == null ? null : weightText(weightUsed!);
    final currentPerformanceLabels =
        (currentPerformances ?? const <SetPerformance>[])
            .map((set) => _todaySetLabel(l10n, set, weightText))
            .where((label) => label.isNotEmpty)
            .toList(growable: false);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: palette.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: _SheetHeaderAction(
                  icon: ExomIcons.feedback,
                  label: l10n.feedbackSendFromExercise,
                  onTap: () => _openFeedback(context),
                  tooltip: l10n.feedbackSendFromExercise,
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: _SheetHeaderAction(
                  icon: ExomIcons.close,
                  onTap: () => Navigator.of(context).pop(),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  highlighted: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          exercise.name,
          style: TextStyle(
            fontFamily: AppTheme.bodyFontFamily,
            color: palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _buildMetadata(l10n),
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Divider(color: palette.divider, height: 1),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: ExomIcons.streak,
              label: _trainingLevelLabel(l10n, trainingLevel),
              color: typeColor,
              emphasized: true,
            ),
            if (muscleGroups.isNotEmpty)
              _InfoChip(
                icon: ExomIcons.target,
                label: muscleGroups.join(', '),
                color: palette.textSecondary,
                maxWidth: MediaQuery.sizeOf(context).width - 128,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasVideo ? () => _openVideo(context) : null,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              height: 196,
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.borderSoft),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: hasThumbnail
                          ? CachedNetworkImage(
                              imageUrl: thumbnailUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: PerformanceProfile.imageCacheWidth(
                                context,
                                MediaQuery.sizeOf(context).width,
                              ),
                              placeholder: (context, imageUrl) =>
                                  Container(color: palette.surfaceVariant),
                              errorWidget: (context, imageUrl, error) =>
                                  Container(
                                    color: palette.surfaceVariant,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      ExomIcons.train,
                                      color: palette.textDisabled,
                                      size: 44,
                                    ),
                                  ),
                            )
                          : Container(
                              color: palette.surfaceVariant,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    ExomIcons.train,
                                    color: palette.textDisabled,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    l10n.video,
                                    style: TextStyle(
                                      color: palette.textDisabled,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  if (hasVideo)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.borderSoft),
                      ),
                      child: Icon(
                        ExomIcons.play,
                        color: palette.textPrimary,
                        size: 44,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (weightLabel != null) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _InfoChip(
              icon: ExomIcons.train,
              label: weightLabel,
              color: palette.textPrimary,
              emphasized: true,
            ),
          ),
        ],
        if (currentPerformanceLabels.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceVariant.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).registeredSetsToday,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final label in currentPerformanceLabels)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_hasContent(exercise.techniqueText)) ...[
          const SizedBox(height: 24),
          _VisibleDetailSection(
            title: l10n.technique,
            text: exercise.techniqueText!,
            bulletItems: _extractBulletItems(exercise.techniqueText!),
          ),
        ],
        if (_hasContent(exercise.commonErrorsText)) ...[
          const SizedBox(height: 20),
          _VisibleDetailSection(
            title: l10n.commonMistakes,
            text: exercise.commonErrorsText!,
            bulletItems: _extractBulletItems(exercise.commonErrorsText!),
          ),
        ],
        if (_hasContent(exercise.explanationText)) ...[
          const SizedBox(height: 20),
          _VisibleDetailSection(
            title: l10n.explanation,
            text: exercise.explanationText!,
            bulletItems: _extractBulletItems(exercise.explanationText!),
          ),
        ],
        if (isCompleted) ...[
          const SizedBox(height: 28),
          ExomSecondaryButton(
            icon: ExomIcons.editNote,
            label: AppLocalizations.of(context).editData,
            onPressed: () {
              Navigator.of(
                context,
              ).pop(const _SheetCompletionResult(openActiveExercise: true));
            },
          ),
          const SizedBox(height: 8),
          ExomQuietButton(
            label: l10n.markExercisePendingButton,
            onPressed: () {
              Navigator.of(
                context,
              ).pop(const _SheetCompletionResult(markPending: true));
            },
          ),
        ] else ...[
          const SizedBox(height: 28),
          ExomSecondaryButton(
            icon: ExomIcons.play,
            label: hasPartialProgress
                ? l10n.resumeExerciseButton
                : l10n.startExerciseButton,
            onPressed: () {
              Navigator.of(
                context,
              ).pop(const _SheetCompletionResult(openActiveExercise: true));
            },
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SheetHeaderAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final String tooltip;
  final bool highlighted;

  const _SheetHeaderAction({
    required this.icon,
    this.label,
    required this.onTap,
    required this.tooltip,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final hasLabel = label != null && label!.trim().isNotEmpty;

    return Material(
      color: highlighted
          ? palette.surfaceVariant.withValues(alpha: 0.9)
          : palette.surface.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        child: Tooltip(
          message: tooltip,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: hasLabel ? 12 : 10,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: highlighted
                          ? palette.textPrimary
                          : palette.textSecondary,
                      size: 18,
                    ),
                    if (hasLabel) ...[
                      const SizedBox(width: 6),
                      Text(
                        label!,
                        style: TextStyle(
                          color: highlighted
                              ? palette.textPrimary
                              : palette.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;
  final double? maxWidth;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.emphasized = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasized ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          if (maxWidth != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: labelText,
            )
          else
            labelText,
        ],
      ),
    );
  }
}

class _VisibleDetailSection extends StatelessWidget {
  final String title;
  final String text;
  final List<String> bulletItems;

  const _VisibleDetailSection({
    required this.title,
    required this.text,
    required this.bulletItems,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: palette.divider, height: 1),
        const SizedBox(height: 12),
        if (bulletItems.isNotEmpty)
          ...bulletItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (bulletItems.isEmpty)
          Text(
            text.trim(),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
      ],
    );
  }
}

/// One scroll row of the exercise list: a single exercise, or the first
/// member of a circuit together with all of its sorted members.
class _ExerciseRowGroup {
  const _ExerciseRowGroup(this.leader, [this.blockExercises]);

  final TrainingExerciseEntity leader;
  final List<TrainingExerciseEntity>? blockExercises;
}
