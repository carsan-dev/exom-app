import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/utils/training_type_utils.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/circuit_progression.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_video_preview.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';

class ActiveCircuitPageArgs {
  final TrainingBloc trainingBloc;
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
          body: const Center(child: Text('Missing active circuit context')),
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
  var _currentRound = 1;
  var _currentExerciseIndex = 0;
  var _status = _CircuitStatus.executing;
  DateTime? _restEndsAt;
  bool _markedComplete = false;
  bool _circuitReadyToFinish = false;
  final Map<String, List<SetPerformance>> _performances = {};
  final Map<String, String> _lastSetFeedbackIds = {};
  final Map<String, String> _lastSetFeedbackStatuses = {};
  StreamSubscription<FeedbackUploadNotice>? _feedbackSubscription;

  String get _stateKey {
    final userId = sl<FirebaseAuthService>().currentUser?.uid ?? 'anonymous';
    return 'active_circuit:$userId:${widget.args.assignmentDate}:'
        '${widget.trainingId}:${widget.args.blockId}';
  }

  @override
  void initState() {
    super.initState();
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
    await sl<RestTimerCoordinator>().start(
      RestTimerSession(
        id: '${widget.trainingId}:${widget.args.blockId}:${endsAt.millisecondsSinceEpoch}',
        exerciseName: _currentExercise.exercise.name,
        durationSeconds: endsAt.difference(DateTime.now()).inSeconds,
        endsAt: endsAt,
      ),
    );
  }

  Future<void> _persistState() {
    return sl<LocalStorage>().cacheData(_stateKey, <String, dynamic>{
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
      'feedback_ids': Map<String, String>.from(_lastSetFeedbackIds),
      'feedback_statuses': Map<String, String>.from(_lastSetFeedbackStatuses),
    });
  }

