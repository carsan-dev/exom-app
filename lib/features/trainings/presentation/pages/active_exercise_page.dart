import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_timer.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/set_prefill.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/active_exercise_set_chips.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_technique_sheet.dart';
import 'package:exom_app/features/trainings/presentation/widgets/last_set_video_sheet.dart';
import 'package:exom_app/features/trainings/presentation/widgets/prescription_hero.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_performance_sheet.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_value_text.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';

export 'package:exom_app/features/trainings/presentation/widgets/set_performance_sheet.dart'
    show SetPerformanceResult;

class ActiveExercisePageArgs {
  final TrainingBloc trainingBloc;
  final String? sessionId;
  final TrainingExerciseEntity trainingExercise;
  final String trainingName;
  final List<String> trainingTypes;
  final String? accentColorHex;
  final String trainingLevel;
  final double? initialWeightKg;
  final List<SetPerformance>? currentPerformances;
  final List<SetPerformance>? previousPerformances;
  final bool requiresLastSetVideo;
  final String assignmentDate;

  const ActiveExercisePageArgs({
    required this.trainingBloc,
    this.sessionId,
    required this.trainingExercise,
    required this.trainingName,
    required this.trainingTypes,
    required this.accentColorHex,
    required this.trainingLevel,
    this.initialWeightKg,
    this.currentPerformances,
    this.previousPerformances,
    this.requiresLastSetVideo = false,
    required this.assignmentDate,
  });
}

class ActiveExercisePage extends StatelessWidget {
  final String trainingId;
  final String exerciseId;
  final ActiveExercisePageArgs? args;

  const ActiveExercisePage({
    super.key,
    required this.trainingId,
    required this.exerciseId,
    required this.args,
  });

  @override
  Widget build(BuildContext context) {
    final pageArgs = args;
    if (pageArgs == null) {
      return ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: ErrorWidget2(
              message: AppLocalizations.of(context).activeExerciseContextMissing,
              onRetry: null,
            ),
          ),
        ),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<TrainingBloc>.value(value: pageArgs.trainingBloc),
        BlocProvider(
          create: (_) => ActiveExerciseBloc(
            localStorage: sl<LocalStorage>().bindActiveWorkoutStore(),
            restTimerCoordinator: sl(),
            trainingExercise: pageArgs.trainingExercise,
            initialWeightKg: pageArgs.initialWeightKg,
          ),
        ),
      ],
      child: _ActiveExerciseView(
        trainingId: trainingId,
        exerciseId: exerciseId,
        args: pageArgs,
      ),
    );
  }
}

class _ActiveExerciseView extends StatefulWidget {
  final String trainingId;
  final String exerciseId;
  final ActiveExercisePageArgs args;

  const _ActiveExerciseView({
    required this.trainingId,
    required this.exerciseId,
    required this.args,
  });

  @override
  State<_ActiveExerciseView> createState() => _ActiveExerciseViewState();
}

class _ActiveExerciseViewState extends State<_ActiveExerciseView> {
  final String? _ownerSession = sl<LocalStorage>().sessionStamp;
  late final int _timerSessionRevision =
      sl<ExecutionTimerCoordinator>().sessionRevision;
  bool _bootstrapped = false;
  bool _handledCompletion = false;
  bool _allowPop = false;
  bool _popScheduled = false;
  bool _lastSetVideoPromptOpen = false;

  /// `last_set_video_reminder_enabled` as shown by the band (L5-D23 i): read
  /// once, then what the user last switched.
  bool? _reminderEnabled;
  String? _preparedLastSetFeedbackId;
  SetPerformanceResult? _pendingLastSetPerformance;
  int? _pendingLastSetNumber;

