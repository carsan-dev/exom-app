import 'dart:io';

import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/presentation/widgets/last_set_video_sheet.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// «Volver a grabar» (FB1): asks for a new last-set video for the failed
/// upload [feedbackId] with the same sheet as after the last set (record or
/// choose from the gallery) and replaces it in the queue
/// ([FeedbackUploadQueueService.replaceFailed]). Returns the new upload id,
/// or null when nothing was replaced: the sheet was closed, the account or
/// its session changed meanwhile ([expectedSession]), or saving failed (a
/// SnackBar says so; the old video stays as it was).
Future<String?> rerecordLastSetVideo(
  BuildContext context, {
  required String feedbackId,
  required String exerciseName,
  required String? expectedSession,
}) async {
  final storage = sl<LocalStorage>();
  bool current() =>
      context.mounted &&
      expectedSession != null &&
      storage.sessionStamp == expectedSession;
  if (!current() || !sl.isRegistered<FeedbackUploadQueueService>()) {
    return null;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failedText = AppLocalizations.of(context).lastSetVideoRerecordFailed;
  final choice = await showExomSheet<LastSetVideoChoice>(
    context: context,
    builder: (_) => LastSetVideoSheet(
      kicker: exerciseName,
      pickVideo: (source) => _pickVideo(context, source),
    ),
  );
  if (choice == null || !current()) return null;
  final notes = choice.notes.trim();
  try {
    return await sl<FeedbackUploadQueueService>().replaceFailed(
      feedbackId,
      file: choice.file,
      contentType: lastSetVideoContentType(choice.file),
      notes: notes.isEmpty ? null : notes,
      expectedSession: expectedSession,
    );
  } on LocalSessionChanged {
    return null;
  } catch (_) {
    if (current()) {
      messenger?.showSnackBar(SnackBar(content: Text(failedText)));
    }
    return null;
  }
}

/// Content type sent for a last-set video file, from its extension.
String lastSetVideoContentType(File file) {
  return switch (file.path.split('.').last.toLowerCase()) {
    'mov' => 'video/quicktime',
    'm4v' => 'video/x-m4v',
    'webm' => 'video/webm',
    _ => 'video/mp4',
  };
}

/// Same picker and error recovery as the active exercise's last-set video.
Future<File?> _pickVideo(BuildContext context, ImageSource initialSource) async {
  var source = initialSource;
  while (context.mounted) {
    try {
      final picked = await ImagePicker().pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      return picked == null ? null : File(picked.path);
    } on Object catch (error) {
      if (!context.mounted) return null;
      final action = await showMediaPickerErrorDialog(
        context,
        error,
        canUseGallery: source != ImageSource.gallery,
      );
      if (action == MediaPickerRecoveryAction.gallery) {
        source = ImageSource.gallery;
      } else if (action != MediaPickerRecoveryAction.retry) {
        return null;
      }
    }
  }
  return null;
}
