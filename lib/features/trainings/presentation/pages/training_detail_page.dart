import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart' show Drag;
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/trainings/presentation/utils/session_date_label.dart';
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
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_large_text.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_scroll_away_footer.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_app_bar.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/core/widgets/home_session_photo.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/planned_sets.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/training_milestone_page.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/utils/exercise_text_bullets.dart';
import 'package:exom_app/features/trainings/presentation/widgets/discard_foreign_progress_dialog.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_bullet_list.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_sync_state.dart';
import 'package:exom_app/features/trainings/presentation/widgets/last_set_video_status.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rerecord_last_set_video.dart';
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

/// Opens the closing sheet «Terminar sesión» (L5-E2b, decision L5-D22; sketch
/// `e-migradas.html`, frame `f-fin-hoja`) and returns the RPE and note to send
/// with `CompleteTrainingRequested`, or null when nothing must be sent.
///
/// Same contract as the confirmation dialog it replaces: the RPE (1-10) is
/// required; the note is returned trimmed, or null when blank; the completion
/// draft of [executionId] is read when the sheet opens (its note wins over
/// [initialNote]) and written on every change, and again (awaiting the pending
/// writes) before cancelling or confirming. If that last write fails (for
/// example the local session changed) the sheet stays open. Cancel, a tap
/// outside, back, a drag down and a router location change close it without
/// a result. A repeated tap on «Terminar sesión» sends once. When
/// [pendingExercises] is positive it warns that confirming marks every pending
/// exercise as completed (owner decision 2026-11-25).
Future<TrainingCompletionInput?> showCompleteTrainingSheet(
  BuildContext context, {
  required LocalStorage storage,
  required String trainingId,
  required String date,
  required String executionId,
  required String? sessionStamp,
  String? trainingName,
  String? initialNote,
  int pendingExercises = 0,
}) async {
  final form = _CompletionForm(
    storage: storage, trainingId: trainingId, date: date,
    executionId: executionId, sessionStamp: sessionStamp,
    initialNote: initialNote);
  try {
    return await showExomSheet<TrainingCompletionInput>(
      context: context,
      builder: (_) => _CompletionSheetBody(form: form,
        trainingName: trainingName, pendingExercises: pendingExercises),
      actions: [
        _CompletionConfirmAction(form: form),
        _CompletionCancelAction(form: form),
      ],
    );
  } finally {
    // The sheet subtree is gone; release the note once pending writes end.
    form.releaseWhenIdle();
  }
}

enum _CompletionSaving { none, cancel, confirm }

/// State of the closing sheet, shared by its body and its pinned actions.
class _CompletionForm extends ChangeNotifier {
  _CompletionForm({required this.storage, required this.trainingId,
    required this.date, required this.executionId, required this.sessionStamp,
    String? initialNote}) {
    final draft = storage.getTrainingCompletionDraft(trainingId, date, executionId);
    rpe = draft?['rpe'] as int?;
    note = TextEditingController(text: draft?['notes'] as String? ?? initialNote);
  }

  final LocalStorage storage;
  final String trainingId;
  final String date;
  final String executionId;
  final String? sessionStamp;
  int? rpe;
  late final TextEditingController note;
  _CompletionSaving saving = _CompletionSaving.none;
  Future<void> _pendingSave = Future<void>.value();
  bool _released = false;

  bool get isSaving => saving != _CompletionSaving.none;

  void selectRpe(int? value) {
    if (isSaving) return;
    rpe = value;
    notifyListeners();
    saveDraft();
  }

  void saveDraft() {
    _pendingSave = _pendingSave.then((_) => _persist()).catchError((Object _) {
      // The confirm path retries persistence and stays open if it fails.
    });
  }

  Future<void> _persist() async {
    if (sessionStamp == null || storage.sessionStamp != sessionStamp) {
      throw const LocalSessionChanged();
    }
    await storage.saveTrainingCompletionDraft(trainingId, date, executionId,
      rpe: rpe, notes: note.text);
  }

  void _setSaving(_CompletionSaving value) {
    if (_released) return;
    saving = value;
    notifyListeners();
  }

  /// Waits for the pending draft writes and writes the draft once more.
  Future<bool> _flush(_CompletionSaving reason) async {
    _setSaving(reason);
    final done = _pendingSave.then((_) => _persist());
    _pendingSave = done.catchError((Object _) {});
    try {
      await done;
      return true;
    } catch (_) {
      _setSaving(_CompletionSaving.none);
      return false;
    }
  }

  Future<void> cancel(BuildContext context) async {
    if (isSaving) return;
    if (await _flush(_CompletionSaving.cancel) && context.mounted) {
      _popIfCurrent(context, null);
    }
  }

  Future<void> confirm(BuildContext context) async {
    if (isSaving || rpe == null) return;
    if (await _flush(_CompletionSaving.confirm) && context.mounted) {
      final text = note.text.trim();
      _popIfCurrent(context, TrainingCompletionInput(
        rpe: rpe, notes: text.isEmpty ? null : text));
    }
  }

  /// Pops the sheet with [result] only while it is still the current route:
  /// once a router change (or anything else) has closed it, a late write must
  /// not pop the page underneath nor deliver a result. If the sheet is still
  /// open under another route, its actions are freed instead.
  void _popIfCurrent(BuildContext context, TrainingCompletionInput? result) {
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) {
      _setSaving(_CompletionSaving.none);
      return;
    }
    Navigator.of(context).pop(result);
  }

  void releaseWhenIdle() {
    _pendingSave.whenComplete(() {
      _released = true;
      note.dispose();
      dispose();
    });
  }
}

/// Body of the closing sheet (`f-fin-hoja`): the session as kicker, the
/// title, the warning about pending exercises (only when there are any), the
/// RPE question with its explanation and the 1-10 scale (D16), and the
/// optional note.
class _CompletionSheetBody extends StatelessWidget {
  const _CompletionSheetBody({required this.form, required this.trainingName,
    required this.pendingExercises});

  final _CompletionForm form;
  final String? trainingName;
  final int pendingExercises;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final name = trainingName?.trim() ?? '';
    final title = l10n.completeTrainingSheetTitle;
    final labelStyle = TextStyle(fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16, fontWeight: FontWeight.w600, height: 1.3,
      color: palette.textPrimary);
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) => Padding(
        key: const Key('complete-training-confirmation'),
        padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (name.isNotEmpty) ...[
              Align(alignment: AlignmentDirectional.centerStart,
                child: ExomKicker(name)),
              const SizedBox(height: ExomSpacing.xs),
            ],
            Semantics(
              header: true,
              label: title,
              excludeSemantics: true,
              child: Text(title.toUpperCase(),
                style: ExomType.headline2Section.copyWith(color: palette.textPrimary)),
            ),
            if (pendingExercises > 0) ...[
              const SizedBox(height: 10),
              Text(l10n.completeTrainingConfirmMessage,
                key: const Key('completion-pending-notice'),
                style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 14, height: 1.35, color: palette.textSecondary)),
            ],
            const SizedBox(height: 18),
            Text(l10n.completeTrainingRpeQuestion, style: labelStyle),
            const SizedBox(height: 6),
            Text(l10n.completeTrainingRpeExplanation,
              style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                fontSize: 14, height: 1.35, color: palette.textSecondary)),
            const SizedBox(height: 12),
            if (form.rpe != null) const SizedBox(key: Key('completion-rpe-selected')),
            ExomScaleChips(
              min: 1,
              max: 10,
              selected: form.rpe,
              allowDeselect: true,
              chipKeyOf: (value) => Key('completion-rpe-$value'),
              onChanged: form.isSaving ? null : form.selectRpe,
            ),
            const SizedBox(height: 18),
            MergeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.addQuickNoteOptional, style: labelStyle),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('completion-note'),
                    controller: form.note,
                    onChanged: (_) => form.saveDraft(),
                    minLines: 3,
                    maxLines: 4,
                    style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 16, color: palette.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Terminar sesión»: disabled until an RPE is chosen, busy while the last
/// draft write runs (a repeated tap is ignored).
class _CompletionConfirmAction extends StatelessWidget {
  const _CompletionConfirmAction({required this.form});

  final _CompletionForm form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) => ExomPrimaryButton(
        key: const Key('confirm-complete-training'),
        label: l10n.completeTrainingSheetAction,
        trailingIcon: ExomIcons.check,
        busy: form.saving == _CompletionSaving.confirm,
        onPressed: form.rpe == null || form.saving == _CompletionSaving.cancel
            ? null
            : () => form.confirm(context),
      ),
    );
  }
}

class _CompletionCancelAction extends StatelessWidget {
  const _CompletionCancelAction({required this.form});

