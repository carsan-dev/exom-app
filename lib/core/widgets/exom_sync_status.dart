import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Sync state of a locally saved record (plan §6 "Semántica de estados").
enum ExomSyncState {
  /// Saved on this phone, not yet queued for the server.
  guardadaEnMovil,

  /// Waiting to be synced (offline or queued).
  pendiente,

  /// Being sent right now.
  enviando,

  /// Confirmed by the server.
  confirmada,

  /// The sync failed; the data is still on the phone.
  fallida,
}

/// One-line sync status: icon + localized text, never colour alone.
///
/// Colours follow the token semantics: saved on the phone is `muted` with a
/// device icon (sketch «Subidas»), sending is `muted` with an upload icon
/// (so the five states differ by icon and text, not only by colour), pending
/// is the `pending` amber with a clock, confirmed is `text` with a check
/// (**never lime**), and failed is `error` with an alert icon. [label] overrides the default text
/// (e.g. "Enviando 62 %") while keeping the icon and colour. The semantics
/// label is the visible text; the icon is decorative.
class ExomSyncStatus extends StatelessWidget {
  const ExomSyncStatus({super.key, required this.state, this.label});

  final ExomSyncState state;
  final String? label;

  static String defaultLabel(AppLocalizations l10n, ExomSyncState state) {
    return switch (state) {
      ExomSyncState.guardadaEnMovil => l10n.syncStatusSavedOnDevice,
      ExomSyncState.pendiente => l10n.syncStatusPending,
      ExomSyncState.enviando => l10n.syncStatusSending,
      ExomSyncState.confirmada => l10n.syncStatusConfirmed,
      ExomSyncState.fallida => l10n.syncStatusFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final (IconData icon, Color colour) = switch (state) {
      ExomSyncState.guardadaEnMovil => (
        Icons.smartphone_outlined,
        palette.textSecondary,
      ),
      ExomSyncState.pendiente => (Icons.schedule, semantic.warning),
      ExomSyncState.enviando => (
        Icons.cloud_upload_outlined,
        palette.textSecondary,
      ),
      ExomSyncState.confirmada => (Icons.check, palette.textPrimary),
      ExomSyncState.fallida => (Icons.error_outline, palette.error),
    };
    final text = label ?? defaultLabel(AppLocalizations.of(context), state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ExcludeSemantics(child: Icon(icon, size: 18, color: colour)),
        ),
        const SizedBox(width: 6),
        Flexible(
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
    );
  }
}
