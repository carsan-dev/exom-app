import 'dart:async';

import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_grow_bar.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/features/feedback/presentation/feedback_notice_snack_bars.dart';
import 'package:exom_app/features/feedback/presentation/inline_upload_status_scope.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rerecord_last_set_video.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PendingUploadsPage extends StatefulWidget {
  const PendingUploadsPage({super.key, this.exerciseNames = const {}});

  final Map<String, String> exerciseNames;

  @override
  State<PendingUploadsPage> createState() => _PendingUploadsPageState();
}

/// Result of the last retry or delete, shown in line under the headline
/// (L5 D14-3: it replaces the SnackBar).
enum _Outcome {
  retryFailed,
  retryRequested,
  retryNotStarted,
  deleted,
  deleteIncomplete,
  syncDeleted,
}

class _PendingUploadsPageState extends State<PendingUploadsPage> {
  FeedbackUploadQueueService get _queue => sl<FeedbackUploadQueueService>();
  OfflineSyncService get _offlineSync => sl<OfflineSyncService>();
  StreamSubscription<FeedbackUploadNotice>? _uploadSubscription;
  StreamSubscription<void>? _syncSubscription;
  late final String? _sessionStamp;
  _Outcome? _outcome;

  /// Row the result is about and its status when it was recorded: a result
  /// that describes the row's state stops showing once the row moves on.
  String? _outcomeId;
  String? _outcomeStatus;

  String? _statusOfId(String id) {
    for (final item in [
      ..._queue.pendingItems,
      ..._offlineSync.pendingActions,
    ]) {
      if (item['id'] == id) return item['status'] as String?;
    }
    return null;
  }

  void _record(_Outcome outcome, String id) {
    _outcome = outcome;
    _outcomeId = id;
    _outcomeStatus = _statusOfId(id);
  }

  void _clearOutcome() {
    _outcome = null;
    _outcomeId = null;
    _outcomeStatus = null;
  }

  /// A deletion result stays until the next action; the others only while the
  /// row still has the status they were recorded with.
  _Outcome? get _visibleOutcome {
    final outcome = _outcome;
    if (outcome == null || !_sameSession) return null;
    if (outcome == _Outcome.deleted || outcome == _Outcome.syncDeleted) {
      return outcome;
    }
    return _statusOfId(_outcomeId ?? '') == _outcomeStatus ? outcome : null;
  }

  bool get _sameSession =>
      mounted &&
      _sessionStamp != null &&
      sl<LocalStorage>().sessionStamp == _sessionStamp;

