import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/utils/operation_id.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/circuit_progression.dart';
import 'package:exom_app/features/trainings/domain/services/set_prefill.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/circuit_round_list.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_timer.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_technique_sheet.dart';
import 'package:exom_app/features/trainings/presentation/widgets/last_set_video_reminder.dart';
import 'package:exom_app/features/trainings/presentation/widgets/last_set_video_sheet.dart';
import 'package:exom_app/features/trainings/presentation/widgets/prescription_hero.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_performance_sheet.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_value_text.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ActiveCircuitPageArgs {
  final TrainingBloc trainingBloc;
  final String? sessionId;
  final String trainingName;
  final List<String> trainingTypes;
  final String? accentColorHex;
  final String trainingLevel;
  final String blockId;
  final String blockName;
  final int rounds;
  final int restBetweenRoundsSeconds;
  final List<TrainingExerciseEntity> exercises;
  final Map<String, List<SetPerformance>> previousPerformances;
  final bool requiresLastSetVideo;
  final String assignmentDate;

  const ActiveCircuitPageArgs({
    required this.trainingBloc,
    this.sessionId,
    required this.trainingName,
    required this.trainingTypes,
    required this.accentColorHex,
    required this.trainingLevel,
    required this.blockId,
    required this.blockName,
    required this.rounds,
    required this.restBetweenRoundsSeconds,
    required this.exercises,
    this.previousPerformances = const {},
    this.requiresLastSetVideo = false,
    required this.assignmentDate,
  });
}

enum _CircuitStatus {
  executing,
  exerciseResting,
  roundResting,
  finalResting,
  done,
}

@visibleForTesting
Map<String, String> restoreCircuitFeedbackStatuses(
  Map<String, String> feedbackIds,
  Map<String, String> storedStatuses,
  String? Function(String id) currentStatus,
) {
  final restored = <String, String>{};
  final staleExerciseIds = <String>[];
  for (final entry in feedbackIds.entries) {
    final liveStatus = currentStatus(entry.value);
    final storedStatus = storedStatuses[entry.key];
    if (liveStatus == null &&
        storedStatus != null &&
        storedStatus != 'completed') {
      staleExerciseIds.add(entry.key);
      continue;
    }
    restored[entry.key] = liveStatus ?? storedStatus ?? 'completed';
  }
  for (final exerciseId in staleExerciseIds) {
    feedbackIds.remove(exerciseId);
  }
  return restored;
}

/// Records that [exerciseId] logged a set at [at] (C-O1), in the wire form
/// of a completion time.
@visibleForTesting
void recordCircuitSetTime(
  Map<String, String> times,
  String exerciseId,
  DateTime at,
) {
  times[exerciseId] = OfflineSyncService.completionTime(at);
}

/// Freeze an exercise's outgoing action once, before its first dispatch.
/// A restored circuit retains this snapshot even if the editable sets change.
/// [completedAt] (its last set, C-O1) is frozen with it; a snapshot frozen
/// without it keeps none.
@visibleForTesting
Map<String, dynamic> snapshotCircuitCompletion(
  Map<String, Map<String, dynamic>> actions,
  String exerciseId, {
  required List<Map<String, dynamic>>? sets,
  double? weightUsed,
  String? feedbackId,
  String? completedAt,
}) {
  final existing = actions[exerciseId];
  if (existing != null && existing['operation_id'] is String &&
      (existing['operation_id'] as String).isNotEmpty) {
    return existing;
  }
  final snapshot = <String, dynamic>{
    'operation_id': newOperationId(),
    'sets': sets?.map((set) => Map<String, dynamic>.from(set)).toList(),
    'weight_used': weightUsed,
    'feedback_id': feedbackId,
    'completed_at': ?completedAt,
  };
  actions[exerciseId] = snapshot;
  return snapshot;
}

@visibleForTesting
Future<void> persistCircuitState(LocalStorage storage, String key,
    String? ownerSession, Map<String, dynamic> state) async {
  if (ownerSession == null || storage.sessionStamp != ownerSession) return;
  await storage.sessionTask(() async {
    if (storage.sessionStamp != ownerSession) return;
    await storage.cacheData(key, state);
  });
}

/// Total length of the rest the circuit is in, for the progress rule
/// (L3 unit 4, fixes F1). An exercise rest follows the previous exercise
/// (the index was already advanced); a final rest follows the current one
/// (the index is not advanced); a round rest is the block's. Never indexes
/// out of range (a one-exercise circuit's final rest read `exercises[-1]`
/// before L3). Clamped like `advanceCircuit`.
@visibleForTesting
int circuitRestTotalSeconds({
  required CircuitRestKind kind,
  required int currentExerciseIndex,
  required List<int> exerciseRestSeconds,
  required int roundRestSeconds,
}) {
  int restOf(int index) =>
      index < 0 || index >= exerciseRestSeconds.length
      ? 0
      : exerciseRestSeconds[index];
  final seconds = switch (kind) {
    CircuitRestKind.round => roundRestSeconds,
    CircuitRestKind.exercise => restOf(currentExerciseIndex - 1),
    CircuitRestKind.finalRest => restOf(currentExerciseIndex),
    CircuitRestKind.none || CircuitRestKind.done => 0,
  };
  return seconds.clamp(0, 3600);
}

/// Exercises already completed (logged or completed without logging) in the
/// circuit, from the persisted position (L3 unit 4, fixes F2). [status] is
/// the persisted status name. A round or final rest starts after the last
/// exercise of [round] without advancing the index, so the whole round is
/// done; an exercise rest starts with the index already advanced.
@visibleForTesting
int circuitCompletedCount({
  required int round,
  required int exerciseIndex,
  required int exerciseCount,
  required int totalRounds,
  required String status,
  required bool readyToFinish,
}) {
  final total = exerciseCount * totalRounds;
  final int completed;
  if (readyToFinish || status == 'done') {
    completed = total;
  } else if (status == 'roundResting' || status == 'finalResting') {
    completed = round * exerciseCount;
  } else {
    completed = (round - 1) * exerciseCount + exerciseIndex;
  }
  return completed.clamp(0, total);
}

class ActiveCircuitPage extends StatelessWidget {
  final String trainingId;
  final String blockId;
  final ActiveCircuitPageArgs? args;

  const ActiveCircuitPage({
    super.key,
    required this.trainingId,
    required this.blockId,
    required this.args,
  });

  @override
  Widget build(BuildContext context) {
    final pageArgs = args;
    if (pageArgs == null || pageArgs.exercises.isEmpty) {
      return ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Text(
              AppLocalizations.of(context).activeCircuitContextMissing,
            ),
          ),
        ),
      );
    }

    return BlocProvider<TrainingBloc>.value(
      value: pageArgs.trainingBloc,
      child: _ActiveCircuitView(trainingId: trainingId, args: pageArgs),
    );
  }
}

class _ActiveCircuitView extends StatefulWidget {
  final String trainingId;
  final ActiveCircuitPageArgs args;

  const _ActiveCircuitView({required this.trainingId, required this.args});

  @override
  State<_ActiveCircuitView> createState() => _ActiveCircuitViewState();
}

class _ActiveCircuitViewState extends State<_ActiveCircuitView> {
  ActiveWorkoutLocalStore? _executionStore;
  var _currentRound = 1;
  var _currentExerciseIndex = 0;
  var _status = _CircuitStatus.executing;
  DateTime? _restEndsAt;
  bool _markedComplete = false;
  bool _circuitReadyToFinish = false;
  final Map<String, List<SetPerformance>> _performances = {};
  final Map<String, String> _lastSetFeedbackIds = {};
  final Map<String, String> _lastSetFeedbackStatuses = {};
  final Map<String, Map<String, dynamic>> _completionActions = {};
  // When each exercise last logged a set (C-O1); dates its completion. Memory
  // only: the circuit cache keeps the released key set (constraint 1), so a
  // restart loses it and that completion is sent without a time, as before.
  // Once frozen in a completion snapshot it survives restarts with it.
  final Map<String, String> _lastSetAt = {};
  // «Recordármelo» as shown; read once from `last_set_video_reminder_enabled`.
  bool? _reminderEnabled;
  // E3c r2: true from the logged transition that will ask the last round's
  // video until its sheet has closed and its id (if any) is saved. Meanwhile
  // the end of the final rest only saves «ready to finish»; the completion
  // runs once, when the sheet closes (never the missing-videos sheet on top).
  bool _lastRoundVideoPending = false;
  StreamSubscription<FeedbackUploadNotice>? _feedbackSubscription;
  final String? _ownerSession = sl<LocalStorage>().sessionStamp;
  late final int _timerSessionRevision =
      sl<ExecutionTimerCoordinator>().sessionRevision;