  final _CompletionForm form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) => ExomQuietButton(
        key: const Key('cancel-complete-training'),
        label: l10n.cancel,
        onPressed: form.isSaving ? null : () => form.cancel(context),
      ),
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

/// O7: after the route finishes entering, the pinned footer actions still
/// ignore taps for this long. Inicio's «Empezar sesión» and the detail's
/// «Siguiente» share the same spot, so a repeated tap ~0,5 s after opening
/// (route entry is `ExomMotion.pushIn`, 240 ms) landed on «Siguiente» and
/// created a session with 0 sets. Entry plus this margin ends ~640 ms after
/// the push, before a deliberate tap on a just-shown screen is realistic.
const Duration _footerEntryTapGuard = Duration(milliseconds: 400);

class _TrainingDetailPageState extends State<TrainingDetailPage> {
  late final String? _sessionStamp;

  /// Whether the pinned footer actions accept taps (O7). True at once when
  /// the route is already in place (no entry transition to wait for).
  final _footerArmed = ValueNotifier<bool>(false);
  Timer? _footerArmTimer;

  @override
  void initState() {
    super.initState();
    _sessionStamp = sl<LocalStorage>().sessionStamp;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_footerArmed.value || _footerArmTimer != null) return;
    final route = ModalRoute.of(context);
    // On the first frame of a push the route is offstage and its animation
    // reports «completed» (Hero measuring), so «offstage» also means entering.
    final entering = route != null &&
        (route.offstage ||
            route.animation?.status != AnimationStatus.completed);
    if (!entering) {
      // Built on a route already in place: no entry to wait for.
      _footerArmed.value = true;
      return;
    }
    // The page is built when the push starts: arm once its entry has run
    // ([TransitionRoute.transitionDuration]) plus the margin. A plain timer
    // cannot leave the footer disarmed if no animation event ever arrives.
    _footerArmTimer =
        Timer(route.transitionDuration + _footerEntryTapGuard, () {
      if (mounted) _footerArmed.value = true;
    });
  }

  @override
  void dispose() {
    _footerArmTimer?.cancel();
    _footerArmed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<TrainingBloc>()
            ..add(TrainingDetailLoadRequested(widget.trainingId, date: widget.selectedDate)),
      child: _TrainingDetailView(
        footerArmed: _footerArmed,
        sessionStamp: _sessionStamp,
        selectedExecutionId: widget.selectedExecutionId,
        finalizeSelected: widget.finalizeSelected,
      ),
    );
  }
}

class _TrainingDetailView extends StatelessWidget {
  const _TrainingDetailView({required this.footerArmed,
    required this.sessionStamp,
    required this.selectedExecutionId, required this.finalizeSelected});

