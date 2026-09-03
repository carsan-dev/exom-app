import 'dart:async';

import 'package:flutter/material.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';

class PendingUploadsPage extends StatefulWidget {
  const PendingUploadsPage({super.key});

  @override
  State<PendingUploadsPage> createState() => _PendingUploadsPageState();
}

class _PendingUploadsPageState extends State<PendingUploadsPage> {
  FeedbackUploadQueueService get _queue => sl<FeedbackUploadQueueService>();
  OfflineSyncService get _offlineSync => sl<OfflineSyncService>();
  StreamSubscription<FeedbackUploadNotice>? _uploadSubscription;
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _uploadSubscription = _queue.notices.listen((_) {
      if (mounted) setState(() {});
    });
    _syncSubscription = _offlineSync.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uploadSubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _retry(String id) async {
    await _queue.retry(id);
    if (mounted) setState(() {});
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
    if (confirmed != true) return;
    await _queue.discard(id);
    if (mounted) setState(() {});
  }

  Future<void> _retrySync(String id) async {
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
    if (confirmed != true) return;
    await _offlineSync.discardAction(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _queue.pendingItems;
    final syncFailures = _offlineSync.pendingActions;
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
                    attempts: item['attempts'] as int? ?? 0,
                    lastError: item['last_error'] as String?,
                    onRetry: item['status'] == 'failed'
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
                      lastError: item['last_error'] as String?,
                      onRetry: item['status'] == 'failed'
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

  String _statusLabel(AppLocalizations l10n, String? status) {
    return switch (status) {
      'uploading' => l10n.pendingUploadUploadingStatus,
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
  });

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
        title: Text(title),
        subtitle: Text(
          [
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