  /// From the tap on «Registrar serie» until the set is logged or the sheet
  /// is dismissed: repeated taps are ignored (motion card 8a).
  bool _seriesBusy = false;

  /// While the completion is being sent: «Terminar circuito» is busy.
  bool _finishing = false;

  /// Set synchronously when a rest starts to end (skip or natural end), so
  /// no other rest action interleaves with its awaits (brief CD3).
  bool _restLeaving = false;

  /// While «+30 s» persists the new end and re-arms the native timer.
  bool _restExtending = false;

  /// Tail of the rest footer actions («+30 s», «Saltar descanso» and the
  /// footer's natural end). They run one after another in tap order, so a
  /// tap during another action's awaits is applied after it instead of being
  /// dropped (L3 review A-F3): +30 s, +30 s gives +60 s; a skip during an
  /// extension ends the extended rest. Each action re-checks its guards when
  /// it runs (a «+30 s» queued behind a skip finds the rest over).
  Future<void> _restActions = Future<void>.value();

  /// The user confirmed leaving and the native rest was cancelled: nothing
  /// may re-arm or finish it afterwards.
  bool _exited = false;

  /// Native session id of the rest in progress (memory only): «+30 s»
  /// re-arms that same session instead of starting a new one.
  String? _nativeRestId;

  /// Last set confirmed written to this phone's cache for its owner (memory
  /// only): the only save state this page may claim.
  ({String name, int round})? _lastSaved;

  String get _stateKey {
    final userId = sl<FirebaseAuthService>().currentUser?.uid ?? 'anonymous';
    return 'active_circuit:$userId:${widget.args.assignmentDate}:'
        '${widget.trainingId}:${widget.args.blockId}'
        '${widget.args.sessionId == null ? '' : ':${widget.args.sessionId}'}';
  }

  @override
  void initState() {
    super.initState();
    if (widget.args.exercises.any(
      (e) =>
          e.measureType == ExerciseMeasureType.seconds && e.targetValue != null,
    )) {
      _executionStore = sl<LocalStorage>().bindActiveWorkoutStore();
    }
    _restoreState();
    _feedbackSubscription = sl<FeedbackUploadQueueService>().notices.listen(
      _onFeedbackNotice,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeRestIfNeeded());
  }

  void _restoreState() {
    final stored = sl<LocalStorage>().getCachedMap(_stateKey);
    if (stored == null) return;

    final round = (stored['round'] as num?)?.toInt();
    final exerciseIndex = (stored['exercise_index'] as num?)?.toInt();
    final statusName = stored['status'] as String?;
    _CircuitStatus? restoredStatus;
    for (final value in _CircuitStatus.values) {
      if (value.name == statusName) restoredStatus = value;
    }
    if (round == null ||
        round < 1 ||
        round > widget.args.rounds ||
        exerciseIndex == null ||
        exerciseIndex < 0 ||
        exerciseIndex >= widget.args.exercises.length ||
        restoredStatus == null ||
        restoredStatus == _CircuitStatus.done) {
      return;
    }

    _currentRound = round;
    _currentExerciseIndex = exerciseIndex;
    _status = restoredStatus;
    _circuitReadyToFinish = stored['ready_to_finish'] == true;
    _restEndsAt = DateTime.tryParse(stored['rest_ends_at'] as String? ?? '');

    final performances = stored['performances'];
    if (performances is Map) {
      for (final entry in performances.entries) {
        final rawSets = entry.value;
        if (rawSets is! List) continue;
        final sets = <SetPerformance>[];
        for (final rawSet in rawSets.whereType<Map>()) {
          try {
            sets.add(
              SetPerformance.fromJson(Map<String, dynamic>.from(rawSet)),
            );
          } on Object {
            // Ignore only the malformed set; keep the remaining recovery data.
          }
        }
        if (sets.isNotEmpty) _performances[entry.key.toString()] = sets;
      }
    }

    final completionActions = stored['completion_actions'];
    if (completionActions is Map) {
      for (final entry in completionActions.entries) {
        if (entry.value is! Map) continue;
        final action = Map<String, dynamic>.from(entry.value as Map);
        if (action['operation_id'] is String &&
            (action['operation_id'] as String).isNotEmpty) {
          _completionActions[entry.key.toString()] = action;
        }
      }
    }

    final feedbackIds = stored['feedback_ids'];
    if (feedbackIds is Map) {
      _lastSetFeedbackIds.addAll(
        feedbackIds.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    }
    final feedbackStatuses = stored['feedback_statuses'];
    if (feedbackStatuses is Map) {
      _lastSetFeedbackStatuses.addAll(
        feedbackStatuses.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    }
    final queue = sl<FeedbackUploadQueueService>();
    final restoredStatuses = restoreCircuitFeedbackStatuses(
      _lastSetFeedbackIds,
      _lastSetFeedbackStatuses,
      queue.statusOf,
    );
    _lastSetFeedbackStatuses
      ..clear()
      ..addAll(restoredStatuses);
  }

  void _onFeedbackNotice(FeedbackUploadNotice notice) {
    final exerciseEntry = _lastSetFeedbackIds.entries.where(
      (entry) => entry.value == notice.id,
    );
    if (exerciseEntry.isEmpty) return;
    final exerciseId = exerciseEntry.first.key;
    if (notice.kind == FeedbackUploadNoticeKind.discarded) {
      _lastSetFeedbackIds.remove(exerciseId);
      _lastSetFeedbackStatuses.remove(exerciseId);
    } else {
      _lastSetFeedbackStatuses[exerciseId] = notice.kind.name;
    }
    unawaited(_persistState());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _feedbackSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resumeRestIfNeeded() async {
    if (!mounted ||
        _status == _CircuitStatus.executing ||
        _status == _CircuitStatus.done) {
      return;
    }
    final endsAt = _restEndsAt;
    if (endsAt == null || !endsAt.isAfter(DateTime.now())) {
      await _finishRest(finishedNaturally: true);
      return;
    }
    final id = _restSessionId(endsAt);
    _nativeRestId = id;
    await sl<RestTimerCoordinator>().start(
      RestTimerSession(
        id: id,
        exerciseName: _currentExercise.exercise.name,
        durationSeconds: endsAt.difference(DateTime.now()).inSeconds,
        endsAt: endsAt,
      ),
    );
  }

  /// Native rest session id, as before L3: it embeds the end of the rest
  /// when it started (a restored rest recomputes it from the persisted end).
  String _restSessionId(DateTime endsAt) =>
      '${widget.trainingId}:${widget.args.blockId}:${endsAt.millisecondsSinceEpoch}';

  bool get _isResting =>
      _status == _CircuitStatus.exerciseResting ||
      _status == _CircuitStatus.roundResting ||
      _status == _CircuitStatus.finalResting;

  Future<void> _persistState() {
    final storage = sl<LocalStorage>();
    if (_ownerSession == null || storage.sessionStamp != _ownerSession) {
      return Future<void>.value();
    }
    return persistCircuitState(storage, _stateKey, _ownerSession, <String, dynamic>{
      'training_session_id': widget.args.sessionId,
      'round': _currentRound,
      'exercise_index': _currentExerciseIndex,
      'status': _status.name,
      'rest_ends_at': _restEndsAt?.toIso8601String(),
      'ready_to_finish': _circuitReadyToFinish,
      'performances': _performances.map(
        (key, sets) => MapEntry(
          key,
          sets.map((performance) => performance.toJson()).toList(),
        ),
      ),
      'completion_actions': _completionActions.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
      ),
      'feedback_ids': Map<String, String>.from(_lastSetFeedbackIds),
      'feedback_statuses': Map<String, String>.from(_lastSetFeedbackStatuses),
    });
  }

  TrainingExerciseEntity get _currentExercise =>
      widget.args.exercises[_currentExerciseIndex];

  Future<void> _openVideoPlayer() async {
    final exercise = _currentExercise.exercise;
    final videoUrl = exercise.videoUrl?.trim();
    if (videoUrl == null || videoUrl.isEmpty) return;

    final uri = Uri.tryParse(videoUrl);
    if (uri == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ExerciseVideoPlayerPage(title: exercise.name, videoUri: uri),
      ),
    );
  }

  bool _hasContent(String? value) => value != null && value.trim().isNotEmpty;

  bool _hasVideo(ExerciseEntity exercise) => _hasContent(exercise.videoUrl);

  List<TechniqueSection> _techniqueSections(
    AppLocalizations l10n,
    ExerciseEntity exercise,
  ) => [
    if (_hasContent(exercise.techniqueText))
      (title: l10n.technique, text: exercise.techniqueText!.trim()),
    if (_hasContent(exercise.commonErrorsText))
      (title: l10n.commonMistakes, text: exercise.commonErrorsText!.trim()),
    if (_hasContent(exercise.explanationText))
      (title: l10n.explanation, text: exercise.explanationText!.trim()),
  ];

  Future<void> _openTechnique(AppLocalizations l10n) async {
    final exercise = _currentExercise.exercise;
    await showExerciseTechniqueSheet(
      context,
      exerciseName: exercise.name,
      hasVideo: _hasVideo(exercise),
      videoUrl: exercise.videoUrl,
      thumbnailUrl: exercise.thumbnailUrl,
      onOpenVideo: _openVideoPlayer,
      sections: _techniqueSections(l10n, exercise),
    );
  }

  /// Sets and exercises done so far (logged or completed without logging),
  /// from the same persisted position the exit message used before L3 (F2).
  int get _completedCount => circuitCompletedCount(
    round: _currentRound,
    exerciseIndex: _currentExerciseIndex,
    exerciseCount: widget.args.exercises.length,
    totalRounds: widget.args.rounds,
    status: _status.name,
    readyToFinish: _circuitReadyToFinish,
  );

  Future<bool> _confirmExit() async {
    if (_status == _CircuitStatus.done) return true;

    final l10n = AppLocalizations.of(context);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activeExerciseCloseTitle),
        content: Text(
          l10n.activeExerciseCloseMessage(
            _completedCount,
            widget.args.exercises.length * widget.args.rounds,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.continueButton),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      // Leaving keeps the persisted state for resuming; only the native rest
      // is cancelled, as before L3.
      _exited = true;
      _nativeRestId = null;
      await sl<RestTimerCoordinator>().cancel();
      return true;
    }
    return false;
  }