  final ValueListenable<bool> footerArmed;
  final String? sessionStamp;
  final String? selectedExecutionId;
  final bool finalizeSelected;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrainingBloc, TrainingState>(
      listener: (context, state) {
        if (state is TrainingDetailLoaded && state.errorMessage != null) {
          final colors = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizedErrorTextOf(context, state.errorMessage, fallback: (l10n) => l10n.trainingProgressSaveError),
                style: TextStyle(color: colors.onError),
              ),
              backgroundColor: colors.error,
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
            footerArmed: footerArmed,
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

/// Loading state with the shape of the loaded detail (L5 skeletons): the photo
/// slot, the title, the figures rule and the exercise rows, with the pinned
/// footer below. Same back action as the loaded page.
class _TrainingDetailLoadingScaffold extends StatelessWidget {
  const _TrainingDetailLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ExomAppBar(
          leading: _DetailBackButton(onPressed: () => context.pop()),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: ExomSpacing.xxl),
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(top: ExomSpacing.lg),
                child: SizedBox(
                  height: HomeSessionPhoto.height,
                  child: ColoredBox(color: palette.surfaceElevated),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExomSkeleton.headline(),
                  SizedBox(height: ExomSpacing.lg),
                  ExomSkeleton.rule(),
                ],
              ),
            ),
            for (var i = 0; i < 4; i++) const ExomSkeleton.row(),
          ],
        ),
        bottomNavigationBar: ExomPinnedFooter(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          child: ExcludeSemantics(
            child: SizedBox(
              height: kExomButtonMinHeight,
              child: ColoredBox(color: palette.surfaceElevated),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailScaffold extends StatefulWidget {
  final ValueListenable<bool> footerArmed;
  final TrainingDetailLoaded state;
  final String? sessionStamp;
  final String? selectedExecutionId;
  final bool finalizeSelected;

  const _DetailScaffold({required this.footerArmed,
    required this.state, required this.sessionStamp,
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
  bool _milestoneOpen = false;
  bool _rerecording = false;
  _DetailSnackBar? _missingVideoNotice;
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
              for (final (index, entry) in pending.indexed)
                ListTile(
                  title: Text('${training.name} · ${sessionDateLabel(dialogContext, date)}'),
                  subtitle: Text(l10n.trainingExecutionLabel(index + 1)),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FB1 r4 (D2): the missing-video message goes once a route covers this
    // detail or it is popped (depends on the route's `isCurrent`).
    if (ModalRoute.isCurrentOf(context) == false) _missingVideoNotice?.dismiss();
    // L5-D63: back to the fixed footer (smaller text or a screen reader), the
    // next time it scrolls away it starts shown.
    if (!exomScrollAwayFooterEnabled(context)) _footerVisibility.show();
  }

  @override
  void didUpdateWidget(covariant _DetailScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.training.id != oldWidget.state.training.id ||
        widget.state.selectedDate != oldWidget.state.selectedDate) {
      _missingVideoNotice?.dismiss();
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
    // FB1: only a video never attached blocks here. A failed one is kept on
    // the phone like one still uploading: the completion is queued and waits
    // for it (`depends_on_feedback_ids`), and its row offers to record it
    // again.
    if (training.requiresLastSetVideo) {
      final feedback = storage.getFeedbackUploadQueue();
      final missing = training.exercises
          .where((exercise) =>
              _videoOf(feedback, exercise, sessionId).state ==
              LastSetVideoState.missing)
          .toList(growable: false);
      if (missing.isNotEmpty) {
        setState(() => _completeConfirmationOpen = false);
        final message = Text(l10n.trainingLastSetVideoMissingFor(
          missing.map((exercise) => exercise.exercise.name).join(', ')));
        void openExercise() {
          if (_sameSession) _openForVideo(training, missing.first);
        }
        // FB1 r4 (D1): the theme's SnackBar is the raised surface and sets no
        // action colour, so Material's inverse default is unreadable on it.
        // The palette's accent text reads on that surface in both themes.
        final actionColor = context.exomPalette.primary;
        // FB1 r4 (D2): a fresh message replaces this detail's previous one.
        _missingVideoNotice?.dismiss();
        final notice = _missingVideoNotice =
            _DetailSnackBar(ScaffoldMessenger.of(context));
        // FB1 r3 (FB1-R2-O2): Material does not wrap an action label, so with
        // large text the action goes under the message, at its start, and
        // wraps like it. It persists until tapped, as a SnackBarAction does.
        notice.show(_isLargeText(context)
            ? SnackBar(
                persist: true,
                onVisible: notice.visible,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    message,
                    const SizedBox(height: 4),
                    _StackedSnackBarAction(
                      label: l10n.trainingLastSetVideoOpenExercise,
                      color: actionColor,
                      onPressed: openExercise,
                    ),
                  ],
                ),
              )
            : SnackBar(
                onVisible: notice.visible,
                content: message,
                action: SnackBarAction(
                  label: l10n.trainingLastSetVideoOpenExercise,
                  textColor: actionColor,
                  onPressed: openExercise,
                ),
              ));
        return;
      }
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
        : await showCompleteTrainingSheet(context,
            storage: storage, trainingId: training.id,
            date: widget.state.selectedDate, executionId: sessionId,
            sessionStamp: widget.sessionStamp, trainingName: training.name,
            initialNote: _notesController.text.trim(),
            pendingExercises: training.exercises
                .where((exercise) => !_progress.ids.contains(exercise.id))
                .length);
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
    _openMilestone(router);
  }

  /// L5-E6a: the server confirmed the completion, so the milestone «Sesión
  /// hecha» opens over the detail (local push, no router path). Leaving it runs
  /// the navigation that used to happen here, once; if the account changed
  /// meanwhile it closes without navigating.
  Future<void> _openMilestone(GoRouter router) async {
    if (_milestoneOpen) return;
    _milestoneOpen = true;
    final training = widget.state.training;
    final stamp = widget.sessionStamp;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TrainingMilestonePage(
          trainingName: training.name,
          exercises: training.exercises.length,
          sets: tallyPlannedSets(
            training.exercises,
            plannedSets: _plannedSetsOfExercise,
            isCompleted: (_) => false,
          ).total,
          isSameSession: () =>
              stamp != null && sl<LocalStorage>().sessionStamp == stamp,
          // E6a: what the server confirmed, so Inicio paints it at once.
          onContinue: () => router.go(
            AppRoutes.home,
            extra: HomeCompletionRefresh(
              trainingId: training.id,
              date: widget.state.selectedDate,
              sessionStamp: stamp,
            ),
          ),
        ),
      ),
    );
    _milestoneOpen = false;
  }

  @override
  void dispose() {
    _missingVideoNotice?.dismiss();
    _syncChanges?.cancel();
    _feedbackChanges?.cancel();
    _notesController.dispose();
    _footerVisibility.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Footer visibility while it scrolls away with large text (L5-D63).
  final _footerVisibility = ExomScrollAwayFooterController();

  /// The list's primary scroll controller: its programmatic scrolls never
  /// count as the user's for [_footerVisibility] (L5-D63).
  final _scrollController = ExomScrollAwayFooterScrollController();

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
    // L5-D64: the active exercise saved by another training is asked about
    // here, over this detail, before the exercise route exists. Asked from
    // that route's first frame (as before) the dialog covered a page with
    // nothing built yet. Same answers as there: cancel opens nothing and
    // keeps that progress; confirm discards it and opens the exercise.
    final storage = sl<LocalStorage>();
    if (storage.getForeignActiveWorkouts(training.id).isNotEmpty) {
      final discard = await confirmDiscardForeignProgress(context);
      if (!discard || !mounted || !context.mounted || !_sameSession) return;
      await storage.clearForeignActiveWorkouts(training.id);
      if (!mounted || !context.mounted || !_sameSession) return;
    }
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

  /// FB1: the last-set video of [exercise] in execution [sessionId].
  LastSetVideoStatus _videoOf(
    List<Map<String, dynamic>> feedback,
    TrainingExerciseEntity exercise,
    String? sessionId,
  ) => lastSetVideoStatus(
    queue: feedback,
    trainingId: widget.state.training.id,
    date: widget.state.selectedDate,
    sessionId: sessionId,
    trainingExerciseId: exercise.id,
  );

  /// Opens the exercise (or its circuit) whose last-set video is missing.
  void _openForVideo(TrainingEntity training, TrainingExerciseEntity exercise) {
    final group = _exerciseGroups(training)
        .where((group) => (group.blockExercises ?? [group.leader])
            .any((member) => member.id == exercise.id))
        .firstOrNull;
    if (group == null) return;
    final members = group.blockExercises;
    unawaited(_runNext(() => members == null
        ? _openActiveExercise(context, training, group.leader)
        : _startCircuit(context, training, group.leader, members)));
  }

  /// «Volver a grabar» for the failed upload [feedbackId]; one at a time.
  Future<void> _rerecord(String feedbackId, String exerciseName) async {
    if (_rerecording || !_sameSession) return;
    setState(() => _rerecording = true);
    try {
      await rerecordLastSetVideo(
        context,
        feedbackId: feedbackId,
        exerciseName: exerciseName,
        expectedSession: widget.sessionStamp,
      );
    } finally {
      if (mounted) setState(() => _rerecording = false);
    }
  }

  /// Row line of the last-set video of [exercise] (FB1), null when there is
  /// nothing to show.
  Widget? _videoLine(
    AppLocalizations l10n,
    List<Map<String, dynamic>> feedback,
    TrainingExerciseEntity exercise, {
    required bool isCompleted,
  }) {
    final sessionId = _progressSessionId;
    if (sessionId == null) return null;
    final video = _videoOf(feedback, exercise, sessionId);
    if (!widget.state.training.requiresLastSetVideo &&
        video.state == LastSetVideoState.missing) {
      return null;
    }
    final line = lastSetVideoLine(l10n, video, exerciseCompleted: isCompleted);
    if (line == null) return null;
    return _LastSetVideoLine(
      state: line.$1,
      text: line.$2,
      rerecordKey: Key('rerecord-video-${exercise.id}'),
      rerecordLabel: l10n.lastSetVideoRerecordFor(exercise.exercise.name),
      enabled: !_rerecording && _sameSession,
      onRerecord: video.state == LastSetVideoState.failed
          ? () => _rerecord(video.feedbackId!, exercise.exercise.name)
          : null,
    );
  }

  /// O7: [action] for a pinned footer button, ignoring taps that land while
  /// the route is still entering (plus [_footerEntryTapGuard]). A null action
  /// stays null, so the button looks the same either way.
  VoidCallback? _onceArmed(FutureOr<void> Function()? action) => action == null
      ? null
      : () {
          if (!widget.footerArmed.value) return;
          action();
        };

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

  /// COLA r3/r4: the text of the most relevant video wait among [actions]
  /// (its own video, then behind another exercise of this training, then
  /// behind the day), as «Subidas pendientes» says it; null when none waits.
  static String? _mostRelevantWait(
    AppLocalizations l10n,
    OfflineSyncService sync,
    Iterable<Map<String, dynamic>> actions,
  ) {
    final waits = {for (final action in actions) ?sync.feedbackWaitOf(action)};
    for (final wait in const [
      ProgressFeedbackWait.ownVideo,
      ProgressFeedbackWait.behindVideo,
      ProgressFeedbackWait.behindDayVideo,
    ]) {
      if (waits.contains(wait)) return progressFeedbackWaitLabel(l10n, wait);
    }
    return null;
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
    List<Map<String, dynamic>> feedback,
    int number,
  ) {
    final completedCount = blockExercises
        .where((blockExercise) => _progress.ids.contains(blockExercise.id))
        .length;
    final l10n = AppLocalizations.of(context);
    // FB1: the members whose last-set video failed, each with «Volver a
    // grabar»; the circuit's own line keeps the aggregated sync state.
    final memberVideos = <Widget>[
      if (_progressSessionId != null)
        for (final member in blockExercises)
          if (_videoOf(feedback, member, _progressSessionId)
              case final video when video.state == LastSetVideoState.failed)
            _LastSetVideoLine(
              state: ExomSyncState.fallida,
              text: l10n.lastSetVideoMemberFailed(
                member.exercise.name,
                lastSetVideoReason(l10n, video.row!),
              ),
              rerecordKey: Key('rerecord-video-${member.id}'),
              rerecordLabel: l10n.lastSetVideoRerecordFor(member.exercise.name),
              enabled: !_rerecording && _sameSession,
              onRerecord: () =>
                  _rerecord(video.feedbackId!, member.exercise.name),
            ),
    ];
    return _CircuitCard(
      memberVideos: memberVideos,
      number: number,
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
    List<Map<String, dynamic>> feedback,
    _WeightText weightText,
    int number, {
    String? footerWait,
  }) {
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

    final syncState = _exerciseSync(
      actions, ex, hasLocalDraft: hasPartialProgress);
    // COLA r4: under the row's «Pendiente de sincronizar», why this
    // exercise's queued progress waits for a video; not repeated when the
    // pending completion's footer already says the same.
    final sync = sl.isRegistered<OfflineSyncService>()
        ? sl<OfflineSyncService>() : null;
    final rowWait = sync != null && syncState == ExomSyncState.pendiente
        ? _mostRelevantWait(l10n, sync, actions.where((action) =>
            const {'mark_exercise_completed', 'unmark_exercise_completed'}
                .contains(action['type']) &&
            action['training_exercise_id'] == ex.id &&
            action['date'] == widget.state.selectedDate &&
            action['training_session_id'] == _progressSessionId))
        : null;
    final waitLabel = rowWait == footerWait ? null : rowWait;
    return _ExerciseCard(
      number: number,
      trainingExercise: ex,
      trainingLevel: training.level,
      isCompleted: isCompleted,
      weightUsed: effectiveWeight,
      weightText: weightText,
      currentPerformances: _progress.performances[ex.id],
      previousValue: _previousValue(
        l10n, widget.state.previousPerformances[ex.id], weightText),
      todayLabel: todayLabel,
      hasPartialProgress: hasPartialProgress,
      syncState: syncState,
      waitLabel: waitLabel,
      video: _videoLine(l10n, feedback, ex, isCompleted: isCompleted),
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
    // FB1: last-set videos are read only where the plan asks for them.
    final feedback = training.requiresLastSetVideo
        ? storage.getFeedbackUploadQueue()
        : const <Map<String, dynamic>>[];
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
    // L5-D49 (O3): a reopened detail only knows the execution it displays,
    // so that execution also says whether the session is already finished.
    final writableCompletionId = widget.selectedExecutionId ?? _sessionId ??
        _locallyConfirmedSessionId ?? _displaySessionId;
    final locallyCompleted = writableCompletionId != null &&
        storage.getConfirmedTrainingExecutions(training.id, widget.state.selectedDate)
            .any((entry) => entry['id'] == writableCompletionId &&
                const ['completed', 'confirmed'].contains(entry['status']));
    // L5-D49 (O3): a finished session offers no completion; the footer shows
    // «Terminada» instead. A blocker, a conflict or a pending completion keeps
    // its own treatment. Repeating it starts another execution from the rows.
    final sessionFinished = locallyCompleted && blocker == null &&
        !needsConflictReview && !pendingSync;
    final activeWorkouts = sl<LocalStorage>().watchActiveWorkouts();
    final groups = _exerciseGroups(training);
    final next = _firstUnfinished(groups);

    // Status of the session completion next to its button (plan §6: pending
    // is amber + clock, failure is error colour + icon). A conflict keeps
    // today's treatment: only the button label.
    // FB1: a completion waiting on videos names their exercises.
    String? videoNames(Set<LastSetVideoState> states) {
      final names = [
        for (final exercise in training.exercises)
          if (states.contains(
              _videoOf(feedback, exercise, selectedCompletionId).state))
            exercise.exercise.name,
      ];
      return names.isEmpty ? null : names.join(', ');
    }
    final ExomSyncStatus? completionStatus;
    if (needsConflictReview ||
        blocker?.kind == CompletionSyncBlockerKind.conflict) {
      completionStatus = null;
    } else if (blocker?.kind == CompletionSyncBlockerKind.feedbackWaiting) {
      final waiting = videoNames(
          const {LastSetVideoState.pending, LastSetVideoState.sending});
      completionStatus = ExomSyncStatus(
        state: ExomSyncState.pendiente,
        label: waiting == null ? null : l10n.trainingFeedbackWaitingFor(waiting),
      );
    } else if (blocker?.kind == CompletionSyncBlockerKind.feedbackFailed) {
      final failed = videoNames(const {LastSetVideoState.failed});
      completionStatus = ExomSyncStatus(
        state: ExomSyncState.fallida,
        label: failed == null ? null : l10n.trainingFeedbackFailedFor(failed),
      );
    } else if (blocker != null ||
        hasFailedExecution && !pendingSync && !locallyCompleted) {
      completionStatus = const ExomSyncStatus(state: ExomSyncState.fallida);
    } else if (pendingSync) {
      completionStatus = ExomSyncStatus(
        state: ExomSyncState.pendiente,
        label: l10n.trainingDetailCompletionSavedPending,
      );
    } else if (sessionFinished) {
      completionStatus = ExomSyncStatus(
        state: ExomSyncState.confirmada,
        label: l10n.trainingDetailSessionFinished,
      );
    } else {
      completionStatus = null;
    }
    // COLA r3: under a pending completion, why this training's queued
    // progress waits for a video, as «Subidas pendientes» says it.
    // Read-only; refreshed by the queue's changes.
    final waitLabel =
        sync != null && completionStatus?.state == ExomSyncState.pendiente
            ? _mostRelevantWait(l10n, sync, pendingActions.where((action) =>
                action['training_id'] == training.id &&
                action['date'] == widget.state.selectedDate &&
                action['training_session_id'] == selectedCompletionId))
            : null;

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
        ? l10n.completeTrainingSheetTitle
        : l10n.completeTrainingConfirmAction);
    // One lime action per state: "next" while work remains; once every
    // exercise is done the completion button takes the primary style.
    final completeIsPrimary = next == null;

    // L5-D63: with large text the pinned footer scrolls away while the user
    // scrolls the list down. The body then runs under the footer slot and the
    // list keeps the footer's height as bottom room.
    final scrollAway = exomScrollAwayFooterEnabled(context);
    final listChildren = <Widget>[
          _DetailHeader(
            training: training,
            selectedDate: widget.state.selectedDate,
            completed: completed,
            total: total,
            completedSets: tallyPlannedSets(
              training.exercises,
              plannedSets: _plannedSetsOfExercise,
              isCompleted: (item) => _progress.ids.contains(item.id),
            ).completed,
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
          // Exercise list (sketch «Detalle del entreno»): section header with
          // the done count, then numbered rows with their thumbnail.
          _SectionTitle(
            title: l10n.exercises,
            trailing: l10n.trainingDetailExercisesDone(completed, total),
          ),
          // Rows are numbered by their position in the list (01, 02…), each
          // exercise or circuit once: `order` is the API sort key (0-based,
          // x1000 with circuits), not a label.
          for (final (index, group) in groups.indexed)
            ValueListenableBuilder(
              valueListenable: activeWorkouts,
              builder: (context, box, _) {
                final circuit = group.blockExercises;
                return circuit == null
                    ? _buildExerciseRow(context, training, group.leader,
                        pendingActions, feedback, weightText, index + 1,
                        footerWait: waitLabel)
                    : _buildCircuitRow(
                        context,
                        training,
                        group.leader,
                        circuit,
                        pendingActions,
                        feedback,
                        index + 1,
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
        ];
    final Widget footer =
      // Pinned thumb-zone actions: the next exercise (lime) and the session
      // completion, which becomes the lime action once every exercise is done.
      // FB1 r4 (D3): the bottom inset stays outside the footer's scroll view:
      // when large text makes the footer reach its height cap and scroll, the
      // inset no longer scrolls with it and the button stays above the
      // gesture bar. Same paint as before (the inset takes the footer's fill).
      ColoredBox(
        color: palette.background,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: ExomPinnedFooter(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (completionStatus != null) ...[
                    Align(alignment: Alignment.centerLeft, child: completionStatus),
                    if (waitLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        waitLabel,
                        key: const Key('training-completion-wait'),
                        style: _rowLineStyle(context),
                      ),
                    ],
                    if (!sessionFinished || next != null)
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
                          : _onceArmed(() => _runNext(() =>
                              next.blockExercises == null
                                  ? _openActiveExercise(
                                      context, training, next.leader)
                                  : _startCircuit(context, training,
                                      next.leader, next.blockExercises!))),
                    ),
                    if (!sessionFinished) const SizedBox(height: 8),
                  ],
                  if (!sessionFinished)
                    _CompleteTrainingButton(
                      primary: completeIsPrimary,
                      label: completeLabel,
                      done: allDone,
                      onPressed: _onceArmed(completeOnPressed),
                    ),
                ],
              ),
          ),
        ),
      );

    final scaffold = Scaffold(
      backgroundColor: palette.background,
      extendBody: scrollAway,
      appBar: ExomAppBar(
        leading: _DetailBackButton(onPressed: () => context.pop()),
      ),
      // One tree for both footers: changing it would rebuild the list and
      // send it back to the top when the text scale crosses 1.3 or the
      // screen reader turns on or off.
      body: NotificationListener<ScrollMetricsNotification>(
        onNotification: scrollAway
            ? _footerVisibility.handleMetricsNotification
            : null,
        child: NotificationListener<ScrollNotification>(
          onNotification: scrollAway
              ? _footerVisibility.handleScrollNotification
              : null,
          child: Builder(
            builder: (context) => ListView(
              // The extended body's bottom padding is the footer slot.
              padding: EdgeInsets.only(
                bottom: scrollAway
                    ? 24 + MediaQuery.paddingOf(context).bottom
                    : 24,
              ),
              children: listChildren,
            ),
          ),
        ),
      ),
      bottomNavigationBar: scrollAway
          ? ExomScrollAwayFooter(
              key: const Key('training-detail-scroll-away-footer'),
              controller: _footerVisibility,
              child: footer,
            )
          : footer,
    );
    // Above the Scaffold so its status-bar tap still scrolls the list up.
    return PrimaryScrollController(
      controller: _scrollController,
      child: scaffold,
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

/// «8 × 60 kg» from the first logged set of the previous session; the row
/// paints it inside «Anterior …» (`trainingDetailPrevious`).
String? _previousValue(
  AppLocalizations l10n,
  List<SetPerformance>? previous,
  _WeightText weightText,
) {
  if (previous == null || previous.isEmpty) return null;
  final sorted = [...previous]
    ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
  for (final set in sorted) {
    final value = _setValueLabel(l10n, set, weightText);
    if (value != null) return value;
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

/// Note of the day and the trainer's reply (L5-E2a): the note flat on the page
/// under its label, the reply as the shared [ExomReplyBlock] (T0.3b) signed
/// «Respuesta de tu entrenador» (the model has no trainer name, D15/D16).
class TrainingNoteReplyCard extends StatelessWidget {
  const TrainingNoteReplyCard({super.key, this.note, this.reply,
    this.historicalDayNote = false});

  final String? note;
  final String? reply;
  final bool historicalDayNote;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final noteText = note;
    final replyText = reply;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (noteText != null) ...[
            Text(
              historicalDayNote
                  ? l10n.historicalDayNoteUnattributed
                  : l10n.yourTrainingNote,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                color: palette.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: ExomSpacing.xs),
            Text(
              noteText,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                color: palette.textPrimary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
          if (noteText != null && replyText != null)
            const SizedBox(height: ExomSpacing.lg),
          if (replyText != null)
            ExomReplyBlock(text: replyText, author: l10n.trainerReply),
        ],
      ),
    );
  }
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

/// Planned sets of one exercise of the detail (circuit exercises weigh sets x
/// rounds, the shared rule of Inicio, L4b-D5).
int _plannedSetsOfExercise(TrainingExerciseEntity item) => plannedSetsOf(
  sets: item.sets,
  inBlock: item.blockId != null,
  blockRounds: item.blockRounds,
);

/// Photo of a session: the `thumbnailUrl` of its first exercise, by `order`,
/// that is a usable http(s) URL (same rule as Inicio and Entrenar, L4b-D1).
String? _sessionPhotoUrl(TrainingEntity training) {
  final ordered = training.exercises.indexed.toList()
    ..sort((a, b) {
      final byOrder = a.$2.order.compareTo(b.$2.order);
      return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
    });
  for (final (_, item) in ordered) {
    final url = item.exercise.thumbnailUrl?.trim();
    if (url == null || url.isEmpty) continue;
    final uri = Uri.tryParse(url);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return url;
    }
  }
  return null;
}

/// Top of the detail (sketch «Detalle del entreno», L5-E2a): the session photo
/// bleeding edge to edge, the name in the display face (shared title hero with
/// Entrenar), the day and the muted facts; then, before the first exercise is
/// done, the numbered figures (exercises, planned sets, approximate minutes)
/// and, once one is done, the session progress as a figure in a featured
/// block (frame «a mitad»). Only data the page already has: no week number.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.training,
    required this.selectedDate,
    required this.completed,
    required this.total,
    required this.completedSets,
  });

  final TrainingEntity training;
  final String selectedDate;
  final int completed;
  final int total;
  final int completedSets;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final totalSets = tallyPlannedSets(
      training.exercises,
      plannedSets: _plannedSetsOfExercise,
      isCompleted: (_) => false,
    ).total;
    final duration = training.estimatedDurationMin;
    final kind = [
      ...trainingTypeLabels(context, training.types),
      if (training.level.trim().isNotEmpty)
        _trainingLevelLabel(l10n, training.level),
      // Calories stay as a fact (the old volume line carried them).
      if (training.estimatedCalories != null)
        '${training.estimatedCalories} kcal',
    ].join(' · ');
    final day = DateTime.tryParse(selectedDate);
    final dateLabel = day == null
        ? null
        : toBeginningOfSentenceCase(
            DateFormat.MMMMEEEEd(
              Localizations.localeOf(context).toString(),
            ).format(day),
          );
    final photo = _sessionPhotoUrl(training);
    final mutedStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      color: palette.textSecondary,
      fontSize: 14,
      height: 1.4,
    );
    final figures = [
      if (training.exercises.isNotEmpty) ...[
        ExomFigure(
          value: formatFigure(context, training.exercises.length),
          label: l10n.homeFigureExercises(training.exercises.length),
        ),
        ExomFigure(
          value: formatFigure(context, totalSets),
          label: l10n.homeFigureSets(totalSets),
        ),
      ],
      if (duration != null)
        ExomFigure(
          value: formatFigure(context, duration),
          label: l10n.trainingsFigureMinutesApprox,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photo != null) HomeSessionPhoto(url: photo),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                    child: Text(
                      training.name.toUpperCase(),
                      style: ExomType.screenTitle.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              if (dateLabel != null) ...[
                const SizedBox(height: ExomSpacing.sm),
                Text(dateLabel, style: mutedStyle),
              ],
              if (kind.isNotEmpty) ...[
                const SizedBox(height: ExomSpacing.xs),
                Text(kind, style: mutedStyle),
              ],
              if (training.tags.isNotEmpty)
                Text(
                  training.tags.map((tag) => '#$tag').join(' '),
                  style: mutedStyle.copyWith(fontSize: 13),
                ),
            ],
          ),
        ),
        if (completed > 0)
          _SessionProgress(
            completed: completed,
            total: total,
            completedSets: completedSets,
            totalSets: totalSets,
          )
        else if (figures.isNotEmpty)
          ExomFigureColumns(items: figures),
      ],
    );
  }
}

