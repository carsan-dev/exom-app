import 'package:flutter/material.dart';
import 'package:exom_app/core/models/training_execution_discard.dart';
import 'package:exom_app/core/storage/local_storage.dart';
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
  });

  final LocalStorage storage;
  final void Function(Map<String, dynamic> entry, String action) onSelect;
  final TrainingExecutionDiscardResult Function(TrainingExecutionDiscardRequest)?
      inspectDiscard;
  final Future<TrainingExecutionDiscardResult> Function(
      TrainingExecutionDiscardRequest)? discard;

  @override
  State<PendingTrainingExecutions> createState() => _PendingTrainingExecutionsState();
}

class _PendingTrainingExecutionsState extends State<PendingTrainingExecutions> {
  bool _busy = false;
  String? _message;

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

  Future<void> _askDiscard(TrainingExecutionDiscardRequest request, String name) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() { _busy = true; _message = null; });
    try {
      final failure = _sessionFailure(request);
      final inspection = failure != null
          ? TrainingExecutionDiscardResult(failure)
          : widget.inspectDiscard?.call(request) ??
              const TrainingExecutionDiscardResult(TrainingExecutionDiscardReason.storageFailure);
      if (!inspection.canDiscard) {
        setState(() => _message = _reason(l10n, inspection.reason));
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
      setState(() => _message = _reason(l10n, result.reason));
      // Re-read owner-scoped storage; never remove by date/training or clear queues.
    } catch (_) {
      if (mounted) setState(() => _message = l10n.trainingDiscardFailure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.storage.getPendingTrainingExecutions();
    final owner = widget.storage.ownerId ?? '';
    final stamp = widget.storage.sessionStamp ?? '';
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_message != null)
        Padding(padding: const EdgeInsets.all(16),
          child: Semantics(liveRegion: true, child: Text(_message!, key: const Key('pending-discard-result')))),
      if (entries.any((entry) => entry['status'] != 'pending-sync'))
        Padding(padding: const EdgeInsets.all(16), child: Text(l10n.trainingPendingFinalizeNotice)),
      for (final entry in entries)
        Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(
            title: Text('${entry['training_name'] ?? entry['training_id']} · ${entry['assignment_date']}'),
            subtitle: Text('${entry['id']} · '
                '${entry['status'] == 'pending-sync' ? l10n.trainingPendingSync : entry['status'] == 'conflict' ? l10n.trainingSyncConflict : l10n.trainingPendingFinalize}'),
          ),
          Wrap(children: [
            if (entry['status'] != 'pending-sync' && entry['status'] != 'conflict') ...[
              TextButton(key: Key('pending-continue-${entry['id']}'),
                onPressed: _busy ? null : () => widget.onSelect(entry, 'continue'),
                child: Text(l10n.trainingContinue)),
              TextButton(key: Key('pending-finalize-${entry['id']}'),
                onPressed: _busy ? null : () => widget.onSelect(entry, 'finalize'),
                child: Text(l10n.trainingFinalize)),
            ],
            TextButton.icon(
              key: Key('pending-discard-${entry['id']}'),
              icon: const Icon(Icons.delete_outline),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: _busy ? null : () => _askDiscard(
                TrainingExecutionDiscardRequest(ownerId: owner, sessionStamp: stamp,
                  executionId: entry['id'] as String? ?? '',
                  trainingId: entry['training_id'] as String? ?? '',
                  date: entry['assignment_date'] as String? ?? ''),
                '${entry['training_name'] ?? entry['training_id']}',
              ),
              label: Text(l10n.trainingDiscardPending),
            ),
          ]),
        ])),
    ]);
  }
}