  Future<void> _close() async {
    final shouldClose = await _confirmExit();
    if (!mounted || !shouldClose) return;
    context.pop();
  }

  /// «Registrar serie» / «Terminar circuito». Busy from the tap until the
  /// set is logged, the sheet is dismissed or the completion ends.
  Future<void> _onPrimaryPressed(WeightText weightText) async {
    if (_seriesBusy || _finishing || _status != _CircuitStatus.executing) {
      return;
    }
    setState(() => _seriesBusy = true);
    try {
      await _completeCurrentSeries(weightText);
    } finally {
      // Every exit of the series (also a failed write or a thrown enqueue)
      // ends the pending last-round video (E3c r2).
      _lastRoundVideoPending = false;
      if (mounted) setState(() => _seriesBusy = false);
    }
  }

  Future<void> _completeCurrentSeries(WeightText weightText) async {
    if (_status != _CircuitStatus.executing) return;
    if (_circuitReadyToFinish) {
      await _finishCircuit();
      return;
    }

    final tracking = await _requestPerformance(_currentExercise, weightText);
    // Null: dismissed, cancelled or a repeated trigger. Nothing happened.
    if (!mounted || tracking == null) return;
    // L5-D23 (ii, iv): with «Recordármelo» on, saving the last round asks for
    // its video, but only once the round is persisted (never a typed round
    // kept only in memory while the camera is open: the circuit does not
    // inherit P-E3b-1). Off, it is asked at the end, as before E3c.
    final videoExercise = _currentExercise;
    final videoRound = _currentRound;
    final asksVideo = _asksLastRoundVideo(videoExercise) && _reminderOn;
    // Before the rest starts: a final rest ending at any point until the
    // sheet closes defers the completion (cleared by `_onPrimaryPressed`).
    if (asksVideo) _lastRoundVideoPending = true;
    // «Completar sin registrar» advances without a set, as before L3.
    final performance = tracking.skipped
        ? null
        : SetPerformance(
            setNumber: _currentRound,
            reps: tracking.reps,
            seconds: tracking.seconds,
            weightKg: tracking.weight,
            rir: tracking.rir,
          );
    final logged = performance == null
        ? null
        : (name: _currentExercise.exercise.name, round: _currentRound);
    if (performance != null) {
      _performances.update(
        _currentExercise.id,
        (sets) => [...sets, performance],
        ifAbsent: () => [performance],
      );
    }
    recordCircuitSetTime(_lastSetAt, _currentExercise.id, DateTime.now());

    final completedTimerKey =
        '${_currentExercise.id}:interval:$_currentRound:${widget.args.assignmentDate}';
    final progression = advanceCircuit(
      currentRound: _currentRound,
      totalRounds: widget.args.rounds,
      currentExerciseIndex: _currentExerciseIndex,
      exerciseCount: widget.args.exercises.length,
      exerciseRestSeconds: _currentExercise.restSeconds,
      roundRestSeconds: widget.args.restBetweenRoundsSeconds,
    );
    if (progression.restKind == CircuitRestKind.done) {
      setState(() => _circuitReadyToFinish = true);
      if (!await _persistLoggedTransition(logged)) return;
      await _executionStore?.removeActiveWorkout(completedTimerKey);
      if (asksVideo && mounted && !_exited) {
        final enqueueFailed = await _offerLastRoundVideo(
          videoExercise,
          tracking,
          videoRound,
          weightText,
        );
        if (!mounted) return;
        // E3c r4 (D1): the error SnackBar stays visible; the missing-videos
        // sheet would cover it. «Terminar circuito» asks for the video.
        if (enqueueFailed) return;
      }
      await _finishCircuit();
      return;
    }

    setState(() {
      if (progression.restKind == CircuitRestKind.round) {
        _status = _CircuitStatus.roundResting;
      } else if (progression.restKind == CircuitRestKind.exercise) {
        _status = _CircuitStatus.exerciseResting;
      } else if (progression.restKind == CircuitRestKind.finalRest) {
        _status = _CircuitStatus.finalResting;
      }
      if (progression.restKind == CircuitRestKind.none) {
        _currentRound = progression.nextRound;
        _currentExerciseIndex = progression.nextExerciseIndex;
      } else {
        _restEndsAt = DateTime.now().add(
          Duration(seconds: progression.restSeconds),
        );
        if (progression.restKind == CircuitRestKind.exercise) {
          _currentExerciseIndex = progression.nextExerciseIndex;
        }
      }
    });
    final restEndsAt = _restEndsAt;
    if (!await _persistLoggedTransition(logged)) return;
    if (progression.restKind != CircuitRestKind.none) {
      await _executionStore?.removeActiveWorkout(completedTimerKey);
      // Never arm a native rest the page already left (skipped meanwhile)
      // or that the user abandoned by leaving.
      if (mounted &&
          !_exited &&
          _isResting &&
          restEndsAt != null &&
          _restEndsAt == restEndsAt) {
        final id = _restSessionId(restEndsAt);
        _nativeRestId = id;
        await sl<RestTimerCoordinator>().start(
          RestTimerSession(
            id: id,
            exerciseName: _currentExercise.exercise.name,
            durationSeconds: progression.restSeconds,
            endsAt: restEndsAt,
          ),
        );
      }
    }
    if (progression.restKind == CircuitRestKind.none) {
      await _executionStore?.removeActiveWorkout(completedTimerKey);
    }
    // The round is persisted (and its rest armed): now its video.
    if (asksVideo && mounted && !_exited) {
      final enqueueFailed = await _offerLastRoundVideo(
        videoExercise,
        tracking,
        videoRound,
        weightText,
      );
      _lastRoundVideoPending = false;
      // The final rest ran out with the sheet open (it only saved «ready to
      // finish»): complete now, once, with the video just queued (if any).
      // The rest already finished its native timer. E3c r4 (D1): not after a
      // failed enqueue, whose SnackBar the missing-videos sheet would cover;
      // «Terminar circuito» asks for the video.
      if (mounted && !_exited && _circuitReadyToFinish && !enqueueFailed) {
        await _finishCircuit(cancelRestTimer: false);
      }
    }
  }