/// Session progress (sketch `.x-feat` «Progreso de la sesión»): exercises done
/// as the protagonist figure («2/6», data colour) captioned «ejercicios», the
/// planned sets of the done exercises beside it captioned «series hechas» and
/// one segment per exercise.
class _SessionProgress extends StatelessWidget {
  const _SessionProgress({
    required this.completed,
    required this.total,
    required this.completedSets,
    required this.totalSets,
  });

  final int completed;
  final int total;
  final int completedSets;
  final int totalSets;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final captionStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      color: palette.textSecondary,
      fontSize: 14,
      height: 1.35,
    );
    return ExomFeatureBlock(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExomKicker(l10n.trainingDetailProgressKicker),
            const SizedBox(height: ExomSpacing.md),
            // One accessible summary of both counts; the figure alone («1/5»)
            // does not say it counts exercises.
            Semantics(
              container: true,
              label: l10n.trainingDetailProgressSemantics(
                completed,
                total,
                completedSets,
                totalSets,
              ),
              excludeSemantics: true,
              // Each figure carries its caption right below it, in the same
              // style, so «1/5» reads as exercises next to «4 de 16 / series
              // hechas» (same layout as ExomNumeral with a side: wrap, 18 dp
              // apart, bottoms aligned so both captions share a line).
              child: Wrap(
                spacing: 18,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExomNumeral(
                        value: formatFigure(context, completed),
                        unit: '/${formatFigure(context, total)}',
                      ),
                      Text(
                        l10n.homeFigureExercises(total),
                        style: captionStyle,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n
                            .trainingDetailSetsDoneOf(completedSets, totalSets)
                            .toUpperCase(),
                        style: ExomType.section.copyWith(
                          fontSize: 28,
                          height: 0.95,
                          letterSpacing: -0.28,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        l10n.trainingDetailSetsDoneLabel(totalSets),
                        style: captionStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (total > 0) ...[
              const SizedBox(height: ExomSpacing.lg),
              ExomProgressRule(
                value: completed / total,
                segments: total,
                thickness: 10,
              ),
            ],
          ],
        ),
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
            backgroundColor: palette.limeFill,
            foregroundColor: palette.onLimeFill,
            iconColor: palette.onLimeFill,
            disabledBackgroundColor: palette.borderSoft,
            disabledForegroundColor:
                isDark ? palette.textDisabled : palette.textSecondary,
            disabledIconColor:
                isDark ? palette.textDisabled : palette.textSecondary,
            side: palette.limeFillOutline == null || onPressed == null
                ? null
                : BorderSide(
                    color: palette.limeFillOutline!,
                    width: ExomRule.outline,
                  ),
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

/// Section heading (warm-up, exercises, cool-down): display face, uppercase,
/// with an optional muted [trailing] fact at the end of the line that wraps
/// below the title when there is no room (sketch `.x-sh-row`).
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final heading = Semantics(
      header: true,
      label: title,
      excludeSemantics: true,
      child: Text(
        title.toUpperCase(),
        style: ExomType.section.copyWith(color: palette.textPrimary),
      ),
    );
    final fact = trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: fact == null
          ? heading
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ExomSpacing.md,
              runSpacing: ExomSpacing.xs,
              children: [
                heading,
                Text(
                  fact,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    color: palette.textSecondary,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
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

/// Numbered list row of the detail (sketch `.x-row` with `.e-rno`): the index
/// «01» in the data colour, a 56 square [thumb], the [body] and the trailing
/// mark centred on the row. Hairline on top, full-width tap target at least 72
/// high and the raised fill while pressed ([ExomRowSurface], M6). One merged
/// semantics node, a button. The list closes with a [Divider].
class _NumberedRow extends StatelessWidget {
  const _NumberedRow({
    required this.number,
    required this.thumb,
    required this.body,
    required this.trailing,
    required this.onTap,
    this.footer,
  });

  final int number;
  final Widget thumb;
  final Widget body;

  /// Mark at the row's end; null leaves the whole width to [body].
  final Widget? trailing;
  final VoidCallback onTap;

  /// FB1 r3: lines under the header, across the row's full width.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    final footer = this.footer;
    final header = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 30),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ExomIndexNumber(number),
              ),
            ),
          ),
          const SizedBox(width: ExomSpacing.md),
          Align(alignment: AlignmentDirectional.topStart, child: thumb),
          const SizedBox(width: 14),
          Expanded(child: body),
          if (trailing != null) Center(child: trailing),
        ],
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: ExomRowSurface(
          onTap: onTap,
          minHeight: 72,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 12),
          child: footer == null
              ? header
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [header, footer],
                ),
        ),
      ),
    );
  }
}