  @override
  void initState() {
    super.initState();
    InlineUploadStatusScope.register(_isCurrentRoute);
    // A feedback notice opened (or queued) before entering would cover the
    // page; close them once, after the first frame (never during build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FeedbackNoticeSnackBars.closeAll();
    });
    _sessionStamp = sl<LocalStorage>().sessionStamp;
    _uploadSubscription = _queue.notices.listen((_) {
      if (_sameSession) setState(() {});
    });
    _syncSubscription = _offlineSync.changes.listen((_) {
      if (_sameSession) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  ModalRoute<Object?>? _route;

  int _sheetsOpen = 0;

  /// The page counts as the visible one also while a sheet opened from it is
  /// on top (the sheet's route is then the current one).
  bool _isCurrentRoute() =>
      mounted && (_sheetsOpen > 0 || (_route?.isCurrent ?? false));

  @override
  void dispose() {
    InlineUploadStatusScope.unregister(_isCurrentRoute);
    _uploadSubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _retry(String id) async {
    if (!_sameSession) return;
    setState(_clearOutcome);
    final before = _statusOfId(id);
    var failed = false;
    try {
      await _queue.retry(id);
    } catch (_) {
      failed = true;
    }
    if (_sameSession) {
      setState(() => _record(_retryResult(id, before, failed), id));
    }
  }

  /// A retry that throws is an error; one that leaves a failed row failed did
  /// not start; anything else is only «requested» (the queue works on it).
  _Outcome _retryResult(String id, String? before, bool threw) {
    if (threw) return _Outcome.retryFailed;
    return before == 'failed' && _statusOfId(id) == 'failed'
        ? _Outcome.retryNotStarted
        : _Outcome.retryRequested;
  }

  /// Destructive confirmation as an EXOM sheet (L5 D17-1, sketch C2 «(b)»):
  /// «Eliminar» is secondary, never lime. The sheet closes without running its
  /// action when the router location changes (CC 11).
  Future<bool> _confirmDelete(String title, String message) async {
    final l10n = AppLocalizations.of(context);
    _sheetsOpen++;
    final bool? confirmed;
    try {
      confirmed = await showExomSheet<bool>(
        context: context,
        title: title,
        body: message,
        actions: [
          Builder(
            builder: (sheetContext) => ExomSecondaryButton(
              key: const Key('pending-delete-confirm'),
              label: l10n.pendingUploadDelete,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
          Builder(
            builder: (sheetContext) => ExomQuietButton(
              label: l10n.cancel,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ),
        ],
      );
    } finally {
      _sheetsOpen--;
    }
    return confirmed == true;
  }

  Future<void> _discard(String id) async {
    setState(_clearOutcome);
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmDelete(
      l10n.pendingUploadDeleteTitle,
      l10n.pendingUploadDeleteMessage,
    );
    if (!confirmed || !_sameSession) return;
    await _queue.discard(id);
    if (mounted) {
      setState(
        () => _record(
          _statusOfId(id) == null
              ? _Outcome.deleted
              : _Outcome.deleteIncomplete,
          id,
        ),
      );
    }
  }

  bool _rerecording = false;

  /// «Volver a grabar» (FB1): replaces the failed last-set video [id]; the
  /// row then shows the new upload.
  Future<void> _rerecord(String id, String exerciseName) async {
    if (_rerecording || !_sameSession) return;
    setState(() {
      _clearOutcome();
      _rerecording = true;
    });
    _sheetsOpen++;
    try {
      await rerecordLastSetVideo(
        context,
        feedbackId: id,
        exerciseName: exerciseName,
        expectedSession: _sessionStamp,
      );
    } finally {
      _sheetsOpen--;
      if (mounted) setState(() => _rerecording = false);
    }
  }

  /// Queued progress that waits for the upload [id]: an exercise completion
  /// sent with it or a training completion depending on it, also when the
  /// action still names a video [id] replaced (a restored circuit snapshot,
  /// or a crash before the redirect), see [actionWaitsForFeedback].
  bool _hasDependants(String id) {
    final actions = _offlineSync.pendingActions;
    if (actions.isEmpty) return false;
    final uploads = sl<LocalStorage>().getFeedbackUploadQueue();
    return actions.any(
      (action) => actionWaitsForFeedback(action, id, uploads),
    );
  }

  /// Display name of the exercise of [item] (FB1): the names the caller
  /// passed, the one saved with the upload, the cached training of its day
  /// (rows saved by earlier builds) or null.
  String? _exerciseName(Map<String, dynamic> item) {
    final trainingExercise = item['training_exercise_id'];
    final passed = widget.exerciseNames[trainingExercise];
    if (passed != null) return passed;
    final saved = item['exercise_name'];
    if (saved is String && saved.isNotEmpty) return saved;
    final trainingId = item['training_id'];
    final date = item['assignment_date'];
    if (trainingExercise is! String || trainingId is! String || date is! String) {
      return null;
    }
    final exercises = sl<LocalStorage>().getCachedMap(
      'training_detail_${trainingId}_$date',
    )?['exercises'];
    if (exercises is! List) return null;
    for (final entry in exercises.whereType<Map>()) {
      final exercise = entry['exercise'];
      if (entry['id'] == trainingExercise && exercise is Map) {
        final name = exercise['name'];
        if (name is String && name.isNotEmpty) return name;
      }
    }
    return null;
  }

  Future<void> _retrySync(String id) async {
    if (!_sameSession) return;
    setState(_clearOutcome);
    final before = _statusOfId(id);
    await _offlineSync.retryAction(id);
    if (mounted) setState(() => _record(_retryResult(id, before, false), id));
  }

  Future<void> _discardSync(String id) async {
    setState(_clearOutcome);
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmDelete(
      l10n.pendingSyncDeleteTitle,
      l10n.pendingSyncDeleteMessage,
    );
    if (!confirmed || !_sameSession) return;
    await _offlineSync.discardAction(id);
    if (mounted) {
      setState(
        () => _record(
          _statusOfId(id) == null
              ? _Outcome.syncDeleted
              : _Outcome.deleteIncomplete,
          id,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _sameSession ? _queue.pendingItems : <Map<String, dynamic>>[];
    final syncFailures = _sameSession
        ? _offlineSync.pendingActions
        : <Map<String, dynamic>>[];
    final empty = items.isEmpty && syncFailures.isEmpty;
    // L5-D66: «completed» (confirmed) rows leave the pending group and the
    // header counts. Every other row is pending (queued, sending, preparing,
    // or bytes sent and awaiting processing) or failed (`failed` or
    // `discarding`, both drawn as an error), so none is counted twice.
    final sentItems = items.where((i) => i['status'] == 'completed').toList();
    final openItems = items.where((i) => i['status'] != 'completed').toList();
    final failedCount = openItems.where(_isFailed).length;
    final pendingCount = openItems.length - failedCount;
    final subtitle = empty || pendingCount + failedCount == 0
        ? l10n.pendingUploadsNone
        : [
            if (pendingCount > 0) l10n.pendingUploadsCountSubtitle(pendingCount),
            if (failedCount > 0) l10n.pendingUploadsErrorCount(failedCount),
          ].join(' · ');
    final outcome = _visibleOutcome;
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Sketch C2: the bar only carries «Volver»; the title is the body
        // headline.
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: ExomSpacing.xxl),
                children: [
                  _ScreenTitle(
                    title: l10n.pendingUploadsTitle,
                    subtitle: subtitle,
                  ),
                  if (empty)
                    ExomEmptyState(
                      first: l10n.pendingUploadsEmptyFirst,
                      second: l10n.pendingUploadsEmptySecond,
                      lead: l10n.pendingUploadsEmpty,
                      body: l10n.pendingUploadsEmptyBody,
                    )
                  else ...[
                    // L5-D66: the numeral counts everything not yet sent (pending +
                    // failed), as Ajustes does; the failed line stays under it.
                    _Summary(count: openItems.length, failed: failedCount),
                    if (openItems.isNotEmpty) ...[
                      _SectionHeader(
                        n: 1,
                        title: l10n.pendingUploadsSectionEvidence,
                      ),
                      for (final item in openItems) _evidenceRow(l10n, item),
                    ],
                    if (sentItems.isNotEmpty) ...[
                      _SectionHeader(
                        n: openItems.isEmpty ? 1 : 2,
                        title: l10n.pendingUploadsSectionSent,
                      ),
                      for (final item in sentItems) _evidenceRow(l10n, item),
                    ],
                    if (syncFailures.isNotEmpty) ...[
                      _SectionHeader(
                        n: (openItems.isEmpty ? 0 : 1) +
                            (sentItems.isEmpty ? 0 : 1) +
                            1,
                        title: l10n.pendingSyncFailuresTitle,
                      ),
                      for (final item in syncFailures) _syncRow(l10n, item),
                    ],
                  ],
                ],
              ),
            ),
            // The result of the last retry or delete stays in view whatever
            // the scroll position (live region, D14-3).
            if (outcome != null)
              _OutcomeStrip(child: _outcomeMessage(l10n, outcome)),
          ],
        ),
      ),
    );
  }

  static bool _isFailed(Map<String, dynamic> item) =>
      item['status'] == 'failed' || item['status'] == 'discarding';

  Widget _outcomeMessage(AppLocalizations l10n, _Outcome outcome) {
    final (ExomMessageKind kind, String text) = switch (outcome) {
      _Outcome.retryFailed => (ExomMessageKind.error, l10n.pendingRetryFailed),
      _Outcome.retryRequested => (
        ExomMessageKind.info,
        l10n.pendingRetryRequested,
      ),
      _Outcome.retryNotStarted => (
        ExomMessageKind.info,
        l10n.pendingRetryNotStarted,
      ),
      _Outcome.deleteIncomplete => (
        ExomMessageKind.info,
        l10n.pendingDeleteIncomplete,
      ),
      _Outcome.deleted => (ExomMessageKind.ok, l10n.pendingDeleteDone),
      _Outcome.syncDeleted => (ExomMessageKind.ok, l10n.pendingSyncDeleteDone),
    };
    return ExomInlineMessage(kind: kind, title: text);
  }

  Widget _evidenceRow(AppLocalizations l10n, Map<String, dynamic> item) {
    final id = item['id'] as String;
    final status = item['status'] as String? ?? 'queued';
    final isVideo = item['media_type'] == 'VIDEO';
    final name = _exerciseName(item);
    final description = [
      // An exercise is never shown by its identifier (FB1, TEXTOS-2 O2): a
      // plain exercise feedback saved without a name reads as a generic label.
      if (item['training_exercise_id'] != null || item['exercise_id'] != null)
        if (name != null)
          l10n.pendingEvidenceExercise(name)
        else if (item['training_exercise_id'] != null)
          l10n.pendingEvidenceExerciseUnnamed
        else
          l10n.pendingEvidenceExerciseGeneric,
      if (item['assignment_date'] is String) item['assignment_date'] as String,
    ].join(' · ');
    // FB1: a last-set video that queued progress waits for cannot be
    // deleted here (the completion would be left failed with no way back);
    // a failed one can be recorded again instead.
    final lastSetVideo =
        isVideo &&
        item['feedback_kind'] == 'LAST_SET' &&
        item['training_exercise_id'] != null;
    final canRerecord =
        lastSetVideo &&
        status == 'failed' &&
        item['discard_requested'] != true &&
        item['replaced_by'] == null;
    final keepForProgress = lastSetVideo && _hasDependants(id);
    final displayName = name ?? l10n.pendingEvidenceExerciseUnnamed;
    return _EvidenceRow(
      key: ValueKey('pending-row-$id'),
      icon: isVideo ? ExomIcons.video : ExomIcons.image,
      title: isVideo ? l10n.pendingMediaVideo : l10n.pendingMediaImage,
      description: description,
      status: _statusOf(l10n, status, _queue.progressOf(id)),
      detail: _errorLabel(l10n, item, feedback: true),
      attempts: item['attempts'] as int? ?? 0,
      showAttempts: status != 'queued',
      retryKey: Key('pending-retry-$id'),
      deleteKey: Key('pending-delete-$id'),
      rerecordKey: Key('pending-rerecord-$id'),
      rerecordLabel: l10n.lastSetVideoRerecordFor(displayName),
      onRetry: FeedbackUploadQueueService.canRetry(item)
          ? () => _retry(id)
          : null,
      onRerecord: canRerecord && !_rerecording
          ? () => _rerecord(id, displayName)
          : null,
      onDelete: keepForProgress ? null : () => _discard(id),
    );
  }

  Widget _syncRow(AppLocalizations l10n, Map<String, dynamic> item) {
    final id = item['id'] as String;
    final failed = item['status'] == 'failed';
    final conflict = item['last_error'] == 'progress_conflict_review_required';
    final known = conflict
        ? l10n.pendingSyncConflict
        : localizedErrorCode(l10n, item['last_error'] as String?);
    return _SyncRow(
      key: ValueKey('pending-row-$id'),
      failed: failed,
      title: failed
          ? l10n.pendingSyncFailedStatus
          : _statusLabel(l10n, item['status'] as String?),
      detail: failed ? known : _errorLabel(l10n, item) ?? _waitLabel(l10n, item),
      attempts: item['attempts'] as int? ?? 0,
      showAttempts: item['status'] != 'queued',
      retryKey: Key('pending-retry-$id'),
      deleteKey: Key('pending-delete-$id'),
      onRetry: failed && !conflict && item['discard_requested'] != true
          ? () => _retrySync(id)
          : null,
      onDelete: () => _discardSync(id),
    );
  }

  String? _errorLabel(
    AppLocalizations l10n,
    Map<String, dynamic> item, {
    bool feedback = false,
  }) {
    if (item['last_error'] == 'progress_conflict_review_required') {
      return l10n.pendingSyncConflict;
    }
    if (item['status'] != 'failed' && item['last_error'] == null) return null;
    final knownCode = localizedErrorCode(l10n, item['last_error'] as String?);
    if (knownCode != null) return knownCode;
    if (feedback) {
      // A queued upload is waiting for its next automatic attempt (network or
      // server hiccup), not failed: the error text is for the failed state.
      if (item['status'] == 'queued') {
        final code = item['last_error'];
        return code is String &&
                code.startsWith('network_') &&
                code.endsWith('_0')
            ? l10n.feedbackUploadOfflineBody
            : l10n.pendingFeedbackQueuedRetry;
      }
      return l10n.pendingFeedbackError;
    }
    return l10n.pendingSyncFailedStatus;
  }

  /// COLA (A): why a queued progress action is not sent yet, when it waits
  /// for a video (its own, one of same-day work of its training, or one of
  /// other same-day work).
  String? _waitLabel(AppLocalizations l10n, Map<String, dynamic> item) {
    if (item['status'] != 'queued') return null;
    final wait = _offlineSync.feedbackWaitOf(item);
    return wait == null ? null : progressFeedbackWaitLabel(l10n, wait);
  }

  String _statusLabel(AppLocalizations l10n, String? status) {
    return switch (status) {
      'uploading' => l10n.pendingUploadUploadingStatus,
      'processing' => l10n.pendingUploadProcessingStatus,
      'completed' => l10n.syncStatusConfirmed,
      'failed' => l10n.pendingUploadFailedStatus,
      _ => l10n.pendingUploadQueuedStatus,
    };
  }

  /// Same state reading as `FeedbackUploadStatus` (preparing, sending,
  /// processing, completed, failed, queued) with an icon besides the text, so
  /// no state depends on colour (sketch C2).
  _Status _statusOf(
    AppLocalizations l10n,
    String status,
    FeedbackUploadNotice? progress,
  ) {
    final preparing =
        status == 'uploading' &&
        progress?.kind == FeedbackUploadNoticeKind.preparing;
    final processing =
        status == 'processing' ||
        (status == 'uploading' &&
            progress?.kind == FeedbackUploadNoticeKind.processing);
    final sending = status == 'uploading' && !processing && !preparing;
    final total = progress?.totalBytes ?? 0;
    final sent = progress?.sentBytes;
    final fraction = sending && total > 0 && sent != null
        ? (sent / total).clamp(0.0, 1.0)
        : null;
    if (preparing) {
      return _Status(
        l10n.pendingUploadPreparingStatus,
        ExomIcons.phone,
        _Tone.secondary,
        indeterminate: true,
      );
    }
    if (processing) {
      return _Status(
        l10n.pendingUploadProcessingStatus,
        ExomIcons.syncing,
        _Tone.secondary,
        indeterminate: true,
      );
    }
    if (sending) {
      final size = NumberFormat(
        '0.0',
        Localizations.localeOf(context).toString(),
      );
      // Same reading as `FeedbackUploadStatus`: below 0.1 MB one decimal of
      // megabytes rounds to «0,0», so the total picks kilobytes for both
      // figures. Without a total there is only «Subiendo».
      final kilobytes = total < 100000;
      final label = fraction != null && sent != null
          ? kilobytes
                ? l10n.pendingUploadSendingKilobytes(
                    (fraction * 100).floor(),
                    size.format(sent / 1000),
                    size.format(total / 1000),
                  )
                : l10n.pendingUploadSendingBytes(
                    (fraction * 100).floor(),
                    size.format(sent / 1000000),
                    size.format(total / 1000000),
                  )
          : l10n.pendingUploadUploadingStatus;
      return _Status(
        label,
        ExomIcons.upload,
        _Tone.secondary,
        fraction: fraction,
      );
    }
    return switch (status) {
      'completed' => _Status(
        l10n.syncStatusConfirmed,
        ExomIcons.check,
        _Tone.primary,
      ),
      'failed' || 'discarding' => _Status(
        l10n.pendingUploadFailedStatus,
        ExomIcons.error,
        _Tone.error,
      ),
      _ => _Status(
        l10n.pendingUploadQueuedStatus,
        ExomIcons.phone,
        _Tone.secondary,
      ),
    };
  }
}

enum _Tone { primary, secondary, error }

class _Status {
  const _Status(
    this.label,
    this.icon,
    this.tone, {
    this.fraction,
    this.indeterminate = false,
  });

  final String label;
  final IconData icon;
  final _Tone tone;
  final double? fraction;
  final bool indeterminate;
}

TextStyle _secondaryStyle(BuildContext context) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: 14,
  height: 1.35,
  color: context.exomPalette.textSecondary,
);