  /// Persists the transition that follows a log (same write as before L3).
  /// Returns false when the write threw: the snackbar says so and the state
  /// stays in memory (the next transition rewrites it). «Guardada en este
  /// móvil» is shown only after a write that reached this phone's cache for
  /// the page's owner; nothing here claims a remote save.
  Future<bool> _persistLoggedTransition(
    ({String name, int round})? logged,
  ) async {
    try {
      await _persistState();
    } on Object {
      if (mounted) {
        setState(() => _lastSaved = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).circuitSaveError)),
        );
      }
      return false;
    }
    final written =
        _ownerSession != null &&
        sl<LocalStorage>().sessionStamp == _ownerSession;
    if (mounted) {
      setState(() => _lastSaved = written ? logged : null);
    }
    return true;
  }

  bool _asksLastRoundVideo(TrainingExerciseEntity trainingExercise) =>
      widget.args.requiresLastSetVideo &&
      _currentRound == widget.args.rounds &&
      !_lastSetFeedbackIds.containsKey(trainingExercise.id);

  bool get _reminderOn =>
      _reminderEnabled ??=
          sl<LocalStorage>().getSetting<bool>(
            'last_set_video_reminder_enabled',
            defaultValue: true,
          ) ??
          true;

  /// «Recordármelo»: the same preference as Ajustes (on = true), as E3b.
  Future<void> _setReminder(bool enabled) async {
    setState(() => _reminderEnabled = enabled);
    try {
      await sl<LocalStorage>().saveSetting(
        'last_set_video_reminder_enabled',
        enabled,
      );
    } catch (_) {
      if (!mounted) return;
      // Same as Ajustes (M8): undo the optimistic switch and say so.
      setState(() {
        if (_reminderEnabled == enabled) _reminderEnabled = !enabled;
      });
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? l10n.settingsSwitchEnableFailed
                : l10n.settingsSwitchDisableFailed,
          ),
        ),
      );
    }
  }

  /// The shared last-set video sheet (L5-D23 ii-iii, iv), opened only after
  /// the last round of [trainingExercise] is persisted and only with
  /// «Recordármelo» on. «Usar vídeo» queues with the same fields as before
  /// E3c and persists the id; «Cambiar», «Cancelar», a dismissal or a router
  /// change queue nothing: the round is already saved and its video is asked
  /// at the end (`_collectMissingVideos`), as «Al terminar» did.
  /// Returns true only when «Usar vídeo» was chosen and the enqueue threw
  /// (its SnackBar is shown).
  Future<bool> _offerLastRoundVideo(
    TrainingExerciseEntity trainingExercise,
    SetPerformanceResult tracking,
    int round,
    WeightText weightText,
  ) async {
    if (!_reminderOn) return false;
    // The set sheet returns once its subtree is gone; open on the next frame.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final performed = tracking.skipped
        ? null
        : setValueLabel(
            l10n,
            SetPerformance(
              setNumber: round,
              reps: tracking.reps,
              seconds: tracking.seconds,
              weightKg: tracking.weight,
            ),
            weightText,
          );
    final choice = await showExomSheet<LastSetVideoChoice>(
      context: context,
      builder: (_) => LastSetVideoSheet(
        kicker: l10n.lastSetVideoSheetKicker(
          trainingExercise.exercise.name,
          round,
        ),
        setLabel: performed == null || performed.isEmpty
            ? l10n.setPerformanceTitle(round)
            : l10n.lastSetVideoChosenSet(round, performed),
        pickVideo: _pickCircuitVideo,
      ),
    );
    // E3c r2: as the active exercise, nothing is queued once the session is
    // no longer the page owner's (no work of user A with B's credentials).
    if (choice == null ||
        !mounted ||
        _ownerSession == null ||
        sl<LocalStorage>().sessionStamp != _ownerSession) {
      return false;
    }
    final notes = choice.notes.trim();
    final String id;
    try {
      id = await _enqueueCircuitVideo(
        trainingExercise,
        choice.file,
        notes.isEmpty ? null : notes,
      );
    } on LocalSessionChanged {
      rethrow;
    } on Object {
      // E3c r3: the state stays «ready to finish»; the retry asks again.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).circuitLastRoundVideoSaveError,
            ),
          ),
        );
      }
      return true;
    }
    if (mounted) {
      setState(() {
        _lastSetFeedbackIds[trainingExercise.id] = id;
        _lastSetFeedbackStatuses[trainingExercise.id] = 'queued';
      });
      await _persistState();
    }
    return false;
  }

  Future<File?> _pickCircuitVideo(ImageSource initialSource) async {
    var source = initialSource;
    while (mounted) {
      try {
        final picked = await ImagePicker().pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        );
        return picked == null ? null : File(picked.path);
      } on Object catch (error) {
        if (!mounted) return null;
        final action = await showMediaPickerErrorDialog(
          context,
          error,
          canUseGallery: source != ImageSource.gallery,
        );
        if (action == MediaPickerRecoveryAction.gallery) {
          source = ImageSource.gallery;
        } else if (action != MediaPickerRecoveryAction.retry) {
          return null;
        }
      }
    }
    return null;
  }

  /// E3c r2: bound to the page owner's session (the queue rejects another
  /// one), in the round and at the end alike; a page without an owner
  /// queues nothing.
  Future<String> _enqueueCircuitVideo(
    TrainingExerciseEntity trainingExercise,
    File file,
    String? notes,
  ) async {
    final owner = _ownerSession;
    if (owner == null) throw const LocalSessionChanged();
    return sl<FeedbackUploadQueueService>().enqueue(
      expectedSession: owner,
      file: file,
      contentType: _videoContentType(file),
      mediaType: 'VIDEO',
      notes: notes,
      exerciseId: trainingExercise.exercise.id,
      feedbackKind: 'LAST_SET',
      trainingId: widget.trainingId,
      trainingExerciseId: trainingExercise.id,
      assignmentDate: widget.args.assignmentDate,
      sessionId: widget.args.sessionId,
      exerciseName: trainingExercise.exercise.name,
    );
  }

  String _videoContentType(File file) {
    return switch (file.path.split('.').last.toLowerCase()) {
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'webm' => 'video/webm',
      _ => 'video/mp4',
    };
  }

  Future<bool> _collectMissingVideos() async {
    final missing = widget.args.exercises
        .where((exercise) => !_lastSetFeedbackIds.containsKey(exercise.id))
        .toList(growable: false);
    if (missing.isEmpty) return true;
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .9,
          child: SingleChildScrollView(
            child: CircuitFeedbackForm(
              circuitName: AppLocalizations.of(
                context,
              ).requiredCircuitVideos(widget.args.blockName),
              requireAll: true,
              targets: missing
                  .map(
                    (exercise) => FeedbackExerciseTarget(
                      key: exercise.id,
                      exerciseId: exercise.exercise.id,
                      exerciseName: exercise.exercise.name,
                    ),
                  )
                  .toList(growable: false),
              enqueue: (upload) async {
                final exercise = missing.firstWhere(
                  (item) => item.id == upload.target.key,
                );
                final id = await _enqueueCircuitVideo(
                  exercise,
                  upload.file,
                  upload.notes,
                );
                _lastSetFeedbackIds[exercise.id] = id;
                _lastSetFeedbackStatuses[exercise.id] = 'queued';
                await _persistState();
              },
              onQueued: () => Navigator.pop(sheetContext, true),
            ),
          ),
        ),
      ),
    );
    return completed == true;
  }

  /// The set logged for exactly [round] in this execution (only after an
  /// interrupted save or a restored state), without `performanceForSet`'s
  /// fallback to another round.
  SetPerformance? _exactRound(List<SetPerformance>? sets, int round) {
    if (sets == null) return null;
    for (final set in sets.reversed) {
      if (set.setNumber == round) return set;
    }
    return null;
  }

  /// Weight (kg) prefilled for [exercise] in [round] (D4): this round's set,
  /// then the last weight logged for it in this execution (before L3 the
  /// last round only, even without weight), then the previous session's
  /// same round, then its last weighted set.
  double? _weightPrefill(TrainingExerciseEntity exercise, int round) {
    final logged = _performances[exercise.id];
    double? lastWeight;
    if (logged != null) {
      for (final set in logged.reversed) {
        if (set.weightKg != null) {
          lastWeight = set.weightKg;
          break;
        }
      }
    }
    return prefillWeightKg(
      today: _exactRound(logged, round),
      sessionWeightKg: lastWeight,
      previous: widget.args.previousPerformances[exercise.id],
      setNumber: round,
    );
  }

  /// Opens the shared set sheet (`showExomSheet`, result only after the
  /// sheet subtree is disposed; null for a dismissal or a repeated trigger).
  /// The weight comes back in kilograms whatever the user's unit (D5).
  Future<SetPerformanceResult?> _requestPerformance(
    TrainingExerciseEntity trainingExercise,
    WeightText weightText,
  ) {
    final l10n = AppLocalizations.of(context);
    final round = _currentRound;
    final logged = _performances[trainingExercise.id];
    final today = _exactRound(logged, round);
    final previousSameRound = performanceForSet(
      widget.args.previousPerformances[trainingExercise.id],
      round,
    );
    final timeUnit = timePerformanceUnitForExercise(trainingExercise);
    return showExomSheet<SetPerformanceResult>(
      context: context,
      builder: (_) => SetPerformanceSheet(
        title: l10n.circuitSheetTitle(trainingExercise.exercise.name, round),
        objective: formatExercisePrescription(trainingExercise),
        timeUnit: timeUnit,
        countRequired: trainingExercise.requestSetTracking,
        unitSystem: weightText.unitSystem,
        decimalSeparator: weightText.decimalSeparator,
        initialCount: prefillCount(
          today: today,
          lastThisExecution: logged == null || logged.isEmpty
              ? null
              : logged.last,
          previousSameSet: previousSameRound,
          target: PrescriptionTarget.of(trainingExercise).count,
          timed: timeUnit != null,
        ),
        initialWeightKg: _weightPrefill(trainingExercise, round),
        // Owner decision: the target RIR on every round, never carried over
        // from the previous round; this round's stored value when re-logged.
        initialRir: prefillRir(
          today: today,
          targetRir: trainingExercise.targetRir,
        ),
        previous: previousSameRound,
        today: today,
      ),
    );
  }

  /// Queues a rest footer action behind the previous ones (see
  /// [_restActions]). The returned future carries the action's own error, as
  /// a direct call did. The queue goes on after a failed action, but the
  /// failure is not silent: it is reported through [FlutterError.reportError]
  /// and the save-error message is shown while the page is mounted. Nothing
  /// runs once the page is disposed.
  Future<void> _enqueueRestAction(Future<void> Function() action) {
    final run = _restActions.then<void>((_) async {
      if (!mounted) return;
      await action();
    });
    _restActions = run.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'active_circuit_page',
            context: ErrorDescription('rest footer action'),
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).circuitSaveError),
          ),
        );
      },
    );
    return run;
  }

  /// Ends the rest in progress. [expectedEndsAt] is the end the caller was
  /// built for (the rest footer's timer): a tick of an outgoing footer after
  /// «+30 s» is stale and ignored. The skip passes none.
  Future<void> _finishRest({
    required bool finishedNaturally,
    DateTime? expectedEndsAt,
  }) async {
    if (!mounted || !_isResting || _restLeaving || _restExtending || _exited) {
      return;
    }
    final currentEnd = _restEndsAt;
    if (expectedEndsAt != null &&
        currentEnd != null &&
        expectedEndsAt != currentEnd) {
      return;
    }
    // Set before the first await: skip, «+30 s» and the natural end cannot
    // interleave with this transition.
    setState(() => _restLeaving = true);
    try {
      _nativeRestId = null;
      final restTimerCoordinator = sl<RestTimerCoordinator>();
      if (finishedNaturally) {
        await restTimerCoordinator.finish();
      } else {
        await restTimerCoordinator.cancel();
      }
      if (!mounted) return;
      if (_status == _CircuitStatus.finalResting) {
        // F3: the final rest ends into «ready to finish» (persisted, as the
        // released app writes it after the last log) so a failed or
        // interrupted completion leaves «Terminar circuito» to retry.
        setState(() {
          _status = _CircuitStatus.executing;
          _circuitReadyToFinish = true;
          _restEndsAt = null;
          _restLeaving = false;
        });
        // E3c r2: read with the state change (no await between them). With
        // the last round's video still pending, the series completes the
        // circuit once its sheet closes; finishing here would open the
        // missing-videos sheet over it and ask the same video twice.
        final videoPending = _lastRoundVideoPending;
        await _persistState();
        if (videoPending) return;
        await _finishCircuit(cancelRestTimer: false);
        return;
      }

      setState(() {
        if (_status == _CircuitStatus.roundResting) {
          _currentRound += 1;
          _currentExerciseIndex = 0;
        }
        _status = _CircuitStatus.executing;
        _restEndsAt = null;
        _restLeaving = false;
      });
      await _persistState();
    } finally {
      if (_restLeaving) {
        if (mounted) {
          setState(() => _restLeaving = false);
        } else {
          _restLeaving = false;
        }
      }
    }
  }

  /// «+30 s» (D7): moves the persisted end 30 s later (at most 30 min from
  /// now), persists it under the same key and re-arms the same native
  /// session. Only while the rest has not ended.
  Future<void> _extendRest() async {
    final currentEnd = _restEndsAt;
    final now = DateTime.now();
    if (!mounted ||
        !_isResting ||
        _restLeaving ||
        _restExtending ||
        _seriesBusy ||
        _exited ||
        currentEnd == null ||
        !now.isBefore(currentEnd)) {
      return;
    }
    final cap = now.add(const Duration(minutes: 30));
    var nextEnd = currentEnd.add(const Duration(seconds: 30));
    if (nextEnd.isAfter(cap)) nextEnd = cap;
    if (!nextEnd.isAfter(currentEnd)) return;

    setState(() {
      _restEndsAt = nextEnd;
      _restExtending = true;
    });
    try {
      // Accepted limitation (L3 review A-F4, same class as CompleteSet and
      // ActiveExerciseBloc's ExtendRest): the new end is shown before this
      // write lands. If the write fails, `start` is skipped: the native timer
      // keeps the OLD end and only the in-memory state has the extension;
      // after a restart the rest restores the last persisted end and ends
      // 30 s earlier than it was shown.
      await _persistState();
      if (!mounted || _exited || !_isResting || _restEndsAt != nextEnd) {
        return;
      }
      final id = _nativeRestId ?? _restSessionId(nextEnd);
      _nativeRestId = id;
      await sl<RestTimerCoordinator>().start(
        RestTimerSession(
          id: id,
          exerciseName: _currentExercise.exercise.name,
          durationSeconds: nextEnd.difference(DateTime.now()).inSeconds,
          endsAt: nextEnd,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _restExtending = false);
      } else {
        _restExtending = false;
      }
    }
  }

  Future<void> _finishCircuit({bool cancelRestTimer = true}) async {
    // Reached after awaits (a logged transition, the end of the final rest):
    // the page may have been disposed meanwhile (L3 review A-F1).
    if (!mounted || _markedComplete || _finishing) return;
    setState(() => _finishing = true);
    try {
      await _sendCompletion(cancelRestTimer: cancelRestTimer);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _sendCompletion({required bool cancelRestTimer}) async {
    if (_markedComplete) return;
    if (widget.args.requiresLastSetVideo && !await _collectMissingVideos()) {
      return;
    }
    if (!mounted || _ownerSession == null ||
        sl<LocalStorage>().sessionStamp != _ownerSession) {
      return;
    }
    _markedComplete = true;
    final trainingBloc = context.read<TrainingBloc>();
    if (cancelRestTimer) {
      await sl<RestTimerCoordinator>().cancel();
    }

    try {
      for (final trainingExercise in widget.args.exercises) {
        if (sl<LocalStorage>().sessionStamp != _ownerSession) return;
        // TrainingBloc ignores MarkExerciseCompleted unless the detail is
        // loaded, so its completion would never complete and «Terminar
        // circuito» would stay busy (L3 review A-F2). Fail this attempt like
        // a failed dispatch: the cached state and the frozen operation ids
        // are kept and the retry reuses them.
        if (trainingBloc.state is! TrainingDetailLoaded) {
          throw StateError('TrainingBloc has no loaded training detail');
        }
        final sets = _performances[trainingExercise.id];
        final action = snapshotCircuitCompletion(
          _completionActions, trainingExercise.id,
          sets: sets?.map((set) => set.toJson()).toList(),
          weightUsed: sets == null || sets.isEmpty ? null : sets.last.weightKg,
          feedbackId: _lastSetFeedbackIds[trainingExercise.id],
          completedAt: _lastSetAt[trainingExercise.id],
        );
        // The snapshot must survive a crash or lost response before dispatch.
        await _persistState();
        if (sl<LocalStorage>().sessionStamp != _ownerSession) return;
        final completion = Completer<void>();
        trainingBloc.add(
          MarkExerciseCompleted(
            trainingExerciseId: trainingExercise.id,
            exerciseId: trainingExercise.exercise.id,
            sessionId: widget.args.sessionId,
            sessionStamp: _ownerSession,
            operationId: action['operation_id'] as String,
            completed: true,
            weightUsed: action['weight_used'] as double?,
            sets: (action['sets'] as List?)?.whereType<Map>().map(
              (set) => SetPerformance.fromJson(Map<String, dynamic>.from(set)),
            ).toList(),
            lastSetFeedbackClientUploadId: action['feedback_id'] as String?,
            completedAt: DateTime.tryParse(
              action['completed_at'] as String? ?? '',
            ),
            completion: completion,
          ),
        );
        await completion.future;
      }
    } catch (_) {
      _markedComplete = false;
      await _persistState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).circuitSaveError)),
      );
      return;
    }

    if (!mounted || sl<LocalStorage>().sessionStamp != _ownerSession) return;
    setState(() {
      _status = _CircuitStatus.done;
    });
    await sl<LocalStorage>().removeCachedData(_stateKey);
    if (!mounted) return;
    // E-D2: a route opened over the page («Salir del ejercicio» while the
    // final rest ends, a sheet) is closed first; otherwise context.pop()
    // would pop it instead of the page and leave it on «done».
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      route.navigator?.popUntil((candidate) => candidate == route);
    }
    context.pop();
  }

  CircuitRestKind get _restKind => switch (_status) {
    _CircuitStatus.exerciseResting => CircuitRestKind.exercise,
    _CircuitStatus.roundResting => CircuitRestKind.round,
    _CircuitStatus.finalResting => CircuitRestKind.finalRest,
    _CircuitStatus.executing || _CircuitStatus.done => CircuitRestKind.none,
  };

  /// Same condition as before L3 for the timed work interval (its widget,
  /// key and draft are unchanged).
  bool get _showsExecutionTimer =>
      _status == _CircuitStatus.executing &&
      _currentExercise.measureType == ExerciseMeasureType.seconds &&
      _currentExercise.targetValue != null &&
      _executionStore != null;

  bool get _readyToFinish =>
      _circuitReadyToFinish || _status == _CircuitStatus.done;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weightText = WeightText.of(context);
    final resting = _isResting;
    final restEndsAt = _restEndsAt;
    final ready = _readyToFinish;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldClose = await _confirmExit();
        if (!context.mounted || !shouldClose) return;
        context.pop();
      },
      child: ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CircuitHeader(
                  blockName: widget.args.blockName,
                  closeTooltip: l10n.circuitCloseA11y,
                  onClose: _close,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    // L5-E5: no side padding here; the columns and the round
                    // list run edge to edge (sketch `.x-cols`, `.x-rows`) and
                    // every other block carries [_sidePadding].
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                    child: resting
                        ? _restBody(context, l10n, weightText)
                        : _executingBody(context, l10n, weightText),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: ExomPinnedFooter(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                _trainingFooterBottomPadding(context),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: resting
                    ? _CircuitRestFooter(
                        key: ValueKey(
                          'round-rest-${restEndsAt?.millisecondsSinceEpoch}',
                        ),
                        restEndsAt: restEndsAt ?? DateTime.now(),
                        enabled: !_restLeaving,
                        onExtend: () =>
                            unawaited(_enqueueRestAction(_extendRest)),
                        onSkip: () => unawaited(
                          _enqueueRestAction(
                            () => _finishRest(finishedNaturally: false),
                          ),
                        ),
                        onFinished: (endsAt) => unawaited(
                          _enqueueRestAction(
                            () => _finishRest(
                              finishedNaturally: true,
                              expectedEndsAt: endsAt,
                            ),
                          ),
                        ),
                      )
                    : SizedBox(
                        key: const ValueKey('circuit-executing-footer'),
                        width: double.infinity,
                        child: ExomPrimaryButton(
                          label: ready
                              ? l10n.circuitFinishButton
                              : l10n.activeExerciseLogSetButton,
                          trailingIcon: ready
                              ? ExomIcons.check
                              : ExomIcons.forward,
                          busy:
                              _seriesBusy ||
                              _finishing ||
                              _status == _CircuitStatus.done,
                          onPressed: () => _onPrimaryPressed(weightText),
                        ),
                      ),
              ),
          ),
        ),
      ),
    );
  }

  /// Side padding of every block that does not run edge to edge.
  static const EdgeInsets _sidePadding = EdgeInsets.symmetric(horizontal: 20);

  TextStyle _sectionStyle(BuildContext context) => TextStyle(
    fontFamily: AppTheme.displayFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -0.44,
    color: context.exomPalette.textPrimary,
  );

  TextStyle _bigStyle(BuildContext context) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 18,
    height: 1.4,
    color: context.exomPalette.textPrimary,
  );

  TextStyle _mutedStyle(BuildContext context) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 14,
    height: 1.4,
    color: context.exomPalette.textSecondary,
  );

  /// «Esta ronda»: what was logged in the current round and what is left.
  /// Rows are numbered by their position in the circuit (index + 1), never
  /// by the exercise's `order`.
  Widget _roundList(AppLocalizations l10n, WeightText weightText) {
    final roundDone =
        _readyToFinish ||
        _status == _CircuitStatus.roundResting ||
        _status == _CircuitStatus.finalResting;
    final exercises = widget.args.exercises;
    final rows = [
      for (var index = 0; index < exercises.length; index++)
        () {
          final exercise = exercises[index];
          final logged = _exactRound(
            _performances[exercise.id],
            _currentRound,
          );
          final CircuitRowState state;
          String? value;
          if (roundDone || index < _currentExerciseIndex) {
            state = logged == null
                ? CircuitRowState.notLogged
                : CircuitRowState.done;
            value = logged == null
                ? null
                : setValueLabel(
                        l10n,
                        logged,
                        weightText,
                        withUnit: false,
                      ) ??
                      setValueLabel(
                        l10n,
                        logged,
                        weightText,
                        withUnit: false,
                        withRir: true,
                      ) ??
                      l10n.activeExerciseSetDone;
          } else if (index == _currentExerciseIndex &&
              _status == _CircuitStatus.executing) {
            state = CircuitRowState.now;
            value = PrescriptionTarget.of(exercise).shortLabel(l10n);
          } else {
            state = CircuitRowState.next;
            value = PrescriptionTarget.of(exercise).shortLabel(l10n);
          }
          return (
            key: ValueKey('circuit-row-$index'),
            name: exercise.exercise.name,
            state: state,
            value: value,
          );
        }(),
    ];
    final logged = rows
        .where((row) => row.state == CircuitRowState.done)
        .length;
    return CircuitRoundList(
      key: const Key('circuit-round-list'),
      title: l10n.circuitThisRound,
      summary: l10n.circuitRoundLogged(logged, rows.length),
      rows: rows,
    );
  }

  List<Widget> _roundSection(AppLocalizations l10n, WeightText weightText) {
    final saved = _lastSaved;
    return [
      // `.pad.mt24.x-sh-row` (circuit frames of the sketch, `e-migradas`).
      const SizedBox(height: 24),
      _roundList(l10n, weightText),
      if (saved != null) ...[
        const SizedBox(height: 12),
        Padding(
          padding: _sidePadding,
          child: Semantics(
            container: true,
            liveRegion: true,
            child: ExomSyncStatus(
              key: const Key('circuit-set-status'),
              state: ExomSyncState.guardadaEnMovil,
              label: l10n.circuitSavedStatus(
                saved.name,
                saved.round,
                l10n.syncStatusSavedOnDevice,
              ),
            ),
          ),
        ),
      ],
    ];
  }

  /// «Descanso después: 30 s», «Descanso de ronda después: 60 s» or «Al
  /// terminar: fin del circuito», from the same values `advanceCircuit`
  /// will use when this exercise is logged.
  String? _afterLine(AppLocalizations l10n) {
    final exercise = _currentExercise;
    final lastExercise =
        _currentExerciseIndex >= widget.args.exercises.length - 1;
    final lastRound = _currentRound >= widget.args.rounds;
    if (!lastExercise) {
      final rest = exercise.restSeconds.clamp(0, 3600);
      return rest > 0 ? l10n.activeExerciseRestAfter(rest) : null;
    }
    if (!lastRound) {
      final rest = widget.args.restBetweenRoundsSeconds.clamp(0, 3600);
      return rest > 0 ? l10n.circuitRoundRestAfter(rest) : null;
    }
    final rest = exercise.restSeconds.clamp(0, 3600);
    return rest > 0
        ? l10n.activeExerciseRestAfter(rest)
        : l10n.circuitEndsAfter;
  }

  /// «Última vez» (sketch `.x-cols`, `.e-ref`): the count of the previous
  /// session's same round, in the unit of the target, in the text colour at
  /// 56, with the rest of that set (weight in the user's unit, RIR) in the
  /// detail below: «10 reps» / «× 22,5 kg · RIR 2». A set without a count
  /// (only weight or RIR) shows no figure, only its detail. Null when there
  /// is no previous set or it carries nothing to show.
  ExomFigure? _lastTimeFigure(
    AppLocalizations l10n,
    SetPerformance? previous,
    PrescriptionTarget target,
    WeightText weightText,
  ) {
    if (previous == null) return null;
    final full = setValueLabel(l10n, previous, weightText, withRir: true);
    if (full == null || full.isEmpty) return null;
    final kg = previous.weightKg;
    final reps = previous.reps;
    final seconds = previous.seconds;
    final rir = previous.rir;
    final String value;
    final String? unit;
    final List<String> rest;
    if (reps != null) {
      value = '$reps';
      unit = l10n.activeExerciseUnitReps;
      rest = [
        if (kg != null) '× ${weightText(kg)}',
        if (seconds != null) '$seconds ${l10n.activeExerciseUnitSeconds}',
      ];
    } else if (seconds != null) {
      final inMinutes =
          target.timeUnit == TimePerformanceUnit.minutes && seconds % 60 == 0;
      value = '${inMinutes ? seconds ~/ 60 : seconds}';
      unit = inMinutes
          ? l10n.activeExerciseUnitMinutes
          : l10n.activeExerciseUnitSeconds;
      rest = [if (kg != null) weightText(kg)];
    } else {
      return ExomFigure(
        value: '',
        label: l10n.exerciseLastTimeLabel,
        detail: full,
        tone: ExomFigureTone.text,
        semanticsLabel: '${l10n.exerciseLastTimeLabel}: $full',
        itemKey: const Key('circuit-last-time'),
      );
    }
    final detail = [...rest, if (rir != null) l10n.activeExerciseRir(rir)];
    return ExomFigure(
      value: value,
      unit: unit,
      label: l10n.exerciseLastTimeLabel,
      tone: ExomFigureTone.text,
      detail: detail.isEmpty ? null : detail.join(' · '),
      semanticsLabel: '${l10n.exerciseLastTimeLabel}: $full',
      itemKey: const Key('circuit-last-time'),
    );
  }

  Widget _executingBody(
    BuildContext context,
    AppLocalizations l10n,
    WeightText weightText,
  ) {
    final palette = context.exomPalette;
    final ready = _readyToFinish;
    final trainingExercise = _currentExercise;
    final exercise = trainingExercise.exercise;
    final weightKg = ready
        ? null
        : _weightPrefill(trainingExercise, _currentRound);
    final previous = performanceForSet(
      widget.args.previousPerformances[trainingExercise.id],
      _currentRound,
    );
    final previousLabel = previous == null
        ? null
        : setValueLabel(l10n, previous, weightText, withRir: true);
    final after = _afterLine(l10n);
    final sections = _techniqueSections(l10n, exercise);
    final hasTechnique = _hasVideo(exercise) || sections.isNotEmpty;
    final mutedStyle = _mutedStyle(context);
    final target = PrescriptionTarget.of(trainingExercise);
    final targetNumeral = target.numeral;
    final targetRir = trainingExercise.targetRir;
    final lastTime = _lastTimeFigure(l10n, previous, target, weightText);
    // The previous set is told by the «Última vez» column when there is one;
    // the «Anterior» / «Sin datos anteriores» line stays only without it
    // (timed interval, free-text prescription, no previous set).
    final showsColumns =
        !_showsExecutionTimer && !ready && targetNumeral != null;
    final showsPreviousLine = !showsColumns || lastTime == null;
    final showsReminder = !ready && _asksLastRoundVideo(trainingExercise);
    // With no line under the columns the reminder sits directly under them
    // and shares their bottom rule (an empty strip between two rules read as
    // an empty section).
    final reminderJoinsColumns =
        showsReminder &&
        showsColumns &&
        weightKg == null &&
        !showsPreviousLine &&
        after == null;

    // The heading changes inside the screen (next exercise, next round):
    // announced as a live region.
    final Widget title = ready
        ? Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              l10n.circuitReadyTitle.toUpperCase(),
              style: ExomType.headline2Section.copyWith(
                color: palette.textPrimary,
              ),
            ),
          )
        : Semantics(
            container: true,
            liveRegion: true,
            child: ExomTwoLineHeadline(
              key: const Key('circuit-exercise-name'),
              first: l10n.circuitStepExercise(exercise.name),
              second: l10n.circuitStepPosition(
                _currentExerciseIndex + 1,
                widget.args.exercises.length,
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: _sidePadding,
          child: _CircuitStep(
            key: const Key('circuit-step'),
            round: _currentRound,
            rounds: widget.args.rounds,
            kicker: l10n.circuitRoundOf(_currentRound, widget.args.rounds),
            title: title,
          ),
        ),
        if (_showsExecutionTimer) ...[
          const SizedBox(height: 24),
          Padding(
            padding: _sidePadding,
            child: CircuitExecutionTimer(
              key: ValueKey('${trainingExercise.id}:$_currentRound'),
              store: _executionStore!,
              exercise: trainingExercise,
              trainingId: widget.trainingId,
              date: widget.args.assignmentDate,
              round: _currentRound,
              runKey: (widget.args.sessionId, widget.args.blockId),
              coordinator: sl<ExecutionTimerCoordinator>(),
              isOwnerCurrent: () => isExecutionTimerOwnerCurrent(
                _ownerSession,
                _timerSessionRevision,
              ),
            ),
          ),
        ] else if (!ready && targetNumeral != null) ...[
          const SizedBox(height: 24),
          ExomFigureColumns(
            numbered: false,
            labelsAbove: true,
            items: [
              ExomFigure(
                value: targetNumeral,
                unit: target.unitLabel(l10n),
                label: l10n.circuitTargetLabel,
                detail: targetRir == null
                    ? null
                    : l10n.activeExerciseRir(targetRir),
                size: ExomFigureSize.s64,
                itemKey: const Key('circuit-target'),
              ),
              ?lastTime,
            ],
          ),
        ] else if (!ready) ...[
          // Free-text prescription: shown as it is, as before L5.
          const SizedBox(height: 24),
          Padding(
            padding: _sidePadding,
            child: PrescriptionHero(
              target: target,
              targetRir: targetRir,
              prescription: formatExercisePrescription(trainingExercise),
              numeralKey: const Key('circuit-target'),
            ),
          ),
        ],
        if (!ready && !reminderJoinsColumns)
          Padding(
            padding: _sidePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (weightKg != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.activeExerciseYourWeight(weightText(weightKg)),
                    key: const Key('circuit-your-weight'),
                    style: _bigStyle(context),
                  ),
                ],
                if (showsPreviousLine) ...[
                  SizedBox(height: weightKg == null ? 16 : 4),
                  Text(
                    previousLabel == null || previousLabel.isEmpty
                        ? l10n.activeExerciseNoPrevious
                        : l10n.setPerformancePrevious(previousLabel),
                    key: const Key('circuit-previous'),
                    style: mutedStyle,
                  ),
                ] else
                  SizedBox(height: weightKg == null ? 16 : 4),
                if (after != null)
                  Text(
                    after,
                    key: const Key('circuit-after'),
                    style: mutedStyle,
                  ),
              ],
            ),
          ),
        // L5-D23 (i, iv), sketch `f-circ-ult`: the reminder of the last
        // round's video, with the circuit copy of the old dialog.
        if (showsReminder) ...[
          if (!reminderJoinsColumns) const SizedBox(height: 24),
          LastSetVideoReminder(
            joinsPrevious: reminderJoinsColumns,
            enabled: _reminderOn,
            title: l10n.lastSetReminderTitle,
            message: l10n.lastSetReminderMessage(exercise.name),
            onChanged: _setReminder,
          ),
        ],
        ..._roundSection(l10n, weightText),
        if (!ready && hasTechnique) ...[
          const SizedBox(height: 20),
          Padding(
            padding: _sidePadding,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExomTextLink(
                key: const Key('circuit-technique'),
                label: l10n.activeExerciseTechniqueButton,
                icon: _hasVideo(exercise) ? ExomIcons.play : null,
                onTap: () => _openTechnique(l10n),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _restBody(
    BuildContext context,
    AppLocalizations l10n,
    WeightText weightText,
  ) {
    final kind = _restKind;
    final restEndsAt = _restEndsAt;
    final title = switch (kind) {
      CircuitRestKind.round => l10n.circuitRoundRestTitle,
      CircuitRestKind.finalRest => l10n.circuitFinalRestTitle,
      _ => l10n.restTimerTitle,
    };
    final total = circuitRestTotalSeconds(
      kind: kind,
      currentExerciseIndex: _currentExerciseIndex,
      exerciseRestSeconds: [
        for (final exercise in widget.args.exercises) exercise.restSeconds,
      ],
      roundRestSeconds: widget.args.restBetweenRoundsSeconds,
    );
    final String next;
    if (kind == CircuitRestKind.round) {
      next = l10n.circuitNextRound(
        _currentRound + 1,
        widget.args.exercises.first.exercise.name,
      );
    } else if (kind == CircuitRestKind.finalRest) {
      next = l10n.circuitAfterRestEnd;
    } else {
      final upcoming = _currentExercise;
      final target = PrescriptionTarget.of(upcoming).shortLabel(l10n);
      final weightKg = _weightPrefill(upcoming, _currentRound);
      next = target == null
          ? l10n.restTimerNextExercise(upcoming.exercise.name)
          : weightKg == null
          ? l10n.circuitNextExercise(upcoming.exercise.name, target)
          : l10n.circuitNextExerciseWithWeight(
              upcoming.exercise.name,
              target,
              weightText(weightKg),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: _sidePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The round left the header (L5-E5): during a rest it stays on
              // screen as the kicker of the rest title.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExomKicker(
                  l10n.circuitRoundOf(_currentRound, widget.args.rounds),
                  key: const Key('circuit-round'),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text(title.toUpperCase(), style: _sectionStyle(context)),
              ),
              if (kind == CircuitRestKind.round) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.circuitRoundDone(_currentRound),
                  style: _mutedStyle(context),
                ),
              ],
              const SizedBox(height: 16),
              if (restEndsAt != null)
                // L5-D48: «+30 s» re-keys the countdown; the scope keeps
                // the bar growing to the new total instead of starting over.
                RestCountdownScope(
                  // Same rest while the round, the exercise and the kind of
                  // rest are the same; «+30 s» only moves the deadline.
                  restId: (_currentRound, _currentExerciseIndex, kind),
                  child: RestCountdown(
                    key: ValueKey(
                      'rest-countdown-${restEndsAt.millisecondsSinceEpoch}',
                    ),
                    restEndsAt: restEndsAt,
                    totalSeconds: total,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                next,
                key: const Key('circuit-rest-next'),
                style: _bigStyle(context),
              ),
            ],
          ),
        ),
        ..._roundSection(l10n, weightText),
      ],
    );
  }
}