/// FB1 r3: text at Android's 1.5x setting or above (the 14 sp body size grows
/// by half or more). There, at 320 dp, the circuit row's counter and a
/// SnackBar action no longer fit beside their text, so those layouts stack.
bool _isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) >= 14 * 1.5;

/// FB1 r4 (D2): a SnackBar of the detail page, shown on the app's messenger
/// but closed when the page asks ([dismiss]): when another route covers the
/// detail, when it is popped or when it shows a fresh one. Without that, a
/// persistent SnackBar followed the user to other screens and held every
/// later SnackBar of the app in the messenger's queue.
///
/// The messenger can only close the SnackBar it is showing, so a dismiss
/// asked while this one still waits in the queue takes effect as soon as it
/// becomes visible ([visible], its `onVisible`). It does not depend on the
/// page's State, which may be disposed by then.
class _DetailSnackBar {
  _DetailSnackBar(this._messenger);

  final ScaffoldMessengerState _messenger;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _controller;
  bool _visible = false;
  bool _closed = false;
  bool _dismissed = false;

  void show(SnackBar snackBar) {
    final controller = _controller = _messenger.showSnackBar(snackBar);
    controller.closed.whenComplete(() => _closed = true);
  }

  void visible() {
    _visible = true;
    if (_dismissed) _close();
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    if (_visible) _close();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    // After the frame: dismiss can come from a build or a dispose, where the
    // messenger cannot change its state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messenger.mounted) _controller?.close();
    });
  }
}

