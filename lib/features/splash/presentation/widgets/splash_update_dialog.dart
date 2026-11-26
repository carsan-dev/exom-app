import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Update notice of the splash (L5-D3, d-acceso.html «Arranque y
/// actualización»): still a dialog, radius 4, with a single lime action
/// («Actualizar»). A recommended update adds «Continuar» as a quiet link; a
/// required one has no way out.
///
/// If the store cannot be opened, or does not answer within
/// [SplashUpdateDialog.storeTimeout], the error shows inside the dialog,
/// above the button, and «Actualizar» retries (it used to be a SnackBar
/// behind the dialog). A recommended update closes with `true` once the store
/// opens or on «Continuar», which stays usable while the store is pending; a
/// required one never closes.
Future<bool?> showSplashUpdateDialog(
  BuildContext context, {
  required String title,
  required String message,
  required bool blocking,
  required Future<bool> Function() openStore,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: !blocking,
    builder: (dialogContext) => PopScope(
      canPop: !blocking,
      child: SplashUpdateDialog(
        title: title,
        message: message,
        blocking: blocking,
        openStore: openStore,
      ),
    ),
  );
}

class SplashUpdateDialog extends StatefulWidget {
  const SplashUpdateDialog({
    super.key,
    required this.title,
    required this.message,
    required this.blocking,
    required this.openStore,
  });

  final String title;
  final String message;
  final bool blocking;
  final Future<bool> Function() openStore;

  /// How long «Actualizar» waits for the store before showing the error and
  /// enabling the actions again. A late answer is ignored.
  static const storeTimeout = Duration(seconds: 5);

  @override
  State<SplashUpdateDialog> createState() => _SplashUpdateDialogState();
}

class _SplashUpdateDialogState extends State<SplashUpdateDialog> {
  bool _busy = false;
  bool _storeFailed = false;

  Future<void> _update() async {
    if (_busy) return;
    setState(() => _busy = true);
    var opened = false;
    try {
      opened = await widget.openStore().timeout(
        SplashUpdateDialog.storeTimeout,
      );
    } catch (error) {
      debugPrint('[SPLASH] Store not opened: $error');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _storeFailed = !opened;
    });
    if (opened && !widget.blocking) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final width = (MediaQuery.sizeOf(context).width - 2 * 40 - 2 * 24).clamp(
      200.0,
      400.0,
    );
    return AlertDialog(
      scrollable: true,
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ExomRadius.control),
        side: BorderSide(color: palette.borderSoft, width: ExomRule.hairline),
      ),
      titleTextStyle: ExomType.section.copyWith(color: palette.textPrimary),
      contentTextStyle: TextStyle(
        fontFamily: AppTheme.bodyFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: palette.textSecondary,
      ),
      title: Text(widget.title),
      // A fixed width: AlertDialog sizes its content by intrinsic width and
      // the full-width primary button has none.
      content: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            if (_storeFailed) ...[
              const SizedBox(height: 16),
              ExomInlineMessage(
                kind: ExomMessageKind.error,
                title: l10n.updateStoreNotOpenedError,
                body: l10n.updateStoreRetryHint,
              ),
            ],
            const SizedBox(height: 24),
            ExomPrimaryButton(
              label: l10n.update,
              trailingIcon: ExomIcons.forward,
              busy: _busy,
              onPressed: _update,
            ),
            if (!widget.blocking) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExomTextLink(
                  label: l10n.continueButton,
                  // Usable while the store is pending: a recommended update
                  // never holds the user.
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