double _trainingFooterBottomPadding(BuildContext context) {
  const margin = 16.0;
  if (defaultTargetPlatform != TargetPlatform.android) return margin;
  final mediaQuery = MediaQuery.of(context);
  final navigationInset = mediaQuery.viewPadding.bottom;
  final usesGestureNavigation = mediaQuery.systemGestureInsets.bottom > 0;
  return usesGestureNavigation
      ? navigationInset.clamp(margin, double.infinity)
      : navigationInset + margin;
}

/// Header of the active circuit (sketch `.hdr-push`): close (48x48,
/// labelled; it goes through `_confirmExit` like system back) and the block
/// name in the display face (wraps, never ellipsized). Since L5-E5 the round
/// is not here: it is the protagonist of [_CircuitStep] and the kicker of a
/// rest.
class _CircuitHeader extends StatelessWidget {
  const _CircuitHeader({
    required this.blockName,
    required this.closeTooltip,
    required this.onClose,
  });

  final String blockName;
  final String closeTooltip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            key: const Key('circuit-close'),
            icon: Icon(ExomIcons.close, color: palette.textPrimary),
            tooltip: closeTooltip,
            onPressed: onClose,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      blockName.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppTheme.displayFontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        letterSpacing: -0.44,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step of the active circuit (sketch `.x-step`, L5-E5): the round as the
/// protagonist, «2/3» at 120 in the data colour with the total muted, then
/// the [kicker] «Ronda 2 de 3» and the [title] (the exercise headline, or the
/// ready title), and under them a rule of one segment per round with the
/// rounds up to the current one filled. The numeral sits beside the title
/// when both fit and above it otherwise (`flex-wrap`).
///
/// The numeral and the rule are painted only: the kicker already says the
/// round to assistive technology.
class _CircuitStep extends StatelessWidget {
  const _CircuitStep({
    super.key,
    required this.round,
    required this.rounds,
    required this.kicker,
    required this.title,
  });