/// FB1 r3: a SnackBar action laid under its message (large text): the label
/// wraps, the target stays at least 48 dp and, like [SnackBarAction], it
/// closes the SnackBar and only acts once.
class _StackedSnackBarAction extends StatefulWidget {
  const _StackedSnackBarAction({required this.label, required this.color,
    required this.onPressed});

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_StackedSnackBarAction> createState() => _StackedSnackBarActionState();
}

class _StackedSnackBarActionState extends State<_StackedSnackBarAction> {
  bool _triggered = false;

  void _handlePressed() {
    if (_triggered) return;
    setState(() => _triggered = true);
    widget.onPressed();
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar(reason: SnackBarClosedReason.action);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _triggered ? null : _handlePressed,
      style: TextButton.styleFrom(
        foregroundColor: widget.color,
        minimumSize: const Size(kExomMinTapTarget, kExomMinTapTarget),
        padding: EdgeInsets.zero,
        alignment: AlignmentDirectional.centerStart,
      ),
      child: Text(widget.label),
    );
  }
}

/// 56 square of a row (`.x-thumb`): the exercise thumbnail, or [icon] on the
/// raised fill when there is none. Decorative.
class _RowThumb extends StatelessWidget {
  const _RowThumb({super.key, required this.url, required this.icon});