  Color _typeColor(BuildContext context) {
    return trainingAccentColor(
      context,
      accentColor: widget.args.accentColorHex,
      types: widget.args.trainingTypes,
    );
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

  String _formatPrescription(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final lower = trimmed.toLowerCase();
    final hasUnit = RegExp(
      r'(rep|repet|seg|sec|min|s\b|kg|kilo|lb|libra|cada|c/l|max|amrap|rm)',
    ).hasMatch(lower);
    if (hasUnit) return trimmed;

    final looksLikeReps = RegExp(
      r'^\d+([-,/]\d+)?$',
    ).hasMatch(trimmed.replaceAll(' ', ''));
    return looksLikeReps ? '$trimmed reps' : trimmed;
  }

  Future<bool> _confirmExit() async {
    if (_status == _CircuitStatus.done) return true;

    final l10n = AppLocalizations.of(context);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activeExerciseCloseTitle),
        content: Text(
          l10n.activeExerciseCloseMessage(
            _currentExerciseIndex,
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
      await sl<RestTimerCoordinator>().cancel();
      return true;
    }
    return false;
  }

  Future<void> _completeCurrentSeries() async {
    if (_status != _CircuitStatus.executing) return;
    if (_circuitReadyToFinish) {
      await _finishCircuit();
      return;
    }

    if (widget.args.requiresLastSetVideo &&
        _currentRound == widget.args.rounds &&
        !_lastSetFeedbackIds.containsKey(_currentExercise.id)) {
      await _showLastRoundReminder(_currentExercise);
      if (!mounted) return;
    }

    final tracking = await _requestPerformance(_currentExercise);
    if (!mounted || tracking == null) return;
    final performance = tracking.performance;
    if (performance != null) {
      _performances.update(
        _currentExercise.id,
        (sets) => [...sets, performance],
        ifAbsent: () => [performance],
      );
    }

    final progression = advanceCircuit(
      currentRound: _currentRound,
      totalRounds: widget.args.rounds,
      currentExerciseIndex: _currentExerciseIndex,
      exerciseCount: widget.args.exercises.length,
      exerciseRestSeconds: _currentExercise.restSeconds,
      roundRestSeconds: widget.args.restBetweenRoundsSeconds,
    );
    if (progression.restKind == CircuitRestKind.done) {
      _circuitReadyToFinish = true;
      await _persistState();
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
    await _persistState();
    if (progression.restKind != CircuitRestKind.none) {
      await sl<RestTimerCoordinator>().start(
        RestTimerSession(
          id: '${widget.trainingId}:${widget.args.blockId}:${_restEndsAt!.millisecondsSinceEpoch}',
          exerciseName: _currentExercise.exercise.name,
          durationSeconds: progression.restSeconds,
          endsAt: _restEndsAt!,
        ),
      );
    }
  }

  Future<void> _showLastRoundReminder(
    TrainingExerciseEntity trainingExercise,
  ) async {
    final storage = sl<LocalStorage>();
    final remindersEnabled =
        storage.getSetting<bool>(
          'last_set_video_reminder_enabled',
          defaultValue: true,
        ) ??
        true;
    if (!remindersEnabled) return;
    var hideAgain = false;
    final attach = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).lastSetReminderTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(
                  context,
                ).lastSetReminderMessage(trainingExercise.exercise.name),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: hideAgain,
                onChanged: (value) =>
                    setDialogState(() => hideAgain = value ?? false),
                title: Text(AppLocalizations.of(context).doNotShowAgain),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(context).attachAtEnd),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppLocalizations.of(context).attachNow),
            ),
          ],
        ),
      ),
    );
    if (hideAgain) {
      await storage.saveSetting('last_set_video_reminder_enabled', false);
    }
    if (attach != true || !mounted) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(AppLocalizations.of(context).recordNow),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(AppLocalizations.of(context).chooseFromGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _pickCircuitVideo(source);
    if (picked == null) return;
    final id = await _enqueueCircuitVideo(trainingExercise, picked, null);
    if (mounted) {
      setState(() {
        _lastSetFeedbackIds[trainingExercise.id] = id;
        _lastSetFeedbackStatuses[trainingExercise.id] = 'queued';
      });
      await _persistState();
    }
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

  Future<String> _enqueueCircuitVideo(
    TrainingExerciseEntity trainingExercise,
    File file,
    String? notes,
  ) => sl<FeedbackUploadQueueService>().enqueue(
    file: file,
    contentType: _videoContentType(file),
    mediaType: 'VIDEO',
    notes: notes,
    exerciseId: trainingExercise.exercise.id,
    feedbackKind: 'LAST_SET',
    trainingId: widget.trainingId,
    trainingExerciseId: trainingExercise.id,
    assignmentDate: widget.args.assignmentDate,
  );

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

  Future<({SetPerformance? performance, bool skipped})?> _requestPerformance(
    TrainingExerciseEntity trainingExercise,
  ) async {
    final l10n = AppLocalizations.of(context);
    final valueController = TextEditingController();
    final currentPerformance = performanceForSet(
      _performances[trainingExercise.id],
      _currentRound,
    );
    final previousWeight = _performances[trainingExercise.id]?.last.weightKg;
    final timeUnit = timePerformanceUnitForExercise(trainingExercise);
    final timeBased = timeUnit != null;
    final previousPerformance = performanceForSet(
      widget.args.previousPerformances[trainingExercise.id],
      _currentRound,
    );
    final previousLabel = previousPerformance == null
        ? null
        : formatSetPerformance(previousPerformance);
    final weightController = TextEditingController(
      text: previousWeight?.toString() ?? '',
    );
    final rirController = TextEditingController(
      text: currentPerformance?.rir?.toString() ?? '',
    );
    String? error;
    final result =
        await showDialog<({SetPerformance? performance, bool skipped})>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: Text(l10n.setPerformanceTitle(_currentRound)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.setPerformancePrescription(
                      formatExercisePrescription(trainingExercise),
                    ),
                  ),
                  if (previousLabel != null && previousLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(l10n.setPerformancePrevious(previousLabel)),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: timeBased
                          ? timeUnit == TimePerformanceUnit.minutes
                                ? l10n.setPerformanceMinutes
                                : l10n.setPerformanceSeconds
                          : l10n.setPerformanceReps,
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.setPerformanceWeightOptional,
                      suffixText: 'kg',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rirController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.setPerformanceRirOptional,
                    ),
                  ),
                ],
              ),
              actions: [
                if (!trainingExercise.requestSetTracking)
                  TextButton(
                    onPressed: () => Navigator.of(
                      dialogContext,
                    ).pop((performance: null, skipped: true)),
                    child: Text(l10n.completeWithoutTracking),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final value = int.tryParse(valueController.text.trim());
                    final weightText = weightController.text.trim();
                    final weight = weightText.isEmpty
                        ? null
                        : double.tryParse(weightText.replaceAll(',', '.'));
                    final rirText = rirController.text.trim();
                    final rir = rirText.isEmpty ? null : int.tryParse(rirText);
                    if (trainingExercise.requestSetTracking &&
                        (value == null || value < 1)) {
                      setDialogState(
                        () => error = timeBased
                            ? l10n.setPerformanceSecondsError
                            : l10n.setPerformanceRepsError,
                      );
                      return;
                    }
                    if (value != null && value < 1) {
                      setDialogState(
                        () => error = timeBased
                            ? l10n.setPerformanceSecondsError
                            : l10n.setPerformanceRepsError,
                      );
                      return;
                    }
                    final reps = timeBased ? null : value;
                    final seconds = timeBased
                        ? secondsFromTimeInput(value, timeUnit)
                        : null;
                    if (weight != null && weight < 0) {
                      setDialogState(
                        () => error = l10n.setPerformanceWeightError,
                      );
                      return;
                    }
                    if (rirText.isNotEmpty &&
                        (rir == null || rir < 0 || rir > 10)) {
                      setDialogState(() => error = l10n.setPerformanceRirError);
                      return;
                    }
                    if (reps == null &&
                        seconds == null &&
                        weight == null &&
                        rir == null) {
                      setDialogState(
                        () => error = l10n.setPerformanceDataError,
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop((
                      performance: SetPerformance(
                        setNumber: _currentRound,
                        reps: reps,
                        seconds: seconds,
                        weightKg: weight,
                        rir: rir,
                      ),
                      skipped: false,
                    ));
                  },
                  child: Text(l10n.weightInputSave),
                ),
              ],
            ),
          ),
        );
    valueController.dispose();
    weightController.dispose();
    rirController.dispose();
    return result;
  }

  Future<void> _finishRest({required bool finishedNaturally}) async {
    if (_status != _CircuitStatus.roundResting &&
        _status != _CircuitStatus.exerciseResting &&
        _status != _CircuitStatus.finalResting) {
      return;
    }

    final restTimerCoordinator = sl<RestTimerCoordinator>();
    if (finishedNaturally) {
      await restTimerCoordinator.finish();
    } else {
      await restTimerCoordinator.cancel();
    }
    if (_status == _CircuitStatus.finalResting) {
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
    });
    await _persistState();
  }

  Future<void> _finishCircuit({bool cancelRestTimer = true}) async {
    if (_markedComplete) return;
    if (widget.args.requiresLastSetVideo && !await _collectMissingVideos()) {
      return;
    }
    if (!mounted) return;
    _markedComplete = true;
    final trainingBloc = context.read<TrainingBloc>();
    if (cancelRestTimer) {
      await sl<RestTimerCoordinator>().cancel();
    }

    try {
      for (final trainingExercise in widget.args.exercises) {
        final sets = _performances[trainingExercise.id];
        final completion = Completer<void>();
        trainingBloc.add(
          MarkExerciseCompleted(
            trainingExerciseId: trainingExercise.id,
            exerciseId: trainingExercise.exercise.id,
            completed: true,
            weightUsed: sets == null || sets.isEmpty
                ? null
                : sets.last.weightKg,
            sets: sets,
            lastSetFeedbackClientUploadId:
                _lastSetFeedbackIds[trainingExercise.id],
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

    if (!mounted) return;
    setState(() {
      _status = _CircuitStatus.done;
    });
    await sl<LocalStorage>().removeCachedData(_stateKey);
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);
    final color = _typeColor(context);
    final solidColorStyle = trainingColorStyle(context, color);
    final exercise = _currentExercise.exercise;
    final completedSeries =
        ((_currentRound - 1) * widget.args.exercises.length) +
        _currentExerciseIndex;
    final totalSeries = widget.args.exercises.length * widget.args.rounds;

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
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.close_rounded,
                        onTap: () async {
                          final shouldClose = await _confirmExit();
                          if (!context.mounted || !shouldClose) return;
                          context.pop();
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              widget.args.trainingName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.args.blockName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 200,
                          child: ExerciseVideoPreview(
                            title: exercise.name,
                            videoUrl: exercise.videoUrl,
                            thumbnailUrl: exercise.thumbnailUrl,
                            onTap: _openVideoPlayer,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: GlassDecoration.card(borderRadius: 24),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _StatusPill(
                                    label:
                                        _status == _CircuitStatus.finalResting
                                        ? l10n.activeExerciseResting
                                        : _status == _CircuitStatus.roundResting
                                        ? l10n.circuitRoundRestTitle
                                        : _status ==
                                              _CircuitStatus.exerciseResting
                                        ? l10n.circuitExerciseRestTitle
                                        : l10n.activeExerciseExecuting,
                                    color:
                                        _status ==
                                                _CircuitStatus.roundResting ||
                                            _status ==
                                                _CircuitStatus.finalResting ||
                                            _status ==
                                                _CircuitStatus.exerciseResting
                                        ? semantic.warning
                                        : color,
                                  ),
                                  const Spacer(),
                                  Text(
                                    widget.args.trainingLevel,
                                    style: TextStyle(
                                      color: palette.textDisabled,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                l10n.circuitRoundProgress(
                                  _currentRound,
                                  widget.args.rounds,
                                ),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.circuitExerciseProgress(
                                  _currentExerciseIndex + 1,
                                  widget.args.exercises.length,
                                ),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                exercise.name,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatPrescription(
                                  formatExercisePrescription(_currentExercise),
                                ),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: totalSeries == 0
                                    ? 0
                                    : completedSeries / totalSeries,
                                minHeight: 8,
                                backgroundColor: palette.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _status == _CircuitStatus.done
                                      ? semantic.success
                                      : color,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ],
                          ),
                        ),
                        if (exercise.techniqueText?.trim().isNotEmpty == true)
                          _DetailSection(
                            title: l10n.technique,
                            text: exercise.techniqueText!,
                          ),
                        if (exercise.commonErrorsText?.trim().isNotEmpty ==
                            true)
                          _DetailSection(
                            title: l10n.commonMistakes,
                            text: exercise.commonErrorsText!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              _trainingFooterBottomPadding(context),
            ),
            child: Padding(
              padding: EdgeInsets.zero,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child:
                    _status == _CircuitStatus.finalResting ||
                        _status == _CircuitStatus.roundResting ||
                        _status == _CircuitStatus.exerciseResting
                    ? _RoundRestFooter(
                        key: ValueKey(
                          'round-rest-${_restEndsAt?.millisecondsSinceEpoch}',
                        ),
                        totalSeconds: _status == _CircuitStatus.roundResting
                            ? widget.args.restBetweenRoundsSeconds
                            : widget
                                  .args
                                  .exercises[_currentExerciseIndex - 1]
                                  .restSeconds,
                        restEndsAt: _restEndsAt ?? DateTime.now(),
                        title: _status == _CircuitStatus.finalResting
                            ? l10n.activeExerciseResting
                            : _status == _CircuitStatus.roundResting
                            ? l10n.circuitRoundRestTitle
                            : l10n.circuitExerciseRestTitle,
                        nextExerciseName: _status == _CircuitStatus.roundResting
                            ? widget.args.exercises.first.exercise.name
                            : _currentExercise.exercise.name,
                        onSkip: () =>
                            unawaited(_finishRest(finishedNaturally: false)),
                        onFinished: () =>
                            unawaited(_finishRest(finishedNaturally: true)),
                      )
                    : SizedBox(
                        key: const ValueKey('circuit-executing-footer'),
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _completeCurrentSeries,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: solidColorStyle.foreground,
                            side: BorderSide(color: solidColorStyle.border),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          child: Text(l10n.completeSetButton.toUpperCase()),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
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

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Material(
      color: palette.surfaceVariant.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: palette.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoundRestFooter extends StatefulWidget {
  final int totalSeconds;
  final DateTime restEndsAt;
  final VoidCallback onSkip;
  final VoidCallback onFinished;
  final String title;
  final String nextExerciseName;

  const _RoundRestFooter({
    super.key,
    required this.totalSeconds,
    required this.restEndsAt,
    required this.onSkip,
    required this.onFinished,
    required this.title,
    required this.nextExerciseName,
  });

  @override
  State<_RoundRestFooter> createState() => _RoundRestFooterState();
}

class _RoundRestFooterState extends State<_RoundRestFooter> {
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
        widget.onFinished();
        return;
      }
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _remainingSeconds <= 0 && !_didFinish) {
        _didFinish = true;
        _ticker?.cancel();
        widget.onFinished();
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

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final remaining = _remainingSeconds;

    return Container(
      decoration: GlassDecoration.card(borderRadius: 22),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: palette.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(remaining),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.restTimerNextExercise(widget.nextExerciseName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: widget.onSkip,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            child: Text(l10n.restTimerSkip.toUpperCase()),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String text;

  const _DetailSection({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      decoration: GlassDecoration.card(borderRadius: 20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
