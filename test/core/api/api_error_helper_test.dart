import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  String map(AppLocalizations l10n, int status, String message) =>
      localizedApiErrorFor(l10n, ApiException(statusCode: status, message: message));

  test('preserves existing status mappings', () {
    expect(map(es, 0, 'x'), es.errorNetwork);
    expect(map(es, 401, 'x'), es.errorSessionExpired);
    expect(map(es, 403, 'x'), es.errorForbidden);
    expect(map(es, 404, 'x'), es.errorNotFound);
    expect(map(es, 423, 'x'), es.errorAccountLocked);
    expect(map(es, 503, 'x'), es.errorServer);
  });

  test('maps 400/422/409/429 and unknown without exposing raw text', () {
    const raw = 'Raw server text: must not be shown';
    expect(map(es, 400, raw), es.errorBadRequest);
    expect(map(es, 422, raw), es.errorBadRequest);
    expect(map(es, 409, raw), es.errorConflict);
    expect(map(es, 429, raw), es.errorRateLimited);
    expect(map(es, 418, raw), es.errorRequestFailed);
    expect(map(en, 418, ''), en.errorRequestFailed);
  });

  test('maps every sync and media code in both locales', () {
    const codes = [
      'progress_conflict_review_required',
      'PROGRESS_VERSION_CONFLICT',
      'PROGRESS_OPERATION_CONFLICT',
      'PROGRESS_HISTORY_AMBIGUOUS',
      'progress_receipt_missing',
      'Bad state: progress_receipt_missing',
      'feedback_discarded',
      'sync_request_failed',
      'sync_failed',
      'unknown',
      'compression_cancelled',
      'compression_invalid_input',
      'compression_timeout',
      'compression_busy',
      'compression_failed',
      'UPLOAD_EXPIRED',
      'UPLOAD_OBJECT_MISSING',
      'upload_session_changed',
      'UPLOAD_OPERATION_CONFLICT',
      'upload_operation_conflict_exhausted',
      'ApiException(409): PROGRESS_VERSION_CONFLICT',
    ];
    for (final code in codes) {
      for (final l10n in [es, en]) {
        final text = localizedErrorCode(l10n, code);
        expect(text, isNotNull, reason: code);
        expect(text, isNot(contains('_')), reason: code);
        expect(text, isNot(equals(code)));
      }
      expect(map(es, 409, code), localizedErrorCode(es, code));
    }
  });

  test('localizedErrorText never returns unknown raw text', () {
    expect(
      localizedErrorText(es, 'FirebaseException: boom', fallback: 'fallback'),
      'fallback',
    );
    expect(localizedErrorText(es, null, fallback: 'fallback'), 'fallback');
  });
}