  final int round;
  final int rounds;
  final String kicker;
  final Widget title;

  /// `.x-step > .x-segs > i { height: 6px }`.
  static const double _ruleThickness = 6;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            ExcludeSemantics(
              child: ExomNumeral(
                value: '$round',
                unit: '/$rounds',
                unitColor: palette.textMuted,
                size: ExomNumeralSize.hero120,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExomKicker(kicker, key: const Key('circuit-round')),
                const SizedBox(height: 6),
                title,
              ],
            ),
          ],
        ),
        if (rounds > 0) ...[
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: ExomProgressRule(
              value: round / rounds,
              thickness: _ruleThickness,
              segments: rounds,
            ),
          ),
        ],
      ],
    );
  }
}

/// Footer of a circuit rest (exercise, round or final): «+30 s» (secondary)
/// and «Saltar descanso» (quiet), no lime. It owns the timer that ends the
/// rest when it reaches zero while mounted (as before L3); callers key it by
/// `round-rest-<restEndsAt ms>` so each rest and each extension gets fresh
/// state. [onFinished] receives the end it was built for, so a tick of an
/// outgoing footer after «+30 s» is stale and ignored by the page.
class _CircuitRestFooter extends StatefulWidget {
  const _CircuitRestFooter({
    super.key,
    required this.restEndsAt,
    required this.enabled,
    required this.onExtend,
    required this.onSkip,
    required this.onFinished,
  });

