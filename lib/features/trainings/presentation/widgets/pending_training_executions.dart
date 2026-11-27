import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/models/training_execution_discard.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/features/trainings/presentation/utils/session_date_label.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Global, owner-scoped recovery list independent of the visible calendar month.
/// Callbacks expose only the typed, execution-specific RD1 contract.
class PendingTrainingExecutions extends StatefulWidget {
  const PendingTrainingExecutions({
    super.key,
    required this.storage,
    required this.onSelect,
    this.inspectDiscard,
    this.discard,
    this.onBusyChanged,
    this.firstActionsKey,
  });

  final LocalStorage storage;
  final void Function(Map<String, dynamic> entry, String action) onSelect;
  final TrainingExecutionDiscardResult Function(TrainingExecutionDiscardRequest)?
      inspectDiscard;
  final Future<TrainingExecutionDiscardResult> Function(
      TrainingExecutionDiscardRequest)? discard;

  /// Told `true` when a discard starts (its row actions are disabled) and
  /// `false` when it ends, even if this widget is gone by then, so a parent
  /// action on the same sessions (the «Continuar sesión» footer) can follow
  /// the same busy state and re-read the list.
  final ValueChanged<bool>? onBusyChanged;

  /// Key set on the action row of the first session, so the parent can measure
  /// how tall the box must be for those actions to show in full.
  final Key? firstActionsKey;

  @override
  State<PendingTrainingExecutions> createState() => _PendingTrainingExecutionsState();
}

class _PendingTrainingExecutionsState extends State<PendingTrainingExecutions> {
  bool _busy = false;
  String? _message;
  ExomMessageKind _messageKind = ExomMessageKind.error;

  TrainingExecutionDiscardReason? _sessionFailure(TrainingExecutionDiscardRequest request) {
    if (widget.storage.ownerId != request.ownerId || request.ownerId.isEmpty) {
      return TrainingExecutionDiscardReason.wrongOwner;
    }
    if (widget.storage.sessionStamp != request.sessionStamp || request.sessionStamp.isEmpty) {
      return TrainingExecutionDiscardReason.staleSession;
    }
    return null;
  }

  String _reason(AppLocalizations l10n, TrainingExecutionDiscardReason reason) => switch (reason) {
    TrainingExecutionDiscardReason.wrongOwner ||
    TrainingExecutionDiscardReason.staleSession => l10n.trainingDiscardOwner,
    TrainingExecutionDiscardReason.notFound ||
    TrainingExecutionDiscardReason.identityMismatch => l10n.trainingDiscardIdentityChanged,
    TrainingExecutionDiscardReason.unknownOwnership => l10n.trainingDiscardUnknownOwner,
    TrainingExecutionDiscardReason.confirmed => l10n.trainingDiscardConfirmed,
    TrainingExecutionDiscardReason.inFlight => l10n.trainingDiscardInFlight,
    TrainingExecutionDiscardReason.unsentDependencies => l10n.trainingDiscardDependencies,
    TrainingExecutionDiscardReason.discarded ||
    TrainingExecutionDiscardReason.alreadyDiscarded => l10n.trainingDiscardSuccess,
    TrainingExecutionDiscardReason.storageFailure ||
    TrainingExecutionDiscardReason.eligible => l10n.trainingDiscardFailure,
  };

  /// Shows the outcome of [reason]: a done discard is a confirmed system state
  /// (text colour with a check, D19); every refusal or failure is an error.
  void _showResult(AppLocalizations l10n, TrainingExecutionDiscardReason reason) {
    _message = _reason(l10n, reason);
    _messageKind = switch (reason) {
      TrainingExecutionDiscardReason.discarded ||
      TrainingExecutionDiscardReason.alreadyDiscarded => ExomMessageKind.ok,
      _ => ExomMessageKind.error,
    };
  }