  final String? url;
  final IconData icon;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final imageUrl = url?.trim();
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: imageUrl == null || imageUrl.isEmpty
            ? ColoredBox(
                color: palette.surfaceElevated,
                child: Icon(icon, size: 24, color: palette.textSecondary),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: PerformanceProfile.imageCacheWidth(
                  context,
                  size,
                ),
                placeholder: (context, imageUrl) => _ThumbnailBackground(),
                errorWidget: (context, imageUrl, error) =>
                    _ThumbnailBackground(),
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

/// Trailing mark of a row: when done, a check in the data colour («hecha» is
/// the client's data, D19; the sync status says whether it is confirmed);
/// otherwise a chevron.
class _RowTrailing extends StatelessWidget {
  const _RowTrailing({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Icon(
        done ? ExomIcons.check : ExomIcons.next,
        color: done ? palette.data : palette.textSecondary,
        size: done ? 24 : 22,
      ),
    );
  }
}

class _CircuitCard extends StatelessWidget {
  final int number;
  final String name;
  final int rounds;
  final int restBetweenRoundsSeconds;
  final int exerciseCount;
  final int completedCount;
  final ExomSyncState? syncState;
  final VoidCallback onFeedback;
  final VoidCallback onStart;
  final VoidCallback? onMarkPending;

  /// FB1: one line per member whose last-set video failed.
  final List<Widget> memberVideos;

  const _CircuitCard({
    this.memberVideos = const [],
    required this.number,
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
    // FB1 r3 (FB1-R2-O1): with large text the counter and its mark leave the
    // header's end, so the body takes all the width left by the numeral and
    // the thumbnail, and the members' video lines go under the header at
    // full width.
    final largeText = _isLargeText(context);
    final progress = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!largeText) const SizedBox(width: 8),
        Text(
          '$completedCount/$exerciseCount',
          style: _rowLineStyle(context, color: palette.textPrimary),
        ),
        _RowTrailing(done: isCompleted),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumberedRow(
          number: number,
          onTap: onStart,
          thumb: const _RowThumb(url: null, icon: ExomIcons.repeat),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              if (largeText) progress else ...memberVideos,
            ],
          ),
          trailing: largeText ? null : progress,
          footer: largeText && memberVideos.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: memberVideos,
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(62, 0, 12, 8),
          child: Row(
            children: [
              // The button takes the width the mark leaves (a Flexible next
              // to a Spacer split it in halves and wrapped the label).
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('circuit-feedback-button'),
                    onPressed: onFeedback,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      minimumSize:
                          const Size(kExomMinTapTarget, kExomMinTapTarget),
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
              ),
              if (onMarkPending != null) ...[
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
  /// Position of the row in the list (1-based), shown as «01», «02»…
  final int number;
  final TrainingExerciseEntity trainingExercise;
  final String trainingLevel;
  final bool isCompleted;
  final double? weightUsed;
  final _WeightText weightText;
  final List<SetPerformance>? currentPerformances;
  final String? previousValue;
  final String? todayLabel;
  final bool hasPartialProgress;
  final ExomSyncState? syncState;

  /// COLA r4: why the row's pending progress waits for a video.
  final String? waitLabel;

  /// FB1: state of the last-set video, with «Volver a grabar» when it failed.
  final Widget? video;
  final VoidCallback onOpenActive;
  final void Function(bool completed, {double? weightUsed}) onToggle;

  const _ExerciseCard({
    required this.number,
    required this.trainingExercise,
    required this.trainingLevel,
    required this.isCompleted,
    required this.weightText,
    required this.onOpenActive,
    required this.onToggle,
    this.weightUsed,
    this.currentPerformances,
    this.previousValue,
    this.todayLabel,
    this.hasPartialProgress = false,
    this.syncState,
    this.waitLabel,
    this.video,
  });

  /// «Anterior 8 × 60 kg» with the value in the text colour, 600 (sketch
  /// `.e-b`); the whole line is one text for assistive technology.
  Widget _previousLine(BuildContext context, String value) {
    final palette = context.exomPalette;
    final line = AppLocalizations.of(context).trainingDetailPrevious(value);
    final at = line.indexOf(value);
    final style = _rowLineStyle(context);
    if (at < 0) return Text(line, style: style);
    return Text.rich(
      TextSpan(
        children: [
          if (at > 0) TextSpan(text: line.substring(0, at)),
          TextSpan(
            text: value,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (at + value.length < line.length)
            TextSpan(text: line.substring(at + value.length)),
        ],
      ),
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = trainingExercise.exercise;
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final previous = previousValue;

    return _NumberedRow(
      number: number,
      onTap: () => _showExerciseDetail(context),
      thumb: _RowThumb(
        key: Key('training-exercise-thumb-${trainingExercise.id}'),
        url: ex.thumbnailUrl,
        icon: ExomIcons.train,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
          if (previous != null) _previousLine(context, previous),
          if (todayLabel != null)
            Text(
              todayLabel!,
              style: _rowLineStyle(context, color: palette.textPrimary),
            ),
          if (syncState != null) ...[
            const SizedBox(height: 4),
            ExomSyncStatus(state: syncState!),
          ],
          if (waitLabel case final wait?)
            Text(
              wait,
              key: Key('training-exercise-wait-${trainingExercise.id}'),
              style: _rowLineStyle(context),
            ),
          ?video,
        ],
      ),
      trailing: _RowTrailing(done: isCompleted),
    );
  }

  void _showExerciseDetail(BuildContext context) async {
    final ex = trainingExercise.exercise;
    // No explicit background: the sheet takes `bottomSheetTheme` (palette
    // surface) from the live theme, so a theme change while it is open
    // repaints it instead of keeping the colour captured when it was opened.
    final result = await showPageAwareModalBottomSheet<_SheetCompletionResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExerciseSheetHost(
        sheetBuilder: (scrollController, onFootHeight, onLeadBottom) =>
            _ExerciseDetailSheet(
          exercise: ex,
          trainingExercise: trainingExercise,
          scrollController: scrollController,
          onFootHeight: onFootHeight,
          onLeadBottom: onLeadBottom,
          isCompleted: isCompleted,
          weightUsed: weightUsed,
          weightText: weightText,
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

/// FB1: state of one last-set video on a row (pending, sending, sent, failed
/// with its reason) and, for a failed one, «Volver a grabar» as a discreet
/// text action (≥48 dp, never lime: the row's next step stays the pinned
/// action).
class _LastSetVideoLine extends StatelessWidget {
  const _LastSetVideoLine({
    required this.state,
    required this.text,
    required this.rerecordKey,
    required this.rerecordLabel,
    required this.enabled,
    this.onRerecord,
  });

  final ExomSyncState state;
  final String text;
  final Key rerecordKey;

  /// Spoken label of the action, naming the exercise.
  final String rerecordLabel;
  final bool enabled;
  final VoidCallback? onRerecord;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final rerecord = onRerecord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        ExomSyncStatus(state: state, label: text),
        if (rerecord != null)
          TextButton.icon(
            key: rerecordKey,
            onPressed: enabled ? rerecord : null,
            style: TextButton.styleFrom(
              foregroundColor: palette.textPrimary,
              minimumSize: const Size(kExomMinTapTarget, kExomMinTapTarget),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: const TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(ExomIcons.video, size: 20),
            label: Text(
              l10n.lastSetVideoRerecord,
              semanticsLabel: rerecordLabel,
            ),
          ),
      ],
    );
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

/// Draggable container of the exercise sheet. Its smallest size is never below
/// what the pinned foot needs (measured, so it follows the text scale) plus a
/// minimum of body, so the foot actions are always fully visible (HOJA-PULIDO
/// H2); the usual 40 % applies when the foot is small. With large text it
/// opens tall enough to show the name and the level above the foot (L5-D63).
class _ExerciseSheetHost extends StatefulWidget {
  const _ExerciseSheetHost({required this.sheetBuilder});

  final Widget Function(
    ScrollController scrollController,
    ValueChanged<double> onFootHeight,
    ValueChanged<double> onLeadBottom,
  )
  sheetBuilder;

  @override
  State<_ExerciseSheetHost> createState() => _ExerciseSheetHostState();
}

class _ExerciseSheetHostState extends State<_ExerciseSheetHost> {
  static const double _baseMinFraction = 0.4;
  static const double _initialFraction = 0.7;
  static const double _maxFraction = 0.95;

  double _footHeight = 0;

  /// Bottom of the name and level block in the body content (L5-D63).
  double _leadBottom = 0;

  void _onFootHeight(double height) {
    if ((height - _footHeight).abs() < 0.5 || !mounted) return;
    setState(() => _footHeight = height);
  }

  void _onLeadBottom(double bottom) {
    if ((bottom - _leadBottom).abs() < 0.5 || !mounted) return;
    setState(() => _leadBottom = bottom);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        final needed = available > 0
            ? (_footHeight + _ExerciseDetailSheet.minBodyHeight) / available
            : 0.0;
        final minSize = math.min(
          math.max(_baseMinFraction, needed),
          _maxFraction - 0.05,
        );
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: exomSheetInitialSize(
            context,
            initialSize: math.max(_initialFraction, minSize),
            maxSize: _maxFraction,
            available: available,
            leadBottom: _leadBottom,
            footHeight: _footHeight,
          ),
          minChildSize: minSize,
          maxChildSize: _maxFraction,
          builder: (_, scrollController) => widget.sheetBuilder(
            scrollController,
            _onFootHeight,
            _onLeadBottom,
          ),
        );
      },
    );
  }
}

/// Exercise sheet (L5-D47, sketch `g-hoja-ejercicio.html` variant «A · media
/// arriba»): the thumbnail or video at full bleed (not painted without
/// either), the name in the display face, the prescription, level and muscles
/// as facts, today's block with the data bar, the numbered texts and a pinned
/// foot with «Enviar feedback» and the exercise action. The header only has
/// the handle and close.
///
/// No background of its own: the bottom sheet takes `bottomSheetTheme` from
/// the live theme (E2a), and the foot is transparent over it.
class _ExerciseDetailSheet extends StatelessWidget {
  final ExerciseEntity exercise;
  final TrainingExerciseEntity trainingExercise;
  final ScrollController scrollController;
  final ValueChanged<double> onFootHeight;

  /// Where the level fact ends in the body content (L5-D63).
  final ValueChanged<double> onLeadBottom;
  final bool isCompleted;
  final double? weightUsed;
  final _WeightText weightText;
  final String trainingLevel;
  final bool hasPartialProgress;
  final List<SetPerformance>? currentPerformances;

  const _ExerciseDetailSheet({
    required this.exercise,
    required this.trainingExercise,
    required this.scrollController,
    required this.onFootHeight,
    required this.onLeadBottom,
    required this.isCompleted,
    required this.weightText,
    required this.trainingLevel,
    this.weightUsed,
    this.hasPartialProgress = false,
    this.currentPerformances,
  });

  /// Body kept above the pinned foot (handle, close and the name), also what
  /// the sheet's smallest size reserves besides the foot.
  static const double minBodyHeight = 160;

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

  void _openActiveExercise(BuildContext context) {
    Navigator.of(
      context,
    ).pop(const _SheetCompletionResult(openActiveExercise: true));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final thumbnailUrl = exercise.thumbnailUrl?.trim();
    final videoUrl = exercise.videoUrl?.trim();
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final muscleGroups = exercise.muscleGroups
        .map((group) => group.trim())
        .where((group) => group.isNotEmpty)
        .toList();
    final weight = weightUsed;
    final currentPerformanceLabels =
        (currentPerformances ?? const <SetPerformance>[])
            .map((set) => _todaySetLabel(l10n, set, weightText))
            .where((label) => label.isNotEmpty)
            .toList(growable: false);
    final sections = [
      if (_hasContent(exercise.techniqueText))
        (l10n.technique, exercise.techniqueText!),
      if (_hasContent(exercise.commonErrorsText))
        (l10n.commonMistakes, exercise.commonErrorsText!),
      if (_hasContent(exercise.explanationText))
        (l10n.explanation, exercise.explanationText!),
    ];

    final body = ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        // One list child, so the lazy list always lays it out and the level
        // can be measured however tall it gets (L5-D63). Stretched, each part
        // gets the full width, as when they were separate children.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ExerciseSheetHeader(onClose: () => Navigator.of(context).pop()),
            if (hasThumbnail || hasVideo)
              _ExerciseSheetMedia(
                key: const Key('exercise-sheet-media'),
                thumbnailUrl: hasThumbnail ? thumbnailUrl : null,
                semanticLabel: l10n.exerciseSheetWatchVideo(exercise.name),
                onPlay: hasVideo ? () => _openVideo(context) : null,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name.toUpperCase(),
                    semanticsLabel: exercise.name,
                    style: ExomType.headline2Section.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _buildMetadata(l10n),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      color: palette.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ExomScrollContentBottomReporter(
                    onBottom: onLeadBottom,
                    child: _ExerciseSheetFact(
                      icon: ExomIcons.streak,
                      text: _trainingLevelLabel(l10n, trainingLevel),
                    ),
                  ),
                  if (muscleGroups.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _ExerciseSheetFact(
                      icon: ExomIcons.target,
                      text: muscleGroups.join(', '),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (weight != null || currentPerformanceLabels.isNotEmpty) ...[
          const SizedBox(height: 24),
          _ExerciseSheetToday(
            weight: weight,
            weightText: weightText,
            setLabels: currentPerformanceLabels,
          ),
        ],
        for (final (index, (title, text)) in sections.indexed) ...[
          const SizedBox(height: 24),
          ExomNumberedSectionHeader(n: index + 1, title: title),
          _ExerciseSheetText(text: text, bulletItems: extractExerciseBulletItems(text)),
        ],
      ],
    );

    final foot = _ExerciseSheetFoot(
      scrollController: scrollController,
      onHeight: onFootHeight,
      onFeedback: () => _openFeedback(context),
      children: isCompleted
          ? [
              ExomSecondaryButton(
                icon: ExomIcons.editNote,
                label: l10n.editData,
                onPressed: () => _openActiveExercise(context),
              ),
              const SizedBox(height: 4),
              ExomQuietButton(
                label: l10n.markExercisePendingButton,
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop(const _SheetCompletionResult(markPending: true));
                },
              ),
            ]
          : [
              ExomPrimaryButton(
                label: hasPartialProgress
                    ? l10n.resumeExerciseButton
                    : l10n.startExerciseButton,
                semanticLabel: hasPartialProgress
                    ? l10n.resumeExerciseButton
                    : l10n.startExerciseButton,
                trailingIcon: ExomIcons.play,
                onPressed: () => _openActiveExercise(context),
              ),
            ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Expanded(child: body),
          ConstrainedBox(
            // The foot never scrolls while the sheet has room for it plus the
            // minimum body; only on a screen too small for both it does.
            constraints: BoxConstraints(
              maxHeight: math.max(
                constraints.maxHeight * 0.5,
                constraints.maxHeight - minBodyHeight,
              ),
            ),
            child: foot,
          ),
        ],
      ),
    );
  }
}

/// Handle and close (`.grab`, `.g-shdr`): the header has no other action.
class _ExerciseSheetHeader extends StatelessWidget {
  const _ExerciseSheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 2),
          decoration: BoxDecoration(
            color: palette.borderSoft,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 10, 6),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              onPressed: onClose,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              color: palette.textPrimary,
              iconSize: 24,
              style: IconButton.styleFrom(
                minimumSize: const Size(kExomMinTapTarget, kExomMinTapTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ExomRadius.control),
                ),
              ),
              icon: const Icon(ExomIcons.close),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-bleed media (`.x-photo.g-media-a`, 200 high): the thumbnail, or the
/// neutral fill when only the video exists, with the play square when there
/// is a video; the whole block opens the player.
class _ExerciseSheetMedia extends StatelessWidget {
  const _ExerciseSheetMedia({
    super.key,
    required this.thumbnailUrl,
    required this.semanticLabel,
    required this.onPlay,
  });

  final String? thumbnailUrl;
  final String semanticLabel;
  final VoidCallback? onPlay;

  static const double _height = 200;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final url = thumbnailUrl;
    final play = onPlay;
    final fill = ColoredBox(color: palette.surfaceVariant);
    final image = url == null
        ? fill
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: PerformanceProfile.imageCacheWidth(
              context,
              MediaQuery.sizeOf(context).width,
            ),
            placeholder: (context, imageUrl) => fill,
            errorWidget: (context, imageUrl, error) => ColoredBox(
              color: palette.surfaceVariant,
              child: Center(
                child: Icon(
                  ExomIcons.train,
                  color: palette.textDisabled,
                  size: 44,
                ),
              ),
            ),
          );
    final stack = SizedBox(
      height: _height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (play != null)
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(ExomRadius.control),
                  border: Border.all(color: palette.borderSoft),
                ),
                child: Icon(
                  ExomIcons.play,
                  color: palette.textPrimary,
                  size: 28,
                ),
              ),
            ),
        ],
      ),
    );
    if (play == null) return ExcludeSemantics(child: stack);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: play, child: stack),
      ),
    );
  }
}

