import 'dart:io';

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
    builder: (dialogContext) => AlertDialog(
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
            onPressed: () async {
              await _openAppSettings();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, MediaPickerRecoveryAction.cancel);
              }
            },
            child: Text(l10n.settings),
          ),
        if (canUseGallery)
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, MediaPickerRecoveryAction.gallery),
            child: Text(l10n.feedbackFromGallery),
          ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext, MediaPickerRecoveryAction.retry),
          child: Text(l10n.retry),
        ),
      ],
    ),
  );
  return action ?? MediaPickerRecoveryAction.cancel;
}