  Future<void> _askDiscard(TrainingExecutionDiscardRequest request, String name) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final onBusyChanged = widget.onBusyChanged;
    setState(() { _busy = true; _message = null; });
    onBusyChanged?.call(true);
    try {
      final failure = _sessionFailure(request);
      final inspection = failure != null
          ? TrainingExecutionDiscardResult(failure)
          : widget.inspectDiscard?.call(request) ??
              const TrainingExecutionDiscardResult(TrainingExecutionDiscardReason.storageFailure);
      if (!inspection.canDiscard) {
        setState(() => _showResult(l10n, inspection.reason));
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.trainingDiscardTitle),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(l10n.trainingDiscardIdentity(name, request.date, request.executionId)),
              const SizedBox(height: 16),
              Text(l10n.trainingDiscardExplanation),
            ],
          )),
          actions: [
            TextButton(
              key: const Key('pending-discard-cancel'),
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              key: const Key('pending-discard-confirm'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.trainingDiscardConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      // Keep exactly the captured request. Inspection is not a reservation;
      // RD1 rechecks identity, ownership and dependencies under its locks.
      final sessionFailure = _sessionFailure(request);
      final result = sessionFailure != null
          ? TrainingExecutionDiscardResult(sessionFailure)
          : await widget.discard!(request);
      if (!mounted) return;
      setState(() => _showResult(l10n, result.reason));
      // Re-read owner-scoped storage; never remove by date/training or clear queues.
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = l10n.trainingDiscardFailure;
          _messageKind = ExomMessageKind.error;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      onBusyChanged?.call(false);
    }
  }

  /// Leading date box of a row: day and short month of the assignment date in
  /// the active locale, or a clock when the stored date does not parse.
  ExomRowLeading _leading(BuildContext context, Object? assignmentDate) {
    final date = assignmentDate is String ? DateTime.tryParse(assignmentDate) : null;
    if (date == null) return const ExomRowLeading.icon(ExomIcons.time);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ExomRowLeading.date(
      day: DateFormat('d', locale).format(date),
      label: DateFormat('MMM', locale).format(date),
    );
  }

  /// Long date of the row title, as the session selector shows it (L5-D52).
  String _rowDate(BuildContext context, Object? assignmentDate) =>
      assignmentDate is String
          ? sessionDateLabel(context, assignmentDate)
          : '$assignmentDate';

  /// Status line of a local session: icon and text, never colour alone.
  Widget _status(AppLocalizations l10n, Object? status) => switch (status) {
    'pending-sync' => ExomSyncStatus(
      state: ExomSyncState.pendiente,
      label: l10n.trainingPendingSync,
    ),
    'conflict' => ExomSyncStatus(
      state: ExomSyncState.fallida,
      label: l10n.trainingSyncConflict,
    ),
    _ => ExomSyncStatus(
      state: ExomSyncState.pendiente,
      label: l10n.trainingPendingFinalize,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final entries = widget.storage.getPendingTrainingExecutions();
    final owner = widget.storage.ownerId ?? '';
    final stamp = widget.storage.sessionStamp ?? '';
    final l10n = AppLocalizations.of(context);
    final message = _message;
    // Sessions the notice talks about: those still to finalize.
    final finalizable =
        entries.where((entry) => entry['status'] != 'pending-sync').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message != null)
          Padding(
            padding: _messagePadding,
            child: ExomInlineMessage(
              key: const Key('pending-discard-result'),
              kind: _messageKind,
              title: message,
            ),
          ),
        if (finalizable > 0)
          Padding(
            padding: _messagePadding,
            child: ExomInlineMessage(
              kind: ExomMessageKind.pendiente,
              title: l10n.trainingPendingFinalizeNotice(finalizable),
            ),
          ),
        ExomFlatRowGroup(
          children: [
            for (final (index, entry) in entries.indexed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // D14-6: the technical session ID is not on the row; the
                  // discard confirmation shows it (trainingDiscardIdentity).
                  ExomRichRow(
                    leading: _leading(context, entry['assignment_date']),
                    title:
                        '${entry['training_name'] ?? entry['training_id']} · ${_rowDate(context, entry['assignment_date'])}',
                    status: _status(l10n, entry['status']),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      _actionsInset,
                      0,
                      12,
                      pendingActionsBottomPadding,
                    ),
                    child: Wrap(
                      key: index == 0 ? widget.firstActionsKey : null,
                      spacing: 16,
                      children: [
                        if (entry['status'] != 'pending-sync' &&
                            entry['status'] != 'conflict') ...[
                          ExomTextLink(
                            key: Key('pending-continue-${entry['id']}'),
                            label: l10n.trainingContinue,
                            onTap: _busy
                                ? null
                                : () => widget.onSelect(entry, 'continue'),
                          ),
                          ExomTextLink(
                            key: Key('pending-finalize-${entry['id']}'),
                            label: l10n.trainingFinalize,
                            onTap: _busy
                                ? null
                                : () => widget.onSelect(entry, 'finalize'),
                          ),
                        ],
                        ExomTextLink(
                          key: Key('pending-discard-${entry['id']}'),
                          label: l10n.trainingDiscardPending,
                          danger: true,
                          onTap: _busy
                              ? null
                              : () => _askDiscard(
                                  TrainingExecutionDiscardRequest(
                                    ownerId: owner,
                                    sessionStamp: stamp,
                                    executionId: entry['id'] as String? ?? '',
                                    trainingId:
                                        entry['training_id'] as String? ?? '',
                                    date:
                                        entry['assignment_date'] as String? ??
                                        '',
                                  ),
                                  '${entry['training_name'] ?? entry['training_id']}',
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

const EdgeInsetsGeometry _messagePadding = EdgeInsetsDirectional.fromSTEB(
  20,
  12,
  20,
  12,
);

/// Padding under the row actions of a session; the pending box of the
/// Entrenar page adds it to the height it measures.
const double pendingActionsBottomPadding = 8;

/// Start inset of the row actions: under the title, past the 56 dp date box
/// (20 row padding + 56 + 14 gap of `ExomRichRow`).
const double _actionsInset = 20 + ExomRichRow.thumbSize + 14;