/// Level or muscles (`.g-meta li`): a fact with its icon, not a chip.
class _ExerciseSheetFact extends StatelessWidget {
  const _ExerciseSheetFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: palette.textPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Today's block (`.x-feat.g-today`): the weight used as a display figure and
/// the sets registered today, numbered.
class _ExerciseSheetToday extends StatelessWidget {
  const _ExerciseSheetToday({
    required this.weight,
    required this.weightText,
    required this.setLabels,
  });

  final double? weight;
  final _WeightText weightText;
  final List<String> setLabels;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final kg = weight;
    final rule = BorderSide(color: palette.borderSoft, width: ExomRule.hairline);
    return ExomFeatureBlock(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kg != null)
              Semantics(
                label: l10n.exerciseSheetWeightUsed(weightText(kg)),
                excludeSemantics: true,
                child: Row(
                  children: [
                    Icon(ExomIcons.train, size: 20, color: palette.textPrimary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              formatWeightDisplay(
                                kg,
                                weightText.unitSystem,
                                decimalSeparator: weightText.decimalSeparator,
                              ),
                              style: ExomType.headline2Section.copyWith(
                                fontSize: 40,
                                height: 0.9,
                                letterSpacing: -0.8,
                                color: palette.data,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            weightUnitSymbol(weightText.unitSystem),
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFontFamily,
                              color: palette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (kg != null && setLabels.isNotEmpty) const SizedBox(height: 12),
            if (setLabels.isNotEmpty) ...[
              ExomKicker(l10n.registeredSetsToday),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: rule)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, label) in setLabels.indexed)
                      DecoratedBox(
                        decoration: BoxDecoration(border: Border(bottom: rule)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                ),
                                child: ExomIndexNumber(index + 1),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontFamily: AppTheme.bodyFontFamily,
                                    color: palette.textPrimary,
                                    fontSize: 14,
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
            ],
          ],
        ),
      ),
    );
  }
}

/// Body of a numbered section (`.g-sec`): dash bullets (`.g-bul`) when the
/// text is a list, otherwise a paragraph (`.g-par`).
class _ExerciseSheetText extends StatelessWidget {
  const _ExerciseSheetText({required this.text, required this.bulletItems});

  final String text;
  final List<String> bulletItems;

  static const double _fontSize = 14;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    TextStyle style(double height) => TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      color: palette.textSecondary,
      fontSize: _fontSize,
      height: height,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: bulletItems.isEmpty
          ? Text(text.trim(), style: style(1.6))
          : ExerciseBulletList(items: bulletItems, fontSize: _fontSize),
    );
  }
}

/// Pinned foot of the sheet (`.sheet-act`): the «Enviar feedback» row (L5-D47
/// alternative F) above the exercise action. Transparent over the live sheet
/// background; past its height limit it scrolls on its own.
class _ExerciseSheetFoot extends StatefulWidget {
  const _ExerciseSheetFoot({
    required this.scrollController,
    required this.onHeight,
    required this.onFeedback,
    required this.children,
  });

  /// The body's controller: a vertical drag on the foot is replayed on it, so
  /// the sheet moves exactly as when dragging the body (HOJA-PULIDO H1).
  final ScrollController scrollController;

  /// Natural height of the foot (what it needs to show all its actions).
  final ValueChanged<double> onHeight;
  final VoidCallback onFeedback;
  final List<Widget> children;

  @override
  State<_ExerciseSheetFoot> createState() => _ExerciseSheetFootState();
}

class _ExerciseSheetFootState extends State<_ExerciseSheetFoot> {
  final GlobalKey _contentKey = GlobalKey();
  Drag? _drag;

  static const double _padTop = 10;
  static const double _padBottom = 12;
  static const double _borderTop = 1;

  /// What the foot adds around its content: padding and top border.
  static const double _chrome = _padTop + _padBottom + _borderTop;

  void _reportHeight() {
    final box = _contentKey.currentContext?.findRenderObject();
    if (!mounted || box is! RenderBox || !box.hasSize) return;
    widget.onHeight(
      box.size.height + _chrome + MediaQuery.paddingOf(context).bottom,
    );
  }

  void _dragStart(DragStartDetails details) {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    _drag = controller.position.drag(details, () => _drag = null);
  }

  @override
  void dispose() {
    _drag?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
    return GestureDetector(
      onVerticalDragStart: _dragStart,
      onVerticalDragUpdate: (details) => _drag?.update(details),
      onVerticalDragEnd: (details) {
        _drag?.end(details);
        _drag = null;
      },
      onVerticalDragCancel: () {
        _drag?.cancel();
        _drag = null;
      },
      child: _buildFoot(context),
    );
  }

  Widget _buildFoot(BuildContext context) {
    final onFeedback = widget.onFeedback;
    final children = widget.children;
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      key: const Key('exercise-sheet-footer'),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.borderSoft, width: _borderTop),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          // Not the sheet's scrollable: the body list owns the drag.
          primary: false,
          padding: const EdgeInsets.fromLTRB(20, _padTop, 20, _padBottom),
          child: Column(
            key: _contentKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MergeSemantics(
                child: Semantics(
                  button: true,
                  child: InkWell(
                    key: const Key('exercise-sheet-feedback'),
                    onTap: onFeedback,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: palette.borderSoft),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            ExomIcons.feedback,
                            size: 22,
                            color: palette.textPrimary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.feedbackSendFromExercise,
                                  style: TextStyle(
                                    fontFamily: AppTheme.bodyFontFamily,
                                    color: palette.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                                Text(
                                  l10n.exerciseSheetFeedbackHint,
                                  style: TextStyle(
                                    fontFamily: AppTheme.bodyFontFamily,
                                    color: palette.textSecondary,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            ExomIcons.next,
                            size: 22,
                            color: palette.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
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
