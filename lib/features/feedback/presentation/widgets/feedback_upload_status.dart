import 'dart:async';

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
    final label = preparing
        ? l10n.pendingUploadPreparingStatus
        : processing
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
        if (sending || processing || preparing)
          LinearProgressIndicator(
            value: processing ? null : fraction,
            backgroundColor: colors.surfaceContainerHighest,
          ),
      ],
    );
  }
}

class FeedbackQueuePanel extends StatefulWidget {
  const FeedbackQueuePanel({super.key, required this.queue});
  final FeedbackUploadQueueService queue;
  @override
  State<FeedbackQueuePanel> createState() => _FeedbackQueuePanelState();
}

class _FeedbackQueuePanelState extends State<FeedbackQueuePanel> {
  final _completionTimers = <String, Timer>{};
  StreamSubscription<FeedbackUploadNotice>? _subscription;
  FeedbackUploadQueueService get queue => widget.queue;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _subscription = queue.notices.listen((notice) {
      if (!mounted) return;
      if (notice.kind == FeedbackUploadNoticeKind.completed) {
        // UI lifetime only: keep durable receipts and cleanup work untouched.
        // Keep expired timers so duplicate confirmations cannot revive the notice.
        _completionTimers.putIfAbsent(
          notice.id,
          () => Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() {});
          }),
        );
      }
      setState(() {});
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
  }

  @override
  void didUpdateWidget(covariant FeedbackQueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queue != queue) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = queue.pendingItems.where(
      (item) =>
          item['status'] != 'completed' ||
          (_completionTimers[item['id']]?.isActive ?? false),
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
                onRetry: FeedbackUploadQueueService.canRetry(item)
                    ? () => queue.retry(item['id'] as String)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Keeps transfer status visible independently of the form/history scroll and load.
class FeedbackQueueLayout extends StatelessWidget {
  const FeedbackQueueLayout({
    super.key,
    required this.queue,
    required this.child,
  });
  final FeedbackUploadQueueService queue;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * .3),
          child: SingleChildScrollView(child: FeedbackQueuePanel(queue: queue)),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
