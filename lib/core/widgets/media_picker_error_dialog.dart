import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MediaPickerRecoveryAction { retry, gallery, cancel }

const _appSettingsChannel = MethodChannel('com.exommethod.exom/app_settings');

Future<void> _openAppSettings() async {
  try {
    await _appSettingsChannel.invokeMethod<void>('open');
  } on PlatformException {
    // The retry/gallery actions remain available if settings cannot open.
  } on MissingPluginException {
    // Unsupported desktop/test platform.
  }
}

Future<MediaPickerRecoveryAction> showMediaPickerErrorDialog(
  BuildContext context,
  Object error, {
  required bool canUseGallery,
}) async {
  final l10n = AppLocalizations.of(context);
  final isPermissionError =
      error is PlatformException &&
      (error.code.toLowerCase().contains('denied') ||
          error.code.toLowerCase().contains('permission') ||
          error.code.toLowerCase().contains('access'));
  final isFileError = error is FileSystemException;
  final action = await showDialog<MediaPickerRecoveryAction>(
    context: context,
    builder: (dialogContext) {
      final palette = dialogContext.exomPalette;
      // Skin only (L5 T0.3b): flat dialog with a hairline, display title and
      // 48 dp text-action targets (the filled button keeps the theme height).
      // Text, actions and results are unchanged.
      final textActionStyle = ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size.square(ExomTextLink.minTarget),
        ),
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
        title: Text(
          isPermissionError
              ? l10n.mediaPickerPermissionTitle
              : l10n.mediaPickerErrorTitle,
        ),
        content: Text(
          isPermissionError
              ? l10n.mediaPickerPermissionMessage
              : isFileError
              ? l10n.mediaPickerFileMessage
              : l10n.mediaPickerErrorMessage,
        ),
        actions: [
          if (isPermissionError)
            TextButton(
              style: textActionStyle,
              onPressed: () async {
                await _openAppSettings();
                if (dialogContext.mounted) {
                  Navigator.pop(
                    dialogContext,
                    MediaPickerRecoveryAction.cancel,
                  );
                }
              },
              child: Text(l10n.settings),
            ),
          if (canUseGallery)
            TextButton(
              style: textActionStyle,
              onPressed: () => Navigator.pop(
                dialogContext,
                MediaPickerRecoveryAction.gallery,
              ),
              child: Text(l10n.feedbackFromGallery),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, MediaPickerRecoveryAction.retry),
            child: Text(l10n.retry),
          ),
        ],
      );
    },
  );
  return action ?? MediaPickerRecoveryAction.cancel;
}