/// Screen headline (sketch `.t1`): Barlow Condensed 800, painted upper case;
/// one header node with the original text, then the secondary count line.
class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExomSpacing.xl,
        ExomSpacing.sm,
        ExomSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            label: title,
            excludeSemantics: true,
            child: Text(
              title.toUpperCase(),
              style: ExomType.screenTitle.copyWith(
                color: context.exomPalette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: ExomSpacing.sm),
          Text(subtitle, style: _secondaryStyle(context)),
        ],
      ),
    );
  }
}

/// «En este móvil» block (sketch `.x-feat`): the number of pending uploads at
/// 96 in the text colour (a system operation, not client data, D19) and how
/// many of them failed.
class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.failed});

  final int count;
  final int failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.only(top: ExomSpacing.lg),
      child: ExomFeatureBlock(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ExomSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExomKicker(
                l10n.pendingUploadsKicker,
                icon: ExomIcons.phone,
              ),
              const SizedBox(height: ExomSpacing.md),
              MergeSemantics(
                child: ExomNumeral(
                  value: '$count',
                  isData: false,
                  side: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.pendingUploadsHeroLabel(count),
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: palette.textPrimary,
                        ),
                      ),
                      if (failed > 0) ...[
                        const SizedBox(height: ExomSpacing.xs),
                        Text(
                          l10n.pendingUploadsErrorCount(failed),
                          style: _secondaryStyle(context),
                        ),
                      ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.n, required this.title});

  final int n;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: ExomSpacing.xl, bottom: ExomSpacing.sm),
    child: ExomNumberedSectionHeader(n: n, title: title),
  );
}