  /// True from the tap on «Registrar serie» until the set is dispatched or
  /// abandoned: repeated taps are ignored (motion card 8a).
  bool _logging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _popOnce() {
    if (!mounted || _popScheduled) return;

    _popScheduled = true;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _bootstrap() async {
    final storage = sl<LocalStorage>();
    final foreignWorkouts = storage.getForeignActiveWorkouts(widget.trainingId);

    if (foreignWorkouts.isNotEmpty) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(l10n.activeExerciseDiscardTitle),
            content: Text(l10n.activeExerciseDiscardMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.activeExerciseDiscardAction),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (shouldDiscard != true) {
        _popOnce();
        return;
      }

      if (storage.sessionStamp != _ownerSession) return;
      await storage.clearForeignActiveWorkouts(widget.trainingId);
    }

    if (!mounted) return;
    final bloc = context.read<ActiveExerciseBloc>();
    final startedState = bloc.stream.first;
    bloc.add(
      StartExercise(
        trainingId: widget.trainingId,
        exerciseId: widget.exerciseId,
        assignmentDate: widget.args.assignmentDate,
        sessionId: widget.args.sessionId,
      ),
    );

    final activeState = await startedState;
    if (!mounted) return;

    setState(() {
      _bootstrapped = true;
    });
    _preparedLastSetFeedbackId = activeState.lastSetFeedbackClientUploadId;
    if (activeState.isDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _beginCompletion(activeState);
      });
    }
  }

  Future<bool> _confirmExit() async {
    final state = context.read<ActiveExerciseBloc>().state;
    if (state.isDone) return true;

    if (state.completedSets == 0) {
      context.read<ActiveExerciseBloc>().add(const AbandonExercise());
      return true;
    }

    final l10n = AppLocalizations.of(context);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activeExerciseCloseTitle),
        content: Text(
          l10n.activeExerciseCloseMessage(state.registeredSets, state.totalSets),
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

    if (!mounted) return false;
    if (shouldLeave == true) {
      context.read<ActiveExerciseBloc>().add(const AbandonExercise());
      return true;
    }

    return false;
  }

  Future<void> _onCompleteSetPressed(
    ActiveExerciseState state,
    AppLocalizations l10n,
    WeightText weightText,
  ) async {
    if (_logging) return;
    setState(() => _logging = true);
    try {
      await _logSet(state, l10n, weightText);
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _logSet(
    ActiveExerciseState state,
    AppLocalizations l10n,
    WeightText weightText,
  ) async {
    final timeUnit = timePerformanceUnitForExercise(
      widget.args.trainingExercise,
    );
    final savedPerformance = _pendingLastSetNumber == state.currentSet
        ? _pendingLastSetPerformance
        : null;
    final performance =
        savedPerformance ??
        await showSetPerformanceSheet(
          context,
          l10n,
          exerciseName: widget.args.trainingExercise.exercise.name,
          setNumber: state.currentSet,
          prescribedReps: formatExercisePrescription(
            widget.args.trainingExercise,
          ),
          previousWeight: state.weightKg,
          currentPerformance: performanceForSet(
            widget.args.currentPerformances,
            state.currentSet,
          ),
          previousPerformance: performanceForSet(
            widget.args.previousPerformances,
            state.currentSet,
          ),
          previousSession: widget.args.previousPerformances,
          lastSetThisExecution: state.setPerformances.isEmpty
              ? null
              : state.setPerformances.last,
          targetCount: _target(state).count,
          // A restored RIR-only set (P3) keeps its stored RIR preselected.
          targetRir: state.currentUnregisteredRir ??
              widget.args.trainingExercise.targetRir,
          timeUnit: timeUnit,
          repsRequired: widget.args.trainingExercise.requestSetTracking,
          unitSystem: weightText.unitSystem,
          decimalSeparator: weightText.decimalSeparator,
        );
    // Null: dismissed, cancelled or a duplicate trigger. Nothing happened.
    if (!mounted || performance == null) return;

    String? feedbackId =
        _preparedLastSetFeedbackId ?? state.lastSetFeedbackClientUploadId;
    if (state.currentSet == state.totalSets &&
        widget.args.requiresLastSetVideo &&
        feedbackId == null) {
      feedbackId = await _prepareLastSetVideo(
        performance,
        state.currentSet,
        weightText,
      );
      if (!mounted || feedbackId == null) {
        _pendingLastSetPerformance = performance;
        _pendingLastSetNumber = state.currentSet;
        return;
      }
    }

    _pendingLastSetPerformance = null;
    _pendingLastSetNumber = null;
    context.read<ActiveExerciseBloc>().add(
      performance.skipped
          ? CompleteSet(lastSetFeedbackClientUploadId: feedbackId)
          : CompleteSet(
              reps: performance.reps,
              seconds: performance.seconds,
              weightKg: performance.weight,
              rir: performance.rir,
              lastSetFeedbackClientUploadId: feedbackId,
            ),
    );
  }

  void _beginCompletion(ActiveExerciseState state) {
    // This page owns the persisted sets; never replay them in a later session.
    if (_handledCompletion || _ownerSession == null ||
        sl<LocalStorage>().sessionStamp != _ownerSession) {
      return;
    }
    _handledCompletion = true;
    unawaited(_persistCompletionAndClose(state));
  }

  Future<void> _persistCompletionAndClose(ActiveExerciseState state) async {
    final completion = Completer<void>();
    context.read<TrainingBloc>().add(
      MarkExerciseCompleted(
        trainingExerciseId: widget.args.trainingExercise.id,
        exerciseId: widget.args.trainingExercise.exercise.id,
        completed: true,
        weightUsed: state.weightKg,
        sets: state.setPerformances,
        lastSetFeedbackClientUploadId: state.lastSetFeedbackClientUploadId,
        sessionId: state.sessionId,
        operationId: state.completionOperationId,
        sessionStamp: _ownerSession,
        completion: completion,
      ),
    );

    try {
      await completion.future;
      final storage = sl<LocalStorage>();
      if (storage.sessionStamp != _ownerSession) return;
      if (state.completionOperationId != null) {
        for (final draft in storage.getActiveWorkouts()) {
          if (draft.trainingId == widget.trainingId &&
              draft.completionOperationId == state.completionOperationId) {
            await storage.removeActiveWorkout(draft.exerciseId);
          }
        }
      }
      if (mounted) _popOnce();
    } catch (_) {
      _handledCompletion = false;
    }
  }

  /// Asks for the last set's video once [performance] (set [setNumber]) is
  /// saved (L5-D23 ii): its own sheet, never on its own when the last set
  /// starts. Null when nothing was queued; the caller keeps the set pending.
  Future<String?> _prepareLastSetVideo(
    SetPerformanceResult performance,
    int setNumber,
    WeightText weightText,
  ) async {
    final bloc = context.read<ActiveExerciseBloc>();
    final existingId =
        _preparedLastSetFeedbackId ?? bloc.state.lastSetFeedbackClientUploadId;
    if (existingId != null || _lastSetVideoPromptOpen || !mounted) {
      return existingId;
    }

    _lastSetVideoPromptOpen = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      final feedbackId = await _enqueueLastSetVideo(
        performance,
        setNumber,
        weightText,
      );
      if (!mounted || feedbackId == null) return null;
      _preparedLastSetFeedbackId = feedbackId;
      bloc.add(AttachLastSetFeedback(feedbackId));
      return feedbackId;
    } finally {
      _lastSetVideoPromptOpen = false;
    }
  }

  bool get _reminderOn =>
      _reminderEnabled ??=
          sl<LocalStorage>().getSetting<bool>(
            'last_set_video_reminder_enabled',
            defaultValue: true,
          ) ??
          true;

  /// «Recordármelo»: the same preference as Ajustes (on = true).
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

  /// The last-set video sheet (L5-D23 ii-iii); «Usar vídeo» queues with the
  /// same fields and the same session check as before E3b. «Cambiar»,
  /// «Cancelar», a dismissal or a router change queue nothing.
  Future<String?> _enqueueLastSetVideo(
    SetPerformanceResult performance,
    int setNumber,
    WeightText weightText,
  ) async {
    final l10n = AppLocalizations.of(context);
    final exercise = widget.args.trainingExercise.exercise;
    final performed = performance.skipped
        ? null
        : setValueLabel(
            l10n,
            SetPerformance(
              setNumber: setNumber,
              reps: performance.reps,
              seconds: performance.seconds,
              weightKg: performance.weight,
            ),
            weightText,
          );
    final choice = await showExomSheet<LastSetVideoChoice>(
      context: context,
      builder: (_) => LastSetVideoSheet(
        kicker: l10n.lastSetVideoSheetKicker(exercise.name, setNumber),
        setLabel: performed == null || performed.isEmpty
            ? l10n.setPerformanceTitle(setNumber)
            : l10n.lastSetVideoChosenSet(setNumber, performed),
        pickVideo: _pickLastSetVideo,
      ),
    );
    if (choice == null || !mounted || !context.mounted ||
        _ownerSession == null ||
        sl<LocalStorage>().sessionStamp != _ownerSession) {
      return null;
    }
    final picked = choice.file;
    final notes = choice.notes.trim();
    return sl<FeedbackUploadQueueService>().enqueue(
      expectedSession: _ownerSession,
      file: picked,
      contentType: _videoContentType(picked),
      mediaType: 'VIDEO',
      notes: notes.isEmpty ? null : notes,
      exerciseId: widget.args.trainingExercise.exercise.id,
      feedbackKind: 'LAST_SET',
      trainingId: widget.trainingId,
      trainingExerciseId: widget.args.trainingExercise.id,
      assignmentDate: widget.args.assignmentDate,
      sessionId: context.read<ActiveExerciseBloc>().state.sessionId,
      exerciseName: exercise.name,
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

  Future<File?> _pickLastSetVideo(ImageSource initialSource) async {
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

  Future<void> _openVideoPlayer() async {
    final videoUrl = widget.args.trainingExercise.exercise.videoUrl?.trim();
    if (videoUrl == null || videoUrl.isEmpty) return;

    final uri = Uri.tryParse(videoUrl);
    if (uri == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseVideoPlayerPage(
          title: widget.args.trainingExercise.exercise.name,
          videoUri: uri,
        ),
      ),
    );
  }

  bool _hasContent(String? value) => value != null && value.trim().isNotEmpty;

  bool get _hasVideo {
    final url = widget.args.trainingExercise.exercise.videoUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  List<TechniqueSection> _techniqueSections(AppLocalizations l10n) {
    final exercise = widget.args.trainingExercise.exercise;
    return [
      if (_hasContent(exercise.techniqueText))
        (title: l10n.technique, text: exercise.techniqueText!.trim()),
      if (_hasContent(exercise.commonErrorsText))
        (title: l10n.commonMistakes, text: exercise.commonErrorsText!.trim()),
      if (_hasContent(exercise.explanationText))
        (title: l10n.explanation, text: exercise.explanationText!.trim()),
    ];
  }

  Future<void> _openTechnique(AppLocalizations l10n) async {
    final exercise = widget.args.trainingExercise.exercise;
    await showExerciseTechniqueSheet(
      context,
      exerciseName: exercise.name,
      hasVideo: _hasVideo,
      videoUrl: exercise.videoUrl,
      thumbnailUrl: exercise.thumbnailUrl,
      onOpenVideo: _openVideoPlayer,
      sections: _techniqueSections(l10n),
    );
  }

  /// «Ejercicio 2 de 6» from the training detail that opened this page, when
  /// it is still the loaded state of the shared TrainingBloc.
  String? _positionLabel(AppLocalizations l10n) {
    final trainingState = widget.args.trainingBloc.state;
    if (trainingState is! TrainingDetailLoaded ||
        trainingState.training.id != widget.trainingId) {
      return null;
    }
    final exercises = trainingState.training.exercises;
    final index = exercises.indexWhere(
      (item) => item.id == widget.args.trainingExercise.id,
    );
    if (index < 0) return null;
    return l10n.activeExercisePosition(index + 1, exercises.length);
  }

  /// What comes after this exercise, for the rest after its last set: the
  /// first other exercise of the training, in list order, that is not
  /// completed yet in this execution (what the training detail offers next),
  /// read from the detail state that opened this page, as [_positionLabel].
  /// Null when every
  /// other exercise is done or the detail is not the loaded state.
  TrainingExerciseEntity? _nextExercise() {
    final trainingState = widget.args.trainingBloc.state;
    if (trainingState is! TrainingDetailLoaded ||
        trainingState.training.id != widget.trainingId) {
      return null;
    }
    final currentId = widget.args.trainingExercise.id;
    // The progress of this execution, as the detail paints it; a missing
    // session means nothing done. The day aggregate (every execution) would
    // skip exercises still pending after a «Nueva ejecución».
    final done =
        trainingState.sessionProgress[widget.args.sessionId]?.ids ??
        const <String>{};
    for (final exercise in trainingState.training.exercises) {
      if (exercise.id == currentId) continue;
      if (!done.contains(exercise.id)) {
        return exercise;
      }
    }
    return null;
  }

  _PrescriptionTarget _target(ActiveExerciseState state) =>
      _PrescriptionTarget.of(
        widget.args.trainingExercise,
        savedTotalSeconds: state.timedTotalSeconds,
      );

  double? _weightForSet(ActiveExerciseState state) => prefillWeightKg(
    today: performanceForSet(widget.args.currentPerformances, state.currentSet),
    sessionWeightKg: state.weightKg,
    previous: widget.args.previousPerformances,
    setNumber: state.currentSet,
  );

  Future<void> _close() async {
    final shouldClose = await _confirmExit();
    if (!mounted || !shouldClose) return;
    _popOnce();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exercise = widget.args.trainingExercise.exercise;
    // Read here (this widget's build), not inside the BlocBuilder callback.
    final weightText = WeightText.of(context);

    if (!_bootstrapped) {
      return ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: const Center(child: LoadingWidget()),
        ),
      );
    }

    return BlocListener<ActiveExerciseBloc, ActiveExerciseState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.currentSet != current.currentSet ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(
              state.errorMessage == ActiveExerciseState.otherExecutionMessage
                  ? AppLocalizations.of(context).activeExerciseOtherExecution
                  : localizedErrorTextOf(
                      context,
                      state.errorMessage,
                      fallback: (l10n) => l10n.activeExerciseSaveError,
                    ),
            )));
        }

        if (state.isDone) _beginCompletion(state);
      },
      child: BlocBuilder<ActiveExerciseBloc, ActiveExerciseState>(
        builder: (context, state) {
          final palette = context.exomPalette;
          final target = _target(state);
          final position = _positionLabel(l10n);

          return PopScope<void>(
            canPop: _allowPop,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final shouldClose = await _confirmExit();
              if (!context.mounted || !shouldClose) return;
              _popOnce();
            },
            child: ExomStaticBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        exerciseName: exercise.name,
                        position: position,
                        closeTooltip: l10n.activeExerciseCloseA11y,
                        onClose: _close,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                          child: _body(
                            context,
                            l10n,
                            state,
                            target,
                            weightText,
                          ),
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
                      trainingFooterBottomPadding(
                        platform: defaultTargetPlatform,
                        navigationInset: MediaQuery.viewPaddingOf(
                          context,
                        ).bottom,
                        systemGestureInset: MediaQuery.systemGestureInsetsOf(
                          context,
                        ).bottom,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: switch (state.status) {
                        ActiveExerciseStatus.executing => SizedBox(
                          key: const ValueKey('footer-executing'),
                          width: double.infinity,
                          child: ExomPrimaryButton(
                            label: l10n.activeExerciseLogSetButton,
                            trailingIcon: ExomIcons.forward,
                            busy: _logging,
                            onPressed: () =>
                                _onCompleteSetPressed(state, l10n, weightText),
                          ),
                        ),
                        ActiveExerciseStatus.resting => _RestingFooter(
                          key: ValueKey(
                            'footer-resting-${state.restEndsAt?.millisecondsSinceEpoch}',
                          ),
                          restEndsAt: state.restEndsAt!,
                          onSkip: () => context.read<ActiveExerciseBloc>().add(
                            const SkipRest(),
                          ),
                          onExtend: () => context
                              .read<ActiveExerciseBloc>()
                              .add(const ExtendRest()),
                          onFinished: (endsAt) => context
                              .read<ActiveExerciseBloc>()
                              .add(FinishRest(restEndsAt: endsAt)),
                        ),
                        ActiveExerciseStatus.finalResting => _RestingFooter(
                          key: ValueKey(
                            'footer-final-resting-${state.restEndsAt?.millisecondsSinceEpoch}',
                          ),
                          restEndsAt: state.restEndsAt!,
                          onSkip: () => context.read<ActiveExerciseBloc>().add(
                            const SkipRest(),
                          ),
                          onExtend: () => context
                              .read<ActiveExerciseBloc>()
                              .add(const ExtendRest()),
                          onFinished: (endsAt) => context
                              .read<ActiveExerciseBloc>()
                              .add(FinishRest(restEndsAt: endsAt)),
                        ),
                        ActiveExerciseStatus.done => SizedBox(
                          key: const ValueKey('footer-done'),
                          height: kExomButtonMinHeight,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  palette.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      },
                    ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ActiveExerciseState state,
    _PrescriptionTarget target,
    WeightText weightText,
  ) {
    final palette = context.exomPalette;
    final mutedStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      height: 1.4,
      color: palette.textSecondary,
    );
    // Rows pad themselves 20 from the edges; the load columns and the band of
    // the next set run edge to edge (`.pad`, `.x-cols`, `.x-band`).
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: child,
    );

    final weightKg = _weightForSet(state);
    final targetLabel = target.shortLabel(l10n);
    final chips = ActiveExerciseSetChips(
      totalSets: state.totalSets,
      completedSets: state.completedSets,
      currentSet: state.isExecuting ? state.currentSet : null,
      performances: state.setPerformances,
      targetLabel: targetLabel,
      weightText: weightText,
      unregisteredSets: state.unregisteredSets,
    );
    // The bloc emits before the Hive write; a failed write emits an error
    // message, so «saved on this phone» is shown only without one. Never
    // «synced»: sets travel in the exercise completion, not one by one.
    final savedStatus = state.registeredSets > 0 && state.errorMessage == null
        ? Semantics(
            container: true,
            liveRegion: true,
            child: ExomSyncStatus(
              key: const Key('active-exercise-set-status'),
              state: ExomSyncState.guardadaEnMovil,
              label: l10n.activeExerciseSetSavedStatus(
                state.registeredSets,
                l10n.syncStatusSavedOnDevice,
              ),
            ),
          )
        : null;
    final status = <Widget>[
      if (savedStatus != null) ...[
        const SizedBox(height: 8),
        pad(savedStatus),
      ],
    ];

    if (state.isResting) {
      final restEndsAt = state.restEndsAt!;
      final nextSet = state.isFinalResting ? null : state.currentSet;
      // After the last set the rest leads to the next exercise of the
      // training (a circuit is named by its block); after the last exercise,
      // to nothing, without a band.
      final nextExercise = nextSet == null ? _nextExercise() : null;
      final nextExerciseName = nextExercise == null
          ? null
          : nextExercise.blockId != null
          ? nextExercise.blockName ?? 'Circuito'
          : nextExercise.exercise.name;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pad(
            ExomTwoLineHeadline(
              first: l10n.activeExerciseRestHeadline,
              second: nextSet != null
                  ? l10n.activeExerciseRestThenSet(nextSet)
                  : nextExerciseName != null
                  ? l10n.activeExerciseRestThenExercise(nextExerciseName)
                  : l10n.activeExerciseRestExerciseDone,
            ),
          ),
          const SizedBox(height: 16),
          pad(
            RestCountdown(
              key: ValueKey(
                'rest-countdown-${restEndsAt.millisecondsSinceEpoch}',
              ),
              restEndsAt: restEndsAt,
              totalSeconds: state.restSeconds,
            ),
          ),
          if (nextSet != null && targetLabel != null) ...[
            const SizedBox(height: 24),
            _NextSetBand(
              setNumber: nextSet,
              targetLabel: targetLabel,
              weight: weightKg == null ? null : weightText(weightKg),
            ),
          ],
          if (nextExercise != null && nextExerciseName != null) ...[
            const SizedBox(height: 24),
            _NextExerciseBand(
              name: nextExerciseName,
              // A circuit tells its members' prescriptions inside it.
              target: nextExercise.blockId != null
                  ? null
                  : formatExercisePrescription(nextExercise),
            ),
          ],
          const SizedBox(height: 24),
          pad(chips),
          ...status,
        ],
      );
    }

    if (state.isDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pad(
            Semantics(
              header: true,
              child: Text(
                l10n.exerciseCompleted.toUpperCase(),
                style: ExomType.section.copyWith(color: palette.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 24),
          pad(chips),
          ...status,
        ],
      );
    }

    final previous = performanceForSet(
      widget.args.previousPerformances,
      state.currentSet,
    );
    final targetRir = widget.args.trainingExercise.targetRir;
    final sections = _techniqueSections(l10n);
    final hasTechnique = _hasVideo || sections.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pad(
          ExomTwoLineHeadline(
            first: l10n.setPerformanceTitle(state.currentSet),
            second: l10n.activeExerciseSetOfLine(state.totalSets),
            semanticsLabel: l10n.activeExerciseSetOf(
              state.currentSet,
              state.totalSets,
            ),
          ),
        ),
        const SizedBox(height: 16),
        pad(
          PrescriptionHero(
            target: PrescriptionTarget(
              timeUnit: target.timeUnit,
              value: target.value,
              max: target.max,
              seconds: target.seconds,
            ),
            targetRir: targetRir,
            prescription: formatExercisePrescription(
              widget.args.trainingExercise,
              savedTotalSeconds: state.timedTotalSeconds,
              savedTimedPrescription: state.timedPrescription,
            ),
            numeralKey: const Key('active-exercise-target'),
            skin: PrescriptionHeroSkin.l5,
          ),
        ),
        const SizedBox(height: 24),
        _loadColumns(
          l10n: l10n,
          weightKg: weightKg,
          previous: previous,
          weightText: weightText,
        ),
        if (showsLastSetVideoReminder(
          requiresLastSetVideo: widget.args.requiresLastSetVideo,
          isExecuting: state.isExecuting,
          currentSet: state.currentSet,
          totalSets: state.totalSets,
          completedSets: state.completedSets,
          feedbackId:
              _preparedLastSetFeedbackId ?? state.lastSetFeedbackClientUploadId,
        )) ...[
          const SizedBox(height: 24),
          _LastSetVideoReminder(
            enabled: _reminderOn,
            isLastSet: state.currentSet == state.totalSets,
            onChanged: _setReminder,
          ),
        ],
        if (state.isExecuting && state.timedTotalSeconds != null)
          pad(
            ExecutionTimer(
              state: state,
              coordinator: sl<ExecutionTimerCoordinator>(),
              isOwnerCurrent: () => isExecutionTimerOwnerCurrent(
                _ownerSession,
                _timerSessionRevision,
              ),
              runKey: (widget.trainingId, widget.exerciseId,
                  widget.args.assignmentDate, widget.args.sessionId),
            ),
          ),
        const SizedBox(height: 24),
        pad(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExomKicker(l10n.sets),
          ),
        ),
        const SizedBox(height: 8),
        pad(chips),
        ...status,
        if (state.restSeconds > 0) ...[
          const SizedBox(height: 8),
          pad(
            Text(
              l10n.activeExerciseRestAfter(state.restSeconds),
              style: mutedStyle,
            ),
          ),
        ],
        if (hasTechnique) ...[
          const SizedBox(height: 8),
          pad(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExomTextLink(
                key: const Key('active-exercise-technique'),
                label: l10n.activeExerciseTechniqueButton,
                // Play with a video; a plain link with only texts (as the
                // circuit, L5-E5).
                icon: _hasVideo ? ExomIcons.play : null,
                onTap: () => _openTechnique(l10n),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// «Tu peso» and «Última vez» in two columns between hairlines (`.x-cols`,
/// `e-load`, `e-ref`) with the shared [ExomFigureColumns] and its labels
/// above, as the circuit (L5-E5): today's weight is the protagonist load at 64
/// in the data colour; the last session's same set is a reference in the text
/// colour at 56 with its reps and RIR below. Without today's weight only the
/// reference column is shown; without a previous set it says so. The component
/// stacks the columns when they do not fit.
ExomFigureColumns _loadColumns({
  required AppLocalizations l10n,
  required double? weightKg,
  required SetPerformance? previous,
  required WeightText weightText,
}) {
  final kg = weightKg;
  return ExomFigureColumns(
    numbered: false,
    labelsAbove: true,
    items: [
      if (kg != null)
        ExomFigure(
          itemKey: const Key('active-exercise-your-weight'),
          value: weightText.number(kg),
          unit: weightText.symbol,
          label: l10n.activeExerciseYourWeightLabel,
          size: ExomFigureSize.s64,
          semanticsLabel: l10n.activeExerciseYourWeight(weightText(kg)),
        ),
      _previousFigure(l10n, previous, weightText),
    ],
  );
}

/// «Última vez»: the figure is the weight when there was one, else the reps or
/// seconds; what is left (reps, seconds, RIR) goes below it. Without a
/// previous set, no figure and «Sin datos anteriores» below the label.
ExomFigure _previousFigure(
  AppLocalizations l10n,
  SetPerformance? previous,
  WeightText weightText,
) {
  const key = Key('active-exercise-previous');
  final set = previous;
  final label = set == null
      ? null
      : setValueLabel(l10n, set, weightText, withRir: true);
  if (set == null || label == null || label.isEmpty) {
    return ExomFigure(
      itemKey: key,
      value: '',
      label: l10n.exerciseLastTimeLabel,
      tone: ExomFigureTone.text,
      detail: l10n.activeExerciseNoPrevious,
      semanticsLabel:
          '${l10n.exerciseLastTimeLabel}: ${l10n.activeExerciseNoPrevious}',
    );
  }
  final kg = set.weightKg;
  final (String value, String unit) = kg != null
      ? (weightText.number(kg), weightText.symbol)
      : set.reps != null
      ? ('${set.reps}', l10n.activeExerciseUnitReps)
      : set.seconds != null
      ? ('${set.seconds}', l10n.activeExerciseUnitSeconds)
      : ('', '');
  final rest = [
    if (kg != null && set.reps != null)
      '${set.reps} ${l10n.activeExerciseUnitReps}',
    if (kg != null && set.seconds != null)
      '${set.seconds} ${l10n.activeExerciseUnitSeconds}',
    if (set.rir != null) l10n.activeExerciseRir(set.rir!),
  ].join(' · ');
  return ExomFigure(
    itemKey: key,
    value: value,
    unit: value.isEmpty ? null : unit,
    label: l10n.exerciseLastTimeLabel,
    tone: ExomFigureTone.text,
    detail: value.isEmpty ? label : (rest.isEmpty ? null : rest),
    semanticsLabel: l10n.activeExerciseLastTimeA11y(label),
  );
}

/// Band of the next set during a rest (`.x-band`, «Siguiente»): the set in
/// the display face and its target with today's weight in the data colour.
/// Assistive technology reads the same sentence as before L5.
class _NextSetBand extends StatelessWidget {
  const _NextSetBand({
    required this.setNumber,
    required this.targetLabel,
    required this.weight,
  });

  final int setNumber;
  final String targetLabel;
  final String? weight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final load = weight;
    final bigStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 18,
      height: 1.4,
      color: palette.textPrimary,
    );
    return Semantics(
      container: true,
      label: load == null
          ? l10n.activeExerciseRestNext(setNumber, targetLabel)
          : l10n.activeExerciseRestNextWithWeight(
              setNumber,
              targetLabel,
              load,
            ),
      excludeSemantics: true,
      child: ExomBand(
        kicker: l10n.activeExerciseNextLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.setPerformanceTitle(setNumber).toUpperCase(),
                style: ExomType.headline2Section.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: targetLabel),
                    if (load != null) ...[
                      TextSpan(
                        text:
                            ' · ${l10n.activeExerciseRestNextWeightLabel} ',
                      ),
                      TextSpan(
                        text: load,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.data,
                        ),
                      ),
                    ],
                  ],
                ),
                key: const Key('active-exercise-rest-next'),
                style: bigStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Band of the next exercise during the rest after the last set (`.x-band`,
/// «Siguiente»): its name in the display face and its prescription below, as
/// [_NextSetBand] does for the next set. Read as one sentence.
class _NextExerciseBand extends StatelessWidget {
  const _NextExerciseBand({required this.name, required this.target});

  final String name;
  final String? target;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final prescription = target?.trim();
    final hasTarget = prescription != null && prescription.isNotEmpty;
    return Semantics(
      container: true,
      label: hasTarget
          ? l10n.circuitNextExercise(name, prescription)
          : l10n.restTimerNextExercise(name),
      excludeSemantics: true,
      child: ExomBand(
        key: const Key('active-exercise-rest-next-exercise'),
        kicker: l10n.activeExerciseNextLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.toUpperCase(),
                style: ExomType.headline2Section.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              if (hasTarget) ...[
                const SizedBox(height: 8),
                Text(
                  prescription,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 18,
                    height: 1.4,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
bool shouldPrepareLastSetVideo({
  required bool requiresLastSetVideo,
  required bool isExecuting,
  required int currentSet,
  required int totalSets,
  required int completedSets,
  required String? feedbackId,
}) {
  return requiresLastSetVideo &&
      isExecuting &&
      currentSet == totalSets &&
      completedSets < totalSets &&
      (feedbackId == null || feedbackId.isEmpty);
}

/// L5-D23 (i): the reminder band (or its minimal line when switched off) is
/// shown while the set before the last one, or the last one, is executing
/// and the last set still needs its video. Informative only: when the video
/// is mandatory does not change.
@visibleForTesting
bool showsLastSetVideoReminder({
  required bool requiresLastSetVideo,
  required bool isExecuting,
  required int currentSet,
  required int totalSets,
  required int completedSets,
  required String? feedbackId,
}) {
  bool lastSetAt(int set) => shouldPrepareLastSetVideo(
    requiresLastSetVideo: requiresLastSetVideo,
    isExecuting: isExecuting,
    currentSet: set,
    totalSets: totalSets,
    completedSets: completedSets,
    feedbackId: feedbackId,
  );
  return lastSetAt(currentSet) || lastSetAt(currentSet + 1);
}

@visibleForTesting
double trainingFooterBottomPadding({
  required TargetPlatform platform,
  required double navigationInset,
  required double systemGestureInset,
}) {
  const margin = 16.0;
  if (platform != TargetPlatform.android) return margin;

  // Gesture navigation normally reports the same bottom area in both insets.
  // A larger view padding means a persistent three-button navigation bar.
  final usesButtonNavigation =
      navigationInset > systemGestureInset + precisionErrorTolerance;
  return usesButtonNavigation
      ? navigationInset + margin
      : navigationInset.clamp(margin, double.infinity);
}

/// Target of the prescription for the hero numeral, the set chips and the
/// sheet prefill: a fixed value or a range, in reps or in time.
class _PrescriptionTarget {
  const _PrescriptionTarget({
    required this.timeUnit,
    this.value,
    this.max,
    this.seconds,
  });

  /// Null for reps.
  final TimePerformanceUnit? timeUnit;

  /// Number shown (reps, seconds or minutes); null when the prescription is
  /// free text.
  final int? value;

  /// Upper end of a range («8–10»).
  final int? max;

  /// Timed prescriptions: total seconds (sheet prefill).
  final int? seconds;

  static final RegExp _leading = RegExp(r'^\s*(\d+)(?:\s*[-–]\s*(\d+))?');

  factory _PrescriptionTarget.of(
    TrainingExerciseEntity exercise, {
    int? savedTotalSeconds,
  }) {
    final timeUnit = timePerformanceUnitForExercise(exercise);
    final match = _leading.firstMatch(exercise.repsOrDuration);
    final textValue = int.tryParse(match?.group(1) ?? '');
    final textMax = int.tryParse(match?.group(2) ?? '');
    if (timeUnit == null) {
      if (exercise.targetValue != null) {
        return _PrescriptionTarget(timeUnit: null, value: exercise.targetValue);
      }
      if (exercise.targetValueMin != null && exercise.targetValueMax != null) {
        return _PrescriptionTarget(
          timeUnit: null,
          value: exercise.targetValueMin,
          max: exercise.targetValueMax,
        );
      }
      return _PrescriptionTarget(timeUnit: null, value: textValue, max: textMax);
    }
    final minutesText =
        exercise.measureType == null && timeUnit == TimePerformanceUnit.minutes;
    final total =
        savedTotalSeconds ??
        exercise.targetValue ??
        (textValue == null ? null : textValue * (minutesText ? 60 : 1));
    if (total == null) {
      if (exercise.targetValueMin != null && exercise.targetValueMax != null) {
        final inMinutes =
            timeUnit == TimePerformanceUnit.minutes &&
            exercise.targetValueMin! % 60 == 0 &&
            exercise.targetValueMax! % 60 == 0;
        return _PrescriptionTarget(
          timeUnit: inMinutes
              ? TimePerformanceUnit.minutes
              : TimePerformanceUnit.seconds,
          value: inMinutes
              ? exercise.targetValueMin! ~/ 60
              : exercise.targetValueMin,
          max: inMinutes
              ? exercise.targetValueMax! ~/ 60
              : exercise.targetValueMax,
          seconds: exercise.targetValueMin,
        );
      }
      return _PrescriptionTarget(timeUnit: timeUnit);
    }
    final inMinutes = timeUnit == TimePerformanceUnit.minutes && total % 60 == 0;
    return _PrescriptionTarget(
      timeUnit: inMinutes
          ? TimePerformanceUnit.minutes
          : TimePerformanceUnit.seconds,
      value: inMinutes ? total ~/ 60 : total,
      seconds: total,
    );
  }

  /// Reps or seconds the sheet starts from when nothing else applies.
  int? get count => timeUnit == null ? value : seconds;

  /// «8», «8–10».
  String? get numeral {
    final v = value;
    if (v == null) return null;
    final m = max;
    return m == null ? '$v' : '$v–$m';
  }

  String unitLabel(AppLocalizations l10n) => switch (timeUnit) {
    null => l10n.activeExerciseUnitReps,
    TimePerformanceUnit.seconds => l10n.activeExerciseUnitSeconds,
    TimePerformanceUnit.minutes => l10n.activeExerciseUnitMinutes,
  };

  /// «8 reps», «45 s», «10 min»; null for free-text prescriptions.
  String? shortLabel(AppLocalizations l10n) {
    final n = numeral;
    return n == null ? null : '$n ${unitLabel(l10n)}';
  }
}

/// Header of the active exercise: close (48x48, labelled; it goes through
/// `_confirmExit` like system back), exercise name in the display face (wraps,
/// never ellipsized) and «Ejercicio 2 de 6».
class _Header extends StatelessWidget {
  const _Header({
    required this.exerciseName,
    required this.position,
    required this.closeTooltip,
    required this.onClose,
  });

  final String exerciseName;
  final String? position;
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
            key: const Key('active-exercise-close'),
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
                      exerciseName.toUpperCase(),
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
                  if (position != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      position!,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFontFamily,
                        fontSize: 14,
                        height: 1.4,
                        color: palette.textSecondary,
                      ),
                    ),
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

/// Footer of a rest: «+30 s» (secondary) and «Saltar descanso» (quiet),
/// separated. It owns the timer that dispatches `FinishRest` when the rest
/// reaches zero while mounted; callers key it by `restEndsAt` so each rest
/// (and each extension) gets fresh state. [onFinished] receives the end it
/// was built for, so a tick of an outgoing footer (after «+30 s») is stale
/// for the bloc and ignored.
class _RestingFooter extends StatefulWidget {
  final DateTime restEndsAt;
  final VoidCallback onSkip;
  final VoidCallback onExtend;
  final ValueChanged<DateTime> onFinished;

  const _RestingFooter({
    super.key,
    required this.restEndsAt,
    required this.onSkip,
    required this.onExtend,
    required this.onFinished,
  });

  @override
  State<_RestingFooter> createState() => _RestingFooterState();
}

class _RestingFooterState extends State<_RestingFooter> {
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
          key: const Key('active-exercise-rest-extend'),
          label: l10n.activeExerciseRestExtend(30),
          onPressed: widget.onExtend,
        ),
        const SizedBox(height: 12),
        Center(
          child: ExomQuietButton(
            key: const Key('active-exercise-rest-skip'),
            label: l10n.activeExerciseRestSkip,
            onPressed: widget.onSkip,
          ),
        ),
      ],
    );
  }
}

/// Opens the set sheet and returns its result only after the sheet subtree
/// has been disposed (contract kept from the pre-L3 sheet: the caller cannot
/// replace or pop the page while the sheet still owns inherited dependencies
/// and text inputs). Null means nothing happened: dismissed, «Cancelar», or a
/// repeated trigger while a sheet opened from [context] is still open
/// (`showExomSheet`).
///
/// Prefill (D4) is resolved here with the pure functions of
/// `set_prefill.dart`: weight = today's set → [previousWeight] (last weight of
/// this execution, or the exercise's initial weight) → previous session's
/// same set → its last weighted set; reps/seconds = today's set →
/// [lastSetThisExecution] → [previousPerformance] → [targetCount]; RIR =
/// today's set, or [targetRir] for a new set.
@visibleForTesting
Future<SetPerformanceResult?> showSetPerformanceSheet(
  BuildContext context,
  AppLocalizations l10n, {
  required int setNumber,
  required String prescribedReps,
  required bool repsRequired,
  required TimePerformanceUnit? timeUnit,
  double? previousWeight,
  SetPerformance? currentPerformance,
  SetPerformance? previousPerformance,
  List<SetPerformance>? previousSession,
  SetPerformance? lastSetThisExecution,
  int? targetCount,
  int? targetRir,
  UnitSystem unitSystem = UnitSystem.metric,
  String? decimalSeparator,
  String? exerciseName,
}) {
  final timed = timeUnit != null;
  final separator =
      decimalSeparator ??
      decimalSeparatorFor(Localizations.localeOf(context).languageCode);
  final initialCount = prefillCount(
    today: currentPerformance,
    lastThisExecution: lastSetThisExecution,
    previousSameSet: previousPerformance,
    target: targetCount,
    timed: timed,
  );
  final initialWeightKg = prefillWeightKg(
    today: currentPerformance,
    sessionWeightKg: previousWeight,
    previous: previousSession ??
        (previousPerformance == null ? null : [previousPerformance]),
    setNumber: setNumber,
  );
  return showExomSheet<SetPerformanceResult>(
    context: context,
    builder: (_) => SetPerformanceSheet(
      title: l10n.setPerformanceTitle(setNumber),
      kicker: exerciseName == null
          ? null
          : l10n.setSheetExerciseKicker(exerciseName),
      objective: prescribedReps,
      timeUnit: timeUnit,
      countRequired: repsRequired,
      unitSystem: unitSystem,
      decimalSeparator: separator,
      initialCount: initialCount,
      initialWeightKg: initialWeightKg,
      initialRir: prefillRir(today: currentPerformance, targetRir: targetRir),
      previous: previousPerformance,
      today: currentPerformance,
    ),
  );
}

/// L5-D23 (i), sketch frames `f-ej-ult` and `f-ej-ult-off`: before the last
/// set, the video reminder is an informative band («Prepárate para grabar»,
/// the same message as the old dialog) with the «Recordármelo» switch on;
/// switched off, one flat row with the same switch to turn it back on. The
/// switch writes `last_set_video_reminder_enabled`, as Ajustes. The switch
/// is in the text colour, never lime.
class _LastSetVideoReminder extends StatelessWidget {
  const _LastSetVideoReminder({
    required this.enabled,
    required this.isLastSet,
    required this.onChanged,
  });

  final bool enabled;

  /// The band also shows on the last set itself: there «the next one is the
  /// last» would be wrong (r3, D1).
  final bool isLastSet;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    if (!enabled) {
      return ExomFlatRowGroup(
        children: [
          MergeSemantics(
            key: const Key('last-set-video-reminder-off'),
            child: Semantics(
              toggled: false,
              child: ExomFlatRow(
                title: l10n.lastSetVideoRemindMe,
                subtitles: [l10n.lastSetVideoReminderOption],
                trailing: const ExcludeSemantics(
                  child: ExomSquareSwitch(value: false),
                ),
                onTap: () => onChanged(true),
              ),
            ),
          ),
        ],
      );
    }
    return ExomBand(
      key: const Key('last-set-video-reminder'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExomKicker(
                l10n.upcomingLastSetTitle,
                icon: ExomIcons.camera,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              isLastSet
                  ? l10n.currentLastSetMessage
                  : l10n.upcomingLastSetMessage,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          ExomSwitchRow(
            label: l10n.lastSetVideoRemindMe,
            value: true,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
