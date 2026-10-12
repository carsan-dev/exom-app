import 'dart:async';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/navigation/page_aware_bottom_sheet.dart';
import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/utils/training_type_utils.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
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
              content: Text(state.errorMessage!),
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
              title: const Text('Error'),
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
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: context.exomPalette.textPrimary,
            ),
            onPressed: () => context.pop(),
          ),
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
    String? selected;
    if (pending.isNotEmpty || legacy || hasPendingSync || hasCompleted) {
      selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Select training execution'),
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
                  title: const Text('Recover saved exercise draft'),
                  subtitle: const Text('Restore saved sets in a new execution'),
                  onTap: () => Navigator.of(dialogContext).pop('recover'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop('new'),
                child: const Text('New execution')),
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

  Color _trainingColor(BuildContext context, TrainingEntity training) {
    return trainingAccentColor(
      context,
      accentColor: training.accentColor,
      types: training.types,
    );
  }

  @override
  Widget build(BuildContext context) {
    final training = widget.state.training;
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final color = _trainingColor(context, training);
    final solidColorStyle = trainingColorStyle(context, color);
    final typeLabels = trainingTypeLabels(context, training.types);
    final completed = _progress.ids.length;
    final total = training.exercises.length;
    final progress = total > 0 ? completed / total : 0.0;
    final allDone = total > 0 && completed == total;
    final storage = sl<LocalStorage>();
    final completionActions = storage.getPendingSyncActions().where((action) =>
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
    final remaining = training.remainingProgress(
      _progress.ids,
    );

    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: palette.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: Hero(
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
              child: Text(
                training.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        body: SizedBox.expand(
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.only(
                  bottom: 160 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  // Header card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: GlassDecoration.accentCard(color),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ...typeLabels.map(
                              (label) => _Badge(label: label, color: color),
                            ),
                            _Badge(
                              label: training.level,
                              color: palette.textSecondary,
                            ),
                            if (allDone)
                              _Badge(
                                label: l10n.completed,
                                icon: Icons.check_circle_outline,
                                color: semantic.success,
                              )
                            else ...[
                              _Badge(
                                label: l10n.remainingTrainingWork(
                                  remaining.remainingExercises,
                                  remaining.remainingSets,
                                ),
                                icon: Icons.fitness_center,
                                color: color,
                              ),
                              if (remaining.remainingDurationMin != null)
                                _Badge(
                                  label: l10n.remainingTrainingMinutes(
                                    remaining.remainingDurationMin!,
                                  ),
                                  icon: Icons.timer_outlined,
                                  color: semantic.info,
                                ),
                            ],
                            if (training.estimatedCalories != null)
                              _Badge(
                                label: '${training.estimatedCalories} kcal',
                                icon: Icons.local_fire_department_outlined,
                                color: semantic.calorie,
                              ),
                          ],
                        ),
                        if (training.tags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            children: training.tags
                                .map(
                                  (t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '#$t',
                                      style: TextStyle(
                                        color: palette.textDisabled,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Warmup
                  if (training.warmupDescription != null) ...[
                    _SectionTitle(
                      title: l10n.warmUp,
                      icon: Icons.whatshot_outlined,
                      color: semantic.warning,
                    ),
                    _DescriptionCard(text: training.warmupDescription!),
                  ],

                  // Unscoped drafts are retained in Hive but never displayed as
                  // this account's progress or submitted under its credentials.
                  if (sl<LocalStorage>().hasQuarantinedWorkoutDrafts)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Saved workout data from an unknown account or date is kept on this device. It cannot be restored automatically; contact support to recover it.',
                        key: Key('quarantined-workout-notice'),
                      ),
                    ),
                  // Exercises section
                  _SectionTitle(
                    title: l10n.exercises,
                    icon: Icons.fitness_center,
                    color: color,
                    trailing: '$total ${l10n.exercises}',
                  ),
                  ValueListenableBuilder(
                    valueListenable: sl<LocalStorage>().watchActiveWorkouts(),
                    builder: (context, box, _) {
                      final cards = <Widget>[];
                      String? currentBlockId;
                      for (
                        var index = 0;
                        index < training.exercises.length;
                        index++
                      ) {
                        final ex = training.exercises[index];
                        if (ex.blockId != null) {
                          if (ex.blockId == currentBlockId) {
                            continue;
                          }
                          currentBlockId = ex.blockId;
                          final blockExercises =
                              training.exercises
                                  .where(
                                    (candidate) =>
                                        candidate.blockId == ex.blockId,
                                  )
                                  .toList()
                                ..sort(
                                  (left, right) =>
                                      (left.positionInBlock ?? left.order)
                                          .compareTo(
                                            right.positionInBlock ??
                                                right.order,
                                          ),
                                );
                          final completedCount = blockExercises
                              .where(
                                (blockExercise) => _progress.ids.contains(blockExercise.id),
                              )
                              .length;
                          final blockId = ex.blockId!;
                          cards.add(
                            _CircuitCard(
                              name: ex.blockName ?? 'Circuito',
                              rounds: ex.blockRounds ?? 1,
                              restBetweenRoundsSeconds:
                                  ex.restBetweenRoundsSeconds ?? 60,
                              exerciseCount: blockExercises.length,
                              completedCount: completedCount,
                              color: color,
                              onFeedback: () {
                                context.push(
                                  AppRoutes.feedback,
                                  extra: FeedbackPageArgs.circuit(
                                    circuitName: ex.blockName ?? 'Circuito',
                                    circuitExercises: blockExercises
                                        .map(
                                          (blockExercise) =>
                                              FeedbackExerciseTarget(
                                                key: blockExercise.id,
                                                exerciseId:
                                                    blockExercise.exercise.id,
                                                exerciseName:
                                                    blockExercise.exercise.name,
                                              ),
                                        )
                                        .toList(growable: false),
                                  ),
                                );
                              },
                              onStart: () async {
                                final sessionId = await _selectExecution(
                                  training, widget.state.selectedDate);
                                if (!mounted || !context.mounted || !_sameSession || sessionId == null) return;
                                context.push(
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
                                      for (final blockExercise
                                          in blockExercises)
                                        if (widget
                                                .state
                                                .previousPerformances[blockExercise
                                                .id] !=
                                            null)
                                          blockExercise.id:
                                              widget
                                                  .state
                                                  .previousPerformances[blockExercise
                                                  .id]!,
                                    },
                                    requiresLastSetVideo:
                                        training.requiresLastSetVideo,
                                    assignmentDate: widget.state.selectedDate,
                                  ),
                                );
                              },
                              onMarkPending:
                                  completedCount == blockExercises.length
                                  ? () async {
                                      final sessionId = await _selectExecution(
                                        training, widget.state.selectedDate);
                                      if (!mounted || !context.mounted || !_sameSession || sessionId == null) return;
                                      for (final blockExercise
                                          in blockExercises) {
                                        context.read<TrainingBloc>().add(
                                          MarkExerciseCompleted(
                                            sessionId: sessionId,
                                            sessionStamp: widget.sessionStamp,
                                            trainingExerciseId:
                                                blockExercise.id,
                                            exerciseId:
                                                blockExercise.exercise.id,
                                            completed: false,
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          );
                          continue;
                        }
                        final isCompleted = _progress.ids.contains(ex.id);
                        final storage = sl<LocalStorage>();
                        final activeWorkout = _progressSessionId == null
                            ? storage.recoverableLegacyWorkout(
                                training.id, ex.id, widget.state.selectedDate)
                            : storage.getActiveWorkout(
                                '${ex.id}:${widget.state.selectedDate}:$_progressSessionId');
                        final partialProgress =
                            activeWorkout?.trainingId == training.id
                            ? activeWorkout
                            : null;
                        final effectiveWeight =
                            _progress.weights[ex.id] ??
                            partialProgress?.lastWeightKg;
                        final partialProgressLabel =
                            !isCompleted &&
                                partialProgress != null &&
                                partialProgress.completedSets > 0
                            ? l10n.exerciseSeriesProgress(
                                partialProgress.completedSets,
                                ex.sets,
                              )
                            : null;

                        cards.add(
                          _ExerciseCard(
                            trainingExercise: ex,
                            trainingTypes: training.types,
                            accentColorHex: training.accentColor,
                            trainingLevel: training.level,
                            isCompleted: isCompleted,
                            weightUsed: effectiveWeight,
                            currentPerformances:
                                _progress.performances[ex.id],
                            partialProgressLabel: partialProgressLabel,
                            onOpenActive: () async {
                              final sessionId = await _selectExecution(
                                training, widget.state.selectedDate,
                                legacyExerciseId: ex.id);
                              if (!mounted || !context.mounted || !_sameSession || sessionId == null) return;
                              final selectedProgress = widget.state.sessionProgress[sessionId]
                                  ?? const TrainingDayProgress();
                              context.push(
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
                            },
                            onToggle: (val, {double? weightUsed}) {
                              if (val && training.requiresLastSetVideo) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Abre el ejercicio para completar la última serie y adjuntar su vídeo.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              // Direct toggles still belong to a durable execution.
                              _toggleExercise(training, ex, val, weightUsed);
                            },
                          ),
                        );
                      }

                      return Column(children: cards);
                    },
                  ),

                  // Cooldown
                  if (training.cooldownDescription != null) ...[
                    _SectionTitle(
                      title: l10n.cooldown,
                      icon: Icons.ac_unit_outlined,
                      color: semantic.info,
                    ),
                    _DescriptionCard(text: training.cooldownDescription!),
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.addQuickNoteOptional,
                        hintStyle: TextStyle(color: palette.textDisabled),
                        prefixIcon: Icon(
                          Icons.edit_note,
                          color: palette.textDisabled,
                        ),
                        filled: true,
                        fillColor: palette.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom bar: progress + Completar button
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completed/$total ${l10n.completedExercisesLabel}',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: (allDone ? semantic.success : color)
                                  .withValues(alpha: 0.20),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: palette.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              allDone ? semantic.success : color,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('complete-training-button'),
                          onPressed: widget.state.isCompleting || !_sameSession
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
                                      ? null : _completeSelectedTraining,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allDone ? semantic.success : color,
                            foregroundColor: allDone
                                ? palette.onPrimary
                                : solidColorStyle.foreground,
                            side: allDone
                                ? null
                                : BorderSide(color: solidColorStyle.border),
                          ),
                          icon: Icon(
                            allDone
                                ? Icons.check_circle_outline
                                : Icons.done_outline,
                            size: 18,
                          ),
                          label: Text(
                            blockerLabel ?? (needsConflictReview ? l10n.trainingSyncConflict : pendingSync ? l10n.trainingPendingSync : locallyCompleted ? l10n.workoutCompletedMessage : hasFailedExecution ? l10n.trainingRetryCompletion : allDone && _sessionId != null
                                ? l10n.workoutCompletedMessage
                                : l10n.completeTrainingConfirmAction),
                          ),
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
    );
  }
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
                  Icons.sticky_note_2_outlined,
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
                  Icons.mark_chat_read_outlined,
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
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return BoxDecoration(
    color: isDark ? AppColors.navBarGlass : AppColors.navBarGlassLightTheme,
    border: Border(
      top: BorderSide(
        color: palette.glassBorder.withValues(alpha: isDark ? 0.18 : 0.10),
        width: 0.6,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
        blurRadius: 24,
        offset: const Offset(0, -6),
        spreadRadius: -14,
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? trailing;

  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing!,
              style: TextStyle(color: palette.textDisabled, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final String text;

  const _DescriptionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: GlassDecoration.card(borderRadius: 14),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
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
  final Color color;
  final VoidCallback onFeedback;
  final VoidCallback onStart;
  final VoidCallback? onMarkPending;

  const _CircuitCard({
    required this.name,
    required this.rounds,
    required this.restBetweenRoundsSeconds,
    required this.exerciseCount,
    required this.completedCount,
    required this.color,
    required this.onFeedback,
    required this.onStart,
    required this.onMarkPending,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final solidColorStyle = trainingColorStyle(context, color);
    final isCompleted = exerciseCount > 0 && completedCount == exerciseCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: isCompleted
          ? BoxDecoration(
              color: semantic.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: semantic.success.withValues(alpha: 0.35),
              ),
            )
          : GlassDecoration.card(borderRadius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.repeat_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCompleted
                            ? semantic.success
                            : palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$rounds rondas · $exerciseCount ${l10n.exercises}',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                Icon(Icons.check_circle_rounded, color: semantic.success)
              else
                Icon(Icons.play_circle_fill_rounded, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _MiniStat(
                icon: Icons.stacked_bar_chart_rounded,
                label: '$completedCount/$exerciseCount',
              ),
              _MiniStat(
                icon: Icons.timer_outlined,
                label: '${restBetweenRoundsSeconds}s ${l10n.rest}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCompleted ? semantic.success : color,
                    foregroundColor: isCompleted
                        ? palette.onPrimary
                        : solidColorStyle.foreground,
                    side: isCompleted
                        ? null
                        : BorderSide(color: solidColorStyle.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    isCompleted
                        ? l10n.completeCircuitButton
                        : l10n.startCircuitButton,
                  ),
                ),
              ),
              if (onMarkPending != null) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: onMarkPending,
                  icon: const Icon(Icons.radio_button_unchecked_rounded),
                  tooltip: l10n.markCircuitPendingButton,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('circuit-feedback-button'),
              onPressed: onFeedback,
              icon: const Icon(Icons.video_library_outlined, size: 19),
              label: Text(l10n.circuitFeedbackAction),
            ),
          ),
        ],
      ),
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
  final List<SetPerformance>? currentPerformances;
  final String? partialProgressLabel;
  final VoidCallback onOpenActive;
  final void Function(bool completed, {double? weightUsed}) onToggle;

  const _ExerciseCard({
    required this.trainingExercise,
    required this.trainingTypes,
    required this.accentColorHex,
    required this.trainingLevel,
    required this.isCompleted,
    required this.onOpenActive,
    required this.onToggle,
    this.weightUsed,
    this.currentPerformances,
    this.partialProgressLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ex = trainingExercise.exercise;
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final currentPerformanceLabel = currentPerformances?.isEmpty ?? true
        ? null
        : currentPerformances!.map(formatSetPerformance).join(' | ');

    return GestureDetector(
      onTap: () => _showExerciseDetail(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: isCompleted
            ? BoxDecoration(
                color: semantic.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: semantic.success.withValues(alpha: 0.35),
                ),
              )
            : GlassDecoration.card(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail or placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ex.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: ex.thumbnailUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      memCacheWidth: PerformanceProfile.imageCacheWidth(
                        context,
                        60,
                      ),
                      placeholder: (context, imageUrl) =>
                          _ExercisePlaceholder(),
                      errorWidget: (context, imageUrl, error) =>
                          _ExercisePlaceholder(),
                    )
                  : _ExercisePlaceholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${trainingExercise.order}.',
                        style: TextStyle(
                          color: palette.textDisabled,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ex.name,
                          style: TextStyle(
                            color: isCompleted
                                ? semantic.success
                                : palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: semantic.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (ex.muscleGroups.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      ex.muscleGroups.join(', '),
                      style: TextStyle(
                        color: palette.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _MiniStat(
                          icon: Icons.repeat,
                          label:
                              '${trainingExercise.sets} x ${formatExercisePrescription(trainingExercise)}',
                        ),
                        _MiniStat(
                          icon: Icons.timer_outlined,
                          label:
                              '${trainingExercise.restSeconds}s ${l10n.rest}',
                        ),
                        if (partialProgressLabel != null)
                          _MiniStat(
                            icon: Icons.stacked_bar_chart_rounded,
                            label: partialProgressLabel!,
                          ),
                        if (weightUsed != null) ...[
                          _MiniStat(
                            icon: Icons.fitness_center,
                            label: l10n.weightBadgeLabel(
                              weightUsed!.toStringAsFixed(
                                weightUsed! % 1 == 0 ? 0 : 1,
                              ),
                            ),
                          ),
                        ],
                        if (currentPerformanceLabel != null)
                          _MiniStat(
                            icon: Icons.edit_note_rounded,
                            label: currentPerformanceLabel,
                            maxWidth: constraints.maxWidth,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isCompleted
                    ? semantic.success
                    : palette.surfaceVariant.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? semantic.success
                      : palette.textDisabled.withValues(alpha: 0.32),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : Icons.chevron_right_rounded,
                color: isCompleted ? Colors.white : palette.textDisabled,
                size: 20,
              ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          trainingTypes: trainingTypes,
          accentColorHex: accentColorHex,
          trainingLevel: trainingLevel,
          hasPartialProgress: partialProgressLabel != null,
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

class _ExercisePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Container(
      width: 60,
      height: 60,
      color: palette.surfaceVariant,
      child: Icon(Icons.fitness_center, color: palette.textDisabled, size: 24),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? maxWidth;

  const _MiniStat({required this.icon, required this.label, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: palette.textDisabled, size: 12),
        const SizedBox(width: 3),
        if (maxWidth == null)
          Text(
            label,
            style: TextStyle(color: palette.textDisabled, fontSize: 11),
          )
        else
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textDisabled, fontSize: 11),
            ),
          ),
      ],
    );

    if (maxWidth == null) return content;
    return SizedBox(width: maxWidth, child: content);
  }
}

class _ExerciseDetailSheet extends StatelessWidget {
  final ExerciseEntity exercise;
  final TrainingExerciseEntity trainingExercise;
  final ScrollController scrollController;
  final bool isCompleted;
  final double? weightUsed;
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
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final typeColor = _typeColor(context);
    final solidTypeStyle = trainingColorStyle(context, typeColor);
    final thumbnailUrl = exercise.thumbnailUrl?.trim();
    final videoUrl = exercise.videoUrl?.trim();
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final muscleGroups = exercise.muscleGroups
        .map((group) => group.trim())
        .where((group) => group.isNotEmpty)
        .toList();
    final weightLabel = weightUsed == null
        ? null
        : l10n.weightBadgeLabel(
            weightUsed!.toStringAsFixed(weightUsed! % 1 == 0 ? 0 : 1),
          );
    final currentPerformanceLabels =
        (currentPerformances ?? const <SetPerformance>[])
            .map(formatSetPerformance)
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
                width: 72,
                height: 6,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withValues(alpha: 0.25),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: _SheetHeaderAction(
                  icon: Icons.feedback_outlined,
                  label: l10n.feedbackSendFromExercise,
                  onTap: () => _openFeedback(context),
                  tooltip: l10n.feedbackSendFromExercise,
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
        ),
        const SizedBox(height: 8),
        Text(
          exercise.name,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
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
              icon: Icons.local_fire_department_outlined,
              label: trainingLevel,
              color: typeColor,
              emphasized: true,
            ),
            if (muscleGroups.isNotEmpty)
              _InfoChip(
                icon: Icons.track_changes_rounded,
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
                border: Border.all(
                  color: hasVideo
                      ? typeColor.withValues(alpha: 0.18)
                      : palette.divider,
                ),
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
                                      Icons.fitness_center,
                                      color: palette.textDisabled,
                                      size: 44,
                                    ),
                                  ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    palette.surfaceVariant,
                                    palette.surface,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fitness_center,
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
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(
                              alpha: hasVideo ? 0.2 : 0.1,
                            ),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  if (hasVideo)
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: typeColor,
                        size: 54,
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
              icon: Icons.fitness_center,
              label: weightLabel,
              color: semantic.success,
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
                  'Series registradas hoy',
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(const _SheetCompletionResult(openActiveExercise: true));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: typeColor,
                foregroundColor: solidTypeStyle.foreground,
                side: BorderSide(color: solidTypeStyle.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text('Editar datos'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(const _SheetCompletionResult(markPending: true));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textPrimary,
                side: BorderSide(color: palette.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.radio_button_unchecked_rounded, size: 18),
              label: Text(l10n.markExercisePendingButton),
            ),
          ),
        ] else ...[
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(const _SheetCompletionResult(openActiveExercise: true));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: typeColor,
                foregroundColor: solidTypeStyle.foreground,
                side: BorderSide(color: solidTypeStyle.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                hasPartialProgress
                    ? l10n.resumeExerciseButton
                    : l10n.startExerciseButton,
              ),
            ),
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
                          fontSize: 12,
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
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
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
