import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_operation_bar.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// State of one feedback upload as the page reads it from the queue (sketch
/// C1 a-e, h; plan §11 «bytes enviados vs confirmación»).
enum _UploadState {
  preparing,
  sending,
  processing,
  confirmed,
  failed,
  discarding,
  queuedOffline,
  queued,
}

/// One upload of the durable feedback queue (L5-C2). Every state has its own
/// icon and text, so none depends on colour alone:
///
/// * preparing: phone icon, «Preparando archivo», indeterminate bar;
/// * sending: cloud icon, percentage and megabytes, a bar that follows the
///   bytes (no bytes known yet: «Subiendo», indeterminate bar);
/// * processing: the bytes arrived, EXOM still has to confirm; it never reads
///   as confirmed (D19, plan §11);
/// * confirmed: check and text in the text colour, never lime (D19), with
///   «Tu entrenador ya puede revisarlo» (D15);
/// * failed: error message that says the evidence is kept on the phone (only
///   when the queue still has the file) and «Reintentar»;
/// * queued without connection: the last attempt got no response from the
///   server (`network_<type>_0`, written by the queue only for offline errors)
///   and the queue is still waiting out that attempt's delay; it will be sent
///   when the connection is back. A session pause puts a claimed upload back
///   in the queue without touching that old error, so then it is only queued;
///   the same once the reconnection has removed the delay;
/// * a discard the user asked for reads as discarding even when the queue
///   left it `failed` because deleting the file failed (`cleanup_failed`).
///
/// The managed transport reports «processing» while it checks whether the
/// object is already on the server, before any byte of the attempt is sent
/// (`lib/core/services/managed_upload.dart:254` → `:139`, D2). While the queue
/// still says `uploading` and the attempt has sent no bytes
/// ([bytesSentThisAttempt] false), that notice reads as preparing, so the row
/// never goes processing → sending → processing.
///
/// Presentation only: it reads [status], [progress], [lastError],
/// [discardRequested], [claimedAt] and [nextAttemptAt] as the queue writes
/// them and never changes the queue.
class FeedbackUploadStatus extends StatelessWidget {
  const FeedbackUploadStatus({
    super.key,
    required this.status,
    this.progress,
    this.onRetry,
    this.lastError,
    this.discardRequested = false,
    this.claimedAt,
    this.nextAttemptAt,
    this.bytesSentThisAttempt = true,
  });

  /// Upload fields as the queue stores them, for [FeedbackQueuePanel].
  factory FeedbackUploadStatus.fromItem(
    Map<String, dynamic> item, {
    Key? key,
    FeedbackUploadNotice? progress,
    VoidCallback? onRetry,
    bool bytesSentThisAttempt = true,
  }) => FeedbackUploadStatus(
    key: key,
    status: item['status'] as String? ?? 'queued',
    progress: progress,
    onRetry: onRetry,
    lastError: item['last_error'] as String?,
    discardRequested: item['discard_requested'] == true,
    claimedAt: item['claimed_at'] as String?,
    nextAttemptAt: item['next_attempt_at'] as String?,
    bytesSentThisAttempt: bytesSentThisAttempt,
  );

  /// Last error code the queue stored for the upload (`last_error`).
  final String? lastError;
  final String status;
  final FeedbackUploadNotice? progress;
  final VoidCallback? onRetry;

  /// The user asked to discard the upload (`discard_requested`).
  final bool discardRequested;

  /// When the queue last claimed the upload for an attempt (`claimed_at`).
  final String? claimedAt;

  /// Earliest time of the next automatic attempt (`next_attempt_at`).
  final String? nextAttemptAt;

  /// The current attempt already reported sent bytes. Without them a
  /// `processing` notice of an `uploading` row is the transport's check
  /// before the transfer, not the server processing the file.
  final bool bytesSentThisAttempt;

  /// Retryable errors the queue stores without an HTTP response: no
  /// connection (`isOfflineError`). Server errors carry their status code.
  static final RegExp _noResponse = RegExp(r'^network_[A-Za-z]+_0$');

  /// The queue is waiting out the delay of an attempt that got no response.
  /// The delay is written after the attempt's claim, so a claim at or after
  /// it means a later attempt was paused (session) and no delay means the
  /// reconnection removed it. Rows without a claim (older builds) keep the
  /// error alone as the signal.
  bool get _waitsForNetwork {
    if (!_noResponse.hasMatch(lastError ?? '')) return false;
    final claimed = DateTime.tryParse(claimedAt ?? '');
    if (claimed == null) return true;
    final next = DateTime.tryParse(nextAttemptAt ?? '');
    return next != null && next.isAfter(claimed);
  }