/// Hairline-topped row of the list (sketch `.x-row`).
class _RowFrame extends StatelessWidget {
  const _RowFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.exomPalette.borderSoft,
            width: ExomRule.hairline,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 4),
        child: child,
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.detail,
    required this.attempts,
    required this.showAttempts,
    required this.retryKey,
    required this.deleteKey,
    required this.onRetry,
    required this.onDelete,
    required this.rerecordKey,
    required this.rerecordLabel,
    required this.onRerecord,
  });

  final IconData icon;
  final String title;
  final String description;
  final _Status status;
  final String? detail;
  final int attempts;
  final bool showAttempts;
  final Key retryKey;
  final Key deleteKey;
  final Key rerecordKey;
  final String rerecordLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onRerecord;

  static const double thumb = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final detailText = detail;
    return _RowFrame(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: thumb,
              height: thumb,
              child: ColoredBox(
                color: palette.surfaceElevated,
                child: Icon(icon, color: palette.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: palette.textPrimary,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: ExomSpacing.xs),
                  Text(description, style: _secondaryStyle(context)),
                ],
                const SizedBox(height: ExomSpacing.sm),
                _StatusLine(status: status),
                if (status.fraction != null) ...[
                  const SizedBox(height: ExomSpacing.sm),
                  ExomGrowBar(
                    value: status.fraction!,
                    followsBytes: true,
                    height: ExomRule.bar,
                    color: palette.textPrimary,
                    trackColor: palette.borderSoft,
                    semanticsLabel: status.label,
                  ),
                ] else if (status.indeterminate) ...[
                  const SizedBox(height: ExomSpacing.sm),
                  LinearProgressIndicator(
                    minHeight: ExomRule.bar,
                    color: palette.textPrimary,
                    backgroundColor: palette.borderSoft,
                    semanticsLabel: status.label,
                  ),
                ],
                if (detailText != null && detailText.trim().isNotEmpty) ...[
                  const SizedBox(height: ExomSpacing.xs),
                  Text(detailText, style: _secondaryStyle(context)),
                ],
                if (showAttempts) ...[
                  const SizedBox(height: ExomSpacing.xs),
                  Text(
                    l10n.pendingUploadAttempts(attempts),
                    style: _secondaryStyle(context),
                  ),
                ],
                _Actions(
                  retryKey: retryKey,
                  deleteKey: deleteKey,
                  onRetry: onRetry,
                  onDelete: onDelete,
                  rerecordKey: rerecordKey,
                  rerecordLabel: rerecordLabel,
                  onRerecord: onRerecord,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final _Status status;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final colour = switch (status.tone) {
      _Tone.primary => palette.textPrimary,
      _Tone.secondary => palette.textSecondary,
      _Tone.error => palette.error,
    };
    final iconSize = MediaQuery.textScalerOf(context).scale(16);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(status.icon, size: iconSize, color: colour),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            status.label,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: colour,
            ),
          ),
        ),
      ],
    );
  }
}

