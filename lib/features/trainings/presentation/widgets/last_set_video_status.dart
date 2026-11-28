import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// State of the last-set video of one exercise in one execution (FB1).
enum LastSetVideoState {
  /// No video was ever attached (or it was discarded).
  missing,

  /// Queued on this phone, waiting to be sent.
  pending,

  /// Being uploaded or processed right now.
  sending,

  /// Confirmed by the server.
  sent,

  /// Failed for good: it has to be recorded again (or retried).
  failed,
}

/// The last-set video of one exercise: its [state] and, when there is one,
/// the upload [row] of the local queue it was read from.
class LastSetVideoStatus {
  const LastSetVideoStatus(this.state, [this.row]);

  final LastSetVideoState state;
  final Map<String, dynamic>? row;

  String? get feedbackId => row?['id'] as String?;
}

/// Reads the last-set video of [trainingExerciseId] in execution [sessionId]
/// from the owned upload [queue] (no network). A replaced, discarded or
/// discarding upload does not count; with several uploads the latest one
/// (queue order) decides.
LastSetVideoStatus lastSetVideoStatus({
  required Iterable<Map<String, dynamic>> queue,
  required String trainingId,
  required String date,
  required String? sessionId,
  required String trainingExerciseId,
}) {
  Map<String, dynamic>? row;
  for (final item in queue) {
    if (item['training_id'] != trainingId ||
        item['assignment_date'] != date ||
        item['training_session_id'] != sessionId ||
        item['training_exercise_id'] != trainingExerciseId ||
        item['feedback_kind'] != 'LAST_SET' ||
        item['media_type'] != 'VIDEO' ||
        item['discard_requested'] == true ||
        item['replaced_by'] != null) {
      continue;
    }
    row = item;
  }
  if (row == null) return const LastSetVideoStatus(LastSetVideoState.missing);
  final state = switch (row['status']) {
    'completed' => LastSetVideoState.sent,
    'failed' => LastSetVideoState.failed,
    'uploading' || 'processing' => LastSetVideoState.sending,
    _ => LastSetVideoState.pending,
  };
  return LastSetVideoStatus(state, row);
}

/// Plain reason of a failed upload [row], for «No se pudo enviar el vídeo:
/// …»: a lost file, a size or format the server refuses, a local
/// preparation problem, or any other refusal.
String lastSetVideoReason(AppLocalizations l10n, Map<String, dynamic> row) {
  final error = row['last_error'];
  final status = row['last_http_status'];
  if (error == 'file_missing') return l10n.lastSetVideoReasonFileMissing;
  if (status == 413) return l10n.lastSetVideoReasonTooLarge;
  if (status == 415) return l10n.lastSetVideoReasonUnsupported;
  if (status == null &&
      error is String &&
      (error.startsWith('compression_') ||
          error == 'upload_local_failure' ||
          error.startsWith('PlatformException'))) {
    return l10n.lastSetVideoReasonPreparation;
  }
  return l10n.lastSetVideoReasonRejected;
}

/// Sync state and text of the row line for [status] (FB1); null when there
/// is nothing to say (no video yet on an exercise still to do).
(ExomSyncState, String)? lastSetVideoLine(
  AppLocalizations l10n,
  LastSetVideoStatus status, {
  required bool exerciseCompleted,
}) => switch (status.state) {
  LastSetVideoState.missing =>
    exerciseCompleted
        ? (ExomSyncState.fallida, l10n.lastSetVideoMissing)
        : null,
  LastSetVideoState.pending => (
    ExomSyncState.pendiente,
    l10n.lastSetVideoPending,
  ),
  LastSetVideoState.sending => (
    ExomSyncState.enviando,
    l10n.lastSetVideoSending,
  ),
  LastSetVideoState.sent => (ExomSyncState.confirmada, l10n.lastSetVideoSent),
  LastSetVideoState.failed => (
    ExomSyncState.fallida,
    l10n.lastSetVideoFailed(lastSetVideoReason(l10n, status.row!)),
  ),
};
