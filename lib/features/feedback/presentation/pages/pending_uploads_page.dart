import 'dart:async';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';

import 'package:flutter/material.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';

class PendingUploadsPage extends StatefulWidget {
  const PendingUploadsPage({super.key, this.exerciseNames = const {}});

  final Map<String, String> exerciseNames;

  @override
  State<PendingUploadsPage> createState() => _PendingUploadsPageState();
}

class _PendingUploadsPageState extends State<PendingUploadsPage> {
  FeedbackUploadQueueService get _queue => sl<FeedbackUploadQueueService>();
  OfflineSyncService get _offlineSync => sl<OfflineSyncService>();
  StreamSubscription<FeedbackUploadNotice>? _uploadSubscription;
  StreamSubscription<void>? _syncSubscription;
  late final String? _sessionStamp;
  bool get _sameSession => mounted && _sessionStamp != null &&
      sl<LocalStorage>().sessionStamp == _sessionStamp;

  @override
  void initState() {
    super.initState();
    _sessionStamp = sl<LocalStorage>().sessionStamp;
    _uploadSubscription = _queue.notices.listen((_) {
      if (_sameSession) setState(() {});
    });
    _syncSubscription = _offlineSync.changes.listen((_) {
      if (_sameSession) setState(() {});
    });
  }

  @override
  void dispose() {
    _uploadSubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _retry(String id) async {
    if (!_sameSession) return;
    try {
      await _queue.retry(id);
    } catch (_) {
      if (mounted && _sameSession) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).pendingFeedbackError)));
      }
    }
    if (_sameSession) setState(() {});
  }

  Future<void> _discard(String id) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pendingUploadDeleteTitle),
        content: Text(l10n.pendingUploadDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.pendingUploadDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !_sameSession) return;
    await _queue.discard(id);
    if (mounted) setState(() {});
  }

  Future<void> _retrySync(String id) async {
    if (!_sameSession) return;
    await _offlineSync.retryAction(id);
    if (mounted) setState(() {});
  }

  Future<void> _discardSync(String id) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pendingUploadDeleteTitle),
        content: Text(l10n.pendingSyncDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.pendingUploadDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !_sameSession) return;
    await _offlineSync.discardAction(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _sameSession ? _queue.pendingItems : <Map<String, dynamic>>[];
    final syncFailures = _sameSession ? _offlineSync.pendingActions : <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pendingUploadsTitle)),
      body: items.isEmpty && syncFailures.isEmpty
          ? Center(child: Text(l10n.pendingUploadsEmpty))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in items) ...[
                  _PendingItemTile(
                    icon: item['media_type'] == 'VIDEO'
                        ? Icons.videocam_outlined
                        : Icons.image_outlined,
                    title: _statusLabel(l10n, item['status'] as String?),
                    uploadStatus: FeedbackUploadStatus(
                      status: item['status'] as String? ?? 'queued',
                      progress: _queue.progressOf(item['id'] as String),
                    ),
                    attempts: item['attempts'] as int? ?? 0,
                    description: [
                      if (item['training_exercise_id'] != null || item['exercise_id'] != null)
                        l10n.pendingEvidenceExercise(
                          widget.exerciseNames[item['training_exercise_id']] ??
                          item['exercise_name'] as String? ??
                          (item['training_exercise_id'] ?? item['exercise_id']).toString()),
                      if (item['assignment_date'] is String) item['assignment_date'] as String,
                    ].join(' · '),
                    lastError: _errorLabel(l10n, item, feedback: true),
                    onRetry: FeedbackUploadQueueService.canRetry(item)
                        ? () => _retry(item['id'] as String)
                        : null,
                    onDelete: () => _discard(item['id'] as String),
                  ),
                  const SizedBox(height: 8),
                ],
                if (syncFailures.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      l10n.pendingSyncFailuresTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final item in syncFailures) ...[
                    _PendingItemTile(
                      icon: Icons.sync_problem_outlined,
                      title: _statusLabel(l10n, item['status'] as String?),
                      attempts: item['attempts'] as int? ?? 0,
                      lastError: _errorLabel(l10n, item),
                      onRetry:
                          item['status'] == 'failed' &&
                              item['last_error'] !=
                                  'progress_conflict_review_required' &&
                              item['discard_requested'] != true
                          ? () => _retrySync(item['id'] as String)
                          : null,
                      onDelete: () => _discardSync(item['id'] as String),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
    );
  }

  String? _errorLabel(AppLocalizations l10n, Map<String, dynamic> item,
      {bool feedback = false}) {
    if (item['last_error'] == 'progress_conflict_review_required') {
      return l10n.pendingSyncConflict;
    }
    if (item['status'] != 'failed' && item['last_error'] == null) return null;
    return feedback ? l10n.pendingFeedbackError : l10n.pendingSyncFailedStatus;
  }

  String _statusLabel(AppLocalizations l10n, String? status) {
    return switch (status) {
      'uploading' => l10n.pendingUploadUploadingStatus,
      'processing' => l10n.pendingUploadProcessingStatus,
      'completed' => l10n.pendingUploadCompletedStatus,
      'failed' => l10n.pendingUploadFailedStatus,
      _ => l10n.pendingUploadQueuedStatus,
    };
  }
}

class _PendingItemTile extends StatelessWidget {
  const _PendingItemTile({
    required this.icon,
    required this.title,
    required this.attempts,
    required this.lastError,
    required this.onRetry,
    required this.onDelete,
    this.uploadStatus,
    this.description,
  });

  final Widget? uploadStatus;
  final String? description;
  final IconData icon;
  final String title;
  final int attempts;
  final String? lastError;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: uploadStatus ?? Text(title),
        subtitle: Text(
          [
            if (description != null && description!.isNotEmpty) description!,
            l10n.pendingUploadAttempts(attempts),
            if (lastError != null && lastError!.trim().isNotEmpty) lastError!,
          ].join('\n'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRetry != null)
              IconButton(
                tooltip: l10n.pendingUploadRetry,
                color: Theme.of(context).colorScheme.primary,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              ),
            IconButton(
              tooltip: l10n.pendingUploadDelete,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
