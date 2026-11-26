import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:exom_app/features/trainings/presentation/widgets/local_video_thumbnail.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Picks an image or a video from [source]; null when the user cancels.
typedef FeedbackMediaPick =
    Future<XFile?> Function(ImageSource source, {required bool video});

/// Numbered question of the feedback form (sketch `.x-q`): the index numeral
/// «01», the label in DM Sans 15 / 600 and the answer under it.
class FeedbackQuestion extends StatelessWidget {
  const FeedbackQuestion({
    super.key,
    required this.n,
    required this.label,
    required this.child,
  });

  final int n;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              ExcludeSemantics(child: ExomIndexNumber(n)),
              const SizedBox(width: ExomSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ExomSpacing.md),
        child,
      ],
    );
  }
}

/// Evidence picker of the feedback form (L5-C2, sketch C1 and C1 i).
///
/// For a single exercise it shows two numbered questions: the evidence type
/// (chips, locked while a file is selected or being queued, as before) and
/// the file. With [videoOnly] (circuit) it shows only the file answer.
///
/// «Elegir archivo» opens a straight EXOM sheet ([showExomSheet], D14-2) with
/// the two sources as a numbered index and «Cancelar». Like every EXOM sheet it
/// closes itself when the router location changes; then nothing is picked
/// (CC 11). The picker opens only after the sheet is gone.
class FeedbackMediaPicker extends StatelessWidget {
  final File? selectedFile;
  final String mediaType;
  final bool isUploading;
  final ValueChanged<String> onMediaTypeChanged;
  final ValueChanged<File> onFileSelected;
  final VoidCallback? onClear;
  final bool videoOnly;

  /// Replaces the platform picker (tests).
  final FeedbackMediaPick? pick;

  const FeedbackMediaPicker({
    super.key,
    required this.selectedFile,
    required this.mediaType,
    required this.isUploading,
    required this.onMediaTypeChanged,
    required this.onFileSelected,
    this.onClear,
    this.videoOnly = false,
    this.pick,
  });

  bool get _isVideo => mediaType == 'VIDEO';

  static Future<XFile?> _platformPick(
    ImageSource source, {
    required bool video,
  }) => video
      ? ImagePicker().pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        )
      : ImagePicker().pickImage(source: source);

  Future<void> _pickFrom(
    BuildContext context,
    ImageSource source, {
    required bool video,
  }) async {
    try {
      final picked = await (pick ?? _platformPick)(source, video: video);
      if (picked != null) onFileSelected(File(picked.path));
    } on Object catch (error) {
      if (!context.mounted) return;
      final action = await showMediaPickerErrorDialog(
        context,
        error,
        canUseGallery: source != ImageSource.gallery,
      );
      if (!context.mounted) return;
      if (action == MediaPickerRecoveryAction.retry) {
        await _pickFrom(context, source, video: video);
      } else if (action == MediaPickerRecoveryAction.gallery) {
        await _pickFrom(context, ImageSource.gallery, video: video);
      }
    }
  }

  Future<void> _chooseSource(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final video = _isVideo;
    final source = await showExomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => ExomIndexList(
        items: [
          ExomIndexItem(
            title: l10n.feedbackFromCamera,
            icon: video ? ExomIcons.video : ExomIcons.camera,
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ExomIndexItem(
            title: l10n.feedbackFromGallery,
            icon: video ? ExomIcons.videoLibrary : ExomIcons.gallery,
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (sheetContext) => ExomQuietButton(
            label: l10n.cancel,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ],
    );
    if (source == null || !context.mounted) return;
    await _pickFrom(context, source, video: video);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final file = _FileAnswer(
      selectedFile: selectedFile,
      isVideo: _isVideo,
      isUploading: isUploading,
      onChoose: () => _chooseSource(context),
      onClear: onClear,
    );
    if (videoOnly) return file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FeedbackQuestion(
          n: 1,
          label: l10n.feedbackQuestionType,
          child: ExomChoiceChips<String>(
            options: const ['VIDEO', 'IMAGE'],
            selected: mediaType,
            labelOf: (type) => type == 'VIDEO'
                ? l10n.feedbackSelectVideo
                : l10n.feedbackSelectImage,
            onSelected: selectedFile != null || isUploading
                ? null
                : onMediaTypeChanged,
          ),
        ),
        const SizedBox(height: ExomSpacing.xxl),
        FeedbackQuestion(n: 2, label: l10n.feedbackQuestionFile, child: file),
      ],
    );
  }
}

