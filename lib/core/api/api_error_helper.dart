import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'api_client.dart';

/// Returns a localized error message for the given [ApiException].
/// Call this from widget build methods or BLoC listeners when displaying errors.
String localizedApiError(BuildContext context, ApiException e) {
  final l10n = AppLocalizations.of(context)!;
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
      return e.message;
  }
}