  _UploadState get _state {
    if (discardRequested && status != 'completed') {
      return _UploadState.discarding;
    }
    final kind = progress?.kind;
    if (status == 'uploading' &&
        (kind == FeedbackUploadNoticeKind.preparing ||
            (kind == FeedbackUploadNoticeKind.processing &&
                !bytesSentThisAttempt))) {
      return _UploadState.preparing;
    }
    if (status == 'processing' ||
        (status == 'uploading' && kind == FeedbackUploadNoticeKind.processing)) {
      return _UploadState.processing;
    }
    return switch (status) {
      'uploading' => _UploadState.sending,
      'completed' => _UploadState.confirmed,
      'failed' => _UploadState.failed,
      'discarding' => _UploadState.discarding,
      _ => _waitsForNetwork ? _UploadState.queuedOffline : _UploadState.queued,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final retry = onRetry;
    switch (_state) {
      case _UploadState.preparing:
        return _ProgressLine(
          icon: ExomIcons.phone,
          title: l10n.pendingUploadPreparingStatus,
          body: l10n.feedbackUploadPreparingBody,
          showBar: true,
        );
      case _UploadState.sending:
        final total = progress?.totalBytes ?? 0;
        final sent = progress?.sentBytes;
        final fraction = total > 0 && sent != null
            ? (sent / total).clamp(0.0, 1.0)
            : null;
        final size = NumberFormat(
          '0.0',
          Localizations.localeOf(context).toString(),
        );
        // Below 0.1 MB one decimal of megabytes rounds to «0,0»: the total
        // picks kilobytes for both figures. Without a total (unknown or 0)
        // there is no percentage nor «of X», only «Subiendo».
        final kilobytes = total < 100000;
        return _ProgressLine(
          icon: ExomIcons.upload,
          title: fraction != null && sent != null
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
              : l10n.pendingUploadUploadingStatus,
          showBar: true,
          value: fraction,
        );
      case _UploadState.processing:
        return _ProgressLine(
          icon: ExomIcons.syncing,
          title: l10n.feedbackUploadProcessingTitle,
          body: l10n.feedbackUploadProcessingBody,
          showBar: true,
        );
      case _UploadState.confirmed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExomInlineMessage(
              kind: ExomMessageKind.ok,
              title: l10n.syncStatusConfirmed,
              body: l10n.feedbackUploadConfirmedBody,
            ),
            const SizedBox(height: ExomSpacing.sm),
            const ExomOperationBar(value: 1),
          ],
        );
      case _UploadState.failed:
        return ExomInlineMessage(
          kind: ExomMessageKind.error,
          title: l10n.feedbackUploadFailedTitle,
          // The queue marks a vanished file as `file_missing`: then nothing
          // is kept and the sentence would be false.
          body: lastError == 'file_missing' ? null : l10n.feedbackUploadKeptBody,
          actionLabel: retry == null ? null : l10n.pendingUploadRetry,
          onAction: retry,
        );
      case _UploadState.discarding:
        // Being deleted at the user's request: no «kept» claim, no retry.
        return ExomInlineMessage(
          kind: ExomMessageKind.error,
          title: l10n.pendingUploadFailedStatus,
        );
      case _UploadState.queuedOffline:
        return ExomInlineMessage(
          kind: ExomMessageKind.pendiente,
          title: l10n.pendingUploadQueuedStatus,
          body: l10n.feedbackUploadOfflineBody,
          actionLabel: retry == null ? null : l10n.pendingUploadRetry,
          onAction: retry,
        );
      case _UploadState.queued:
        return _ProgressLine(
          icon: ExomIcons.time,
          title: l10n.pendingUploadQueuedStatus,
          showBar: false,
          onRetry: retry,
        );
    }
  }
}

/// Icon, title, optional body and the operation bar (`.bar`) of an upload in
/// progress. Not a live region: the percentage changes too often to announce.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.icon,
    required this.title,
    required this.showBar,
    this.body,
    this.value,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? body;
  final bool showBar;
  final double? value;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final iconSize = MediaQuery.textScalerOf(context).scale(18);
    final bodyText = body;
    final retry = onRetry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: ExomSpacing.sm),
              Expanded(
                child: Column(
                  // Full width: the whole line is the hit area of the status.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: palette.textSecondary,
                      ),
                    ),
                    if (bodyText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        bodyText,
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
            ],
          ),
        ),
        if (showBar) ...[
          const SizedBox(height: ExomSpacing.sm),
          ExomOperationBar(value: value),
        ],
        if (retry != null)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: iconSize + ExomSpacing.sm,
            ),
            child: ExomTextLink(label: l10n.pendingUploadRetry, onTap: retry),
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

  /// `claimed_at` of the attempt in which each upload reported sent bytes.
  /// A new claim is a new attempt, so the rule starts again (D2).
  final _bytesSentAttempt = <String, String?>{};
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
      if (notice.kind == FeedbackUploadNoticeKind.uploading &&
          notice.sentBytes != null) {
        for (final item in queue.pendingItems) {
          if (item['id'] == notice.id) {
            _bytesSentAttempt[notice.id] = item['claimed_at'] as String?;
          }
        }
      }
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
    _bytesSentAttempt.clear();
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
      padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (queue.hasUnattributedData)
            Padding(
              padding: const EdgeInsets.only(top: ExomSpacing.md),
              child: ExomInlineMessage(
                kind: ExomMessageKind.info,
                title: AppLocalizations.of(context).pendingUploadLegacyRecovery,
              ),
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: ExomSpacing.md),
              child: FeedbackUploadStatus.fromItem(
                item,
                progress: queue.progressOf(item['id'] as String),
                bytesSentThisAttempt:
                    _bytesSentAttempt.containsKey(item['id']) &&
                    _bytesSentAttempt[item['id']] == item['claimed_at'],
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