/// Failed pending action of the offline sync (sketch `.x-alert`): red edge,
/// icon, title, the reason and the same actions.
class _SyncRow extends StatelessWidget {
  const _SyncRow({
    super.key,
    required this.failed,
    required this.title,
    required this.detail,
    required this.attempts,
    required this.showAttempts,
    required this.retryKey,
    required this.deleteKey,
    required this.onRetry,
    required this.onDelete,
  });

  final bool failed;
  final String title;
  final String? detail;
  final int attempts;
  final bool showAttempts;
  final Key retryKey;
  final Key deleteKey;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _RowFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExomInlineMessage(
            kind: failed ? ExomMessageKind.error : ExomMessageKind.pendiente,
            title: title,
            body: detail,
          ),
          if (showAttempts) ...[
            const SizedBox(height: ExomSpacing.xs),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 14),
              child: Text(
                l10n.pendingUploadAttempts(attempts),
                style: _secondaryStyle(context),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 14),
            child: _Actions(
              retryKey: retryKey,
              deleteKey: deleteKey,
              onRetry: onRetry,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

/// «Reintentar», «Volver a grabar» (FB1) and «Eliminar» as discreet in-line
/// actions (sketch `.c-act`), never lime: there is no single next step.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.retryKey,
    required this.deleteKey,
    required this.onRetry,
    required this.onDelete,
    this.rerecordKey,
    this.rerecordLabel,
    this.onRerecord,
  });

  final Key retryKey;
  final Key deleteKey;
  final Key? rerecordKey;
  final String? rerecordLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onRerecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: ExomSpacing.lg,
      children: [
        if (onRetry != null)
          _RowAction(
            key: retryKey,
            label: l10n.pendingUploadRetry,
            icon: ExomIcons.retry,
            onTap: onRetry!,
          ),
        if (onRerecord != null)
          _RowAction(
            key: rerecordKey,
            label: l10n.lastSetVideoRerecord,
            semanticsLabel: rerecordLabel,
            icon: ExomIcons.video,
            onTap: onRerecord!,
          ),
        if (onDelete != null)
          _RowAction(
            key: deleteKey,
            label: l10n.pendingUploadDelete,
            onTap: onDelete!,
          ),
      ],
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// Spoken label when [label] alone does not say what it acts on.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final iconSize = MediaQuery.textScalerOf(context).scale(16);
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: iconSize, color: palette.textPrimary),
                  const SizedBox(width: 6),
                ],
                // Wraps instead of overflowing when a long label meets a
                // large text size on a narrow screen (FB1 r2).
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// In-line result strip under the list: a hairline on top, the message inside.
class _OutcomeStrip extends StatelessWidget {
  const _OutcomeStrip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(
            top: BorderSide(
              color: palette.borderSoft,
              width: ExomRule.hairline,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExomSpacing.xl,
            ExomSpacing.md,
            ExomSpacing.xl,
            ExomSpacing.md,
          ),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// COLA (A): the text of a progress [wait], shared by «Subidas pendientes»
/// and the training detail (COLA r3).
String progressFeedbackWaitLabel(
  AppLocalizations l10n,
  ProgressFeedbackWait wait,
) => switch (wait) {
  ProgressFeedbackWait.ownVideo => l10n.pendingSyncWaitsOwnVideo,
  ProgressFeedbackWait.behindVideo => l10n.pendingSyncWaitsBehindVideo,
  ProgressFeedbackWait.behindDayVideo => l10n.pendingSyncWaitsBehindDayVideo,
};
