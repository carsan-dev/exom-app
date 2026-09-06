import 'package:flutter/material.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class FeedbackUploadStatus extends StatelessWidget {
  const FeedbackUploadStatus({
    super.key,
    required this.status,
    this.progress,
    this.onRetry,
  });
  final String status;
  final FeedbackUploadNotice? progress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final processing =
        status == 'processing' ||
        (status == 'uploading' &&
            progress?.kind == FeedbackUploadNoticeKind.processing);
    final sending = status == 'uploading' && !processing;
    final total = progress?.totalBytes ?? 0;
    final sent = progress?.sentBytes;
    final fraction = sending && total > 0 && sent != null
        ? (sent / total).clamp(0.0, 1.0)
        : null;
    final label = processing
        ? l10n.pendingUploadProcessingStatus
        : switch (status) {
            'uploading' => l10n.pendingUploadUploadingStatus,
            'completed' => l10n.pendingUploadCompletedStatus,
            'failed' || 'discarding' => l10n.pendingUploadFailedStatus,
            _ => l10n.pendingUploadQueuedStatus,
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            if (fraction != null) Text('${(fraction * 100).floor()}%'),
            if (onRetry != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colors.primary),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.pendingUploadRetry),
              ),
          ],
        ),
        if (sending || processing)
          LinearProgressIndicator(value: processing ? null : fraction),
      ],
    );
  }
}

class FeedbackQueuePanel extends StatelessWidget {
  const FeedbackQueuePanel({super.key, required this.queue});
  final FeedbackUploadQueueService queue;
  @override
  Widget build(BuildContext context) => StreamBuilder<FeedbackUploadNotice>(
    stream: queue.notices,
    builder: (context, _) {
      final items = queue.pendingItems.where(
        (item) =>
            item['status'] != 'completed' ||
            queue.progressOf(item['id'] as String) != null,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            if (queue.hasUnattributedData)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  AppLocalizations.of(context).pendingUploadLegacyRecovery,
                ),
              ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FeedbackUploadStatus(
                  status: item['status'] as String? ?? 'queued',
                  progress: queue.progressOf(item['id'] as String),
                  onRetry:
                      item['status'] == 'failed' &&
                          item['discard_requested'] != true
                      ? () => queue.retry(item['id'] as String)
                      : null,
                ),
              ),
          ],
        ),
      );
    },
  );
}
