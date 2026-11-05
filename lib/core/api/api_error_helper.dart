import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'api_client.dart';

/// Returns a localized error message for the given [ApiException].
/// Call this from widget build methods or BLoC listeners when displaying errors.
///
/// Raw backend messages are never shown: known sync/upload codes carried in
/// the message are mapped, everything else falls back to a generic message.
String localizedApiError(BuildContext context, ApiException e) {
  return localizedApiErrorFor(AppLocalizations.of(context), e);
}

/// Same as [localizedApiError] but without a [BuildContext].
String localizedApiErrorFor(AppLocalizations l10n, ApiException e) {
  switch (e.statusCode) {
    case 0:
      return l10n.errorNetwork;
    case 401:
      return l10n.errorSessionExpired;
    case 403:
      return l10n.errorForbidden;
    case 404:
      return l10n.errorNotFound;
    case 423:
      return l10n.errorAccountLocked;
    default:
      if (e.statusCode >= 500) return l10n.errorServer;
      final codeMessage = localizedErrorCode(l10n, e.message);
      if (codeMessage != null) return codeMessage;
      switch (e.statusCode) {
        case 400:
        case 422:
          return l10n.errorBadRequest;
        case 409:
          return l10n.errorConflict;
        case 429:
          return l10n.errorRateLimited;
        default:
          return l10n.errorRequestFailed;
      }
  }
}

/// Maps a known technical error code (sync, media or upload) to a localized
/// message. Returns null when [raw] is not a known code. The stored/wire
/// value is never altered; this only affects what is displayed.
String? localizedErrorCode(AppLocalizations l10n, String? raw) {
  if (raw == null) return null;
  var code = raw.trim();
  code = code.replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), '');
  for (final prefix in const ['Bad state: ', 'Exception: ']) {
    if (code.startsWith(prefix)) {
      code = code.substring(prefix.length);
    }
  }
  switch (code) {
    case 'progress_conflict_review_required':
      return l10n.errorSyncConflictReview;
    case 'PROGRESS_VERSION_CONFLICT':
    case 'PROGRESS_OPERATION_CONFLICT':
      return l10n.errorSyncVersionConflict;
    case 'PROGRESS_HISTORY_AMBIGUOUS':
      return l10n.errorSyncHistoryAmbiguous;
    case 'progress_receipt_missing':
      return l10n.errorSyncReceiptMissing;
    case 'feedback_discarded':
      return l10n.errorFeedbackDiscarded;
    case 'sync_request_failed':
    case 'sync_failed':
    case 'unknown':
      return l10n.errorSyncFailed;
    case 'compression_cancelled':
      return l10n.errorCompressionCancelled;
    case 'compression_invalid_input':
      return l10n.errorCompressionInvalidInput;
    case 'compression_timeout':
      return l10n.errorCompressionTimeout;
    case 'compression_busy':
      return l10n.errorCompressionBusy;
    case 'compression_failed':
      return l10n.errorCompressionFailed;
    case 'UPLOAD_EXPIRED':
      return l10n.errorUploadExpired;
    case 'UPLOAD_OBJECT_MISSING':
      return l10n.errorUploadObjectMissing;
    case 'upload_session_changed':
      return l10n.errorUploadSessionChanged;
    case 'UPLOAD_OPERATION_CONFLICT':
    case 'upload_operation_conflict_exhausted':
      return l10n.errorUploadOperationConflict;
    default:
      return null;
  }
}

/// Localizes a plain error string held in a BLoC state. A known code is
/// mapped; any other raw text is replaced by [fallback] so technical or
/// server-authored messages never reach the UI.
String localizedErrorText(
  AppLocalizations l10n,
  String? raw, {
  required String fallback,
}) {
  return localizedErrorCode(l10n, raw) ?? fallback;
}

/// [BuildContext] flavour of [localizedErrorText]; [fallback] picks the
/// screen-specific message from the localizations.
String localizedErrorTextOf(
  BuildContext context,
  String? raw, {
  required String Function(AppLocalizations l10n) fallback,
}) {
  final l10n = AppLocalizations.of(context);
  return localizedErrorText(l10n, raw, fallback: fallback(l10n));
}
