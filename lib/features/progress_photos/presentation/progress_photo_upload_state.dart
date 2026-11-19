import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Upload state of one progress photo tile (plan §6 "Semántica de estados").
enum ProgressPhotoUploadState {
  /// Staged or queued on this phone, waiting to be sent.
  pending,

  /// Bytes are being sent or the server is processing them.
  synchronizing,

  /// Confirmed by the server and the local copy is already gone.
  confirmed,

  /// Confirmed by the server; the local copy is still being removed.
  cleanupPending,

  /// The upload failed; the photo is still on this phone.
  failed,

  /// The replacement went stale (the active photo changed): needs a review.
  conflict,
}

/// State of a tile derived only from the queue item the page already reads
/// (no network call, nothing written). `null` when the tile has no queue item.
///
/// A stale replacement (`STALE` or HTTP 409 in `last_error`) is a conflict
/// whatever the queue status says, as before the redesign.
ProgressPhotoUploadState? progressPhotoUploadState(Map<String, dynamic>? item) {
  if (item == null) return null;
  final error = item['last_error'] as String? ?? '';
  if (error.contains('STALE') || error.contains('409')) {
    return ProgressPhotoUploadState.conflict;
  }
  return switch (item['status']) {
    'processing' => ProgressPhotoUploadState.synchronizing,
    'completed' =>
      item['cleanup_pending'] == true
          ? ProgressPhotoUploadState.cleanupPending
          : ProgressPhotoUploadState.confirmed,
    'failed' => ProgressPhotoUploadState.failed,
    _ => ProgressPhotoUploadState.pending,
  };
}

/// Localized text of [state]. The six texts are different from each other.
String progressPhotoUploadLabel(
  AppLocalizations l10n,
  ProgressPhotoUploadState state,
) => switch (state) {
  ProgressPhotoUploadState.pending => l10n.progressPhotosPending,
  ProgressPhotoUploadState.synchronizing => l10n.progressPhotosSynchronizing,
  ProgressPhotoUploadState.confirmed => l10n.progressPhotosConfirmed,
  ProgressPhotoUploadState.cleanupPending =>
    l10n.progressPhotosConfirmedCleanup,
  ProgressPhotoUploadState.failed => l10n.progressPhotosFailed,
  ProgressPhotoUploadState.conflict => l10n.progressPhotosConflict,
};

/// One status per tile: icon + text, never colour alone. Every state has its
/// own icon (clock, upload cloud, check, broom, alert, sync problem) and its
/// own text; colour only reinforces the token semantics: pending is the
/// `pending` amber, confirmed is `text` (**never lime**), failed and conflict
/// are `error`, the rest `muted`. The text is the accessible label of the
/// merged node; the icon is decorative.
class ProgressPhotoUploadStatus extends StatelessWidget {
  const ProgressPhotoUploadStatus({super.key, required this.state});

  final ProgressPhotoUploadState state;

  static IconData iconOf(ProgressPhotoUploadState state) => switch (state) {
    ProgressPhotoUploadState.pending => Icons.schedule,
    ProgressPhotoUploadState.synchronizing => Icons.cloud_upload_outlined,
    ProgressPhotoUploadState.confirmed => Icons.check,
    ProgressPhotoUploadState.cleanupPending => Icons.cleaning_services_outlined,
    ProgressPhotoUploadState.failed => Icons.error_outline,
    ProgressPhotoUploadState.conflict => Icons.sync_problem,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final colour = switch (state) {
      ProgressPhotoUploadState.pending => semantic.warning,
      ProgressPhotoUploadState.synchronizing => palette.textSecondary,
      ProgressPhotoUploadState.confirmed => palette.textPrimary,
      ProgressPhotoUploadState.cleanupPending => palette.textSecondary,
      ProgressPhotoUploadState.failed => palette.error,
      ProgressPhotoUploadState.conflict => palette.error,
    };
    final text = progressPhotoUploadLabel(AppLocalizations.of(context), state);
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(iconOf(state), size: 18, color: colour),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
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
      ),
    );
  }
}