/// The file answer: «Elegir archivo», the chosen file with «Quitar», or the
/// queueing line while the file is copied into the queue.
class _FileAnswer extends StatelessWidget {
  const _FileAnswer({
    required this.selectedFile,
    required this.isVideo,
    required this.isUploading,
    required this.onChoose,
    required this.onClear,
  });

  final File? selectedFile;
  final bool isVideo;
  final bool isUploading;
  final VoidCallback onChoose;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final secondary = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      height: 1.35,
      color: palette.textSecondary,
    );

    if (isUploading) {
      return Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(width: ExomSpacing.md),
          Expanded(child: Text(l10n.feedbackUploading, style: secondary)),
        ],
      );
    }

    final file = selectedFile;
    if (file != null) {
      return _ChosenFile(
        key: ValueKey<String>(file.path),
        file: file,
        isVideo: isVideo,
        onClear: onClear,
      );
    }

    return ExomSecondaryButton(
      key: const Key('feedback-pick-file'),
      label: l10n.feedbackChooseFile,
      icon: isVideo ? ExomIcons.video : ExomIcons.addPhoto,
      onPressed: onChoose,
    );
  }
}

/// The chosen file (L5-E3d-P1, as «Vídeo preparado»): a 56 dp thumbnail, the
/// kind («Vídeo · 0:12» once the clip's duration is known, «Imagen») and
/// «Quitar». The file name is never shown.
class _ChosenFile extends StatefulWidget {
  const _ChosenFile({
    super.key,
    required this.file,
    required this.isVideo,
    required this.onClear,
  });

  final File file;
  final bool isVideo;
  final VoidCallback? onClear;

  @override
  State<_ChosenFile> createState() => _ChosenFileState();
}

class _ChosenFileState extends State<_ChosenFile> {
  static const Key _thumbnailKey = Key('feedback-file-thumbnail');

  Duration? _duration;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final clear = widget.onClear;
    final kind = widget.isVideo ? l10n.video : l10n.image;
    final duration = widget.isVideo ? _duration : null;
    final time = duration == null ? null : formatClipDuration(duration);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final thumbnail = widget.isVideo
        ? LocalVideoThumbnail(
            key: _thumbnailKey,
            file: widget.file,
            onDuration: (value) {
              if (mounted) setState(() => _duration = value);
            },
          )
        : _ImageThumbnail(
            key: _thumbnailKey,
            file: widget.file,
            cacheWidth: (_ImageThumbnail.size * dpr).ceil(),
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        thumbnail,
        const SizedBox(width: ExomSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: time == null
                    ? kind
                    : l10n.feedbackChosenFileA11y(kind, time),
                excludeSemantics: true,
                child: Text(
                  time == null ? kind : '$kind · $time',
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: palette.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (clear != null)
                ExomTextLink(label: l10n.feedbackRemoveFile, onTap: clear),
            ],
          ),
        ),
      ],
    );
  }
}

/// The 56 dp box of the chosen image: the picture (cover) with the outline of
/// the video thumbnail, or [ExomIcons.image] in the same box if it cannot be
/// decoded. Decorative: excluded from semantics.
class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    super.key,
    required this.file,
    required this.cacheWidth,
  });

  static const double size = 56;

  final File file;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: palette.borderSoft),
          borderRadius: BorderRadius.circular(2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(ExomIcons.image, size: 24, color: palette.textPrimary),
          ),
        ),
      ),
    );
  }
}