  final DateTime restEndsAt;

  /// False while a rest transition is in flight: taps are ignored.
  final bool enabled;
  final VoidCallback onExtend;
  final VoidCallback onSkip;
  final ValueChanged<DateTime> onFinished;

  @override
  State<_CircuitRestFooter> createState() => _CircuitRestFooterState();
}

class _CircuitRestFooterState extends State<_CircuitRestFooter> {
  Timer? _ticker;
  bool _didFinish = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0 && !_didFinish) {
        _didFinish = true;
        _ticker?.cancel();
        widget.onFinished(widget.restEndsAt);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _remainingSeconds <= 0 && !_didFinish) {
        _didFinish = true;
        _ticker?.cancel();
        widget.onFinished(widget.restEndsAt);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _remainingSeconds {
    final remainingMs = widget.restEndsAt
        .difference(DateTime.now())
        .inMilliseconds;
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExomSecondaryButton(
          key: const Key('circuit-rest-extend'),
          label: l10n.activeExerciseRestExtend(30),
          onPressed: widget.enabled ? widget.onExtend : null,
        ),
        const SizedBox(height: 12),
        Center(
          child: ExomQuietButton(
            key: const Key('circuit-rest-skip'),
            label: l10n.activeExerciseRestSkip,
            onPressed: widget.enabled ? widget.onSkip : null,
          ),
        ),
      ],
    );
  }
}
