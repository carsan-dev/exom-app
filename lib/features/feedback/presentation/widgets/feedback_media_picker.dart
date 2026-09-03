import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';

class FeedbackMediaPicker extends StatelessWidget {
  final File? selectedFile;
  final String mediaType;
  final bool isUploading;
  final ValueChanged<String> onMediaTypeChanged;
  final ValueChanged<File> onFileSelected;
  final VoidCallback? onClear;
  final bool videoOnly;

  const FeedbackMediaPicker({
    super.key,
    required this.selectedFile,
    required this.mediaType,
    required this.isUploading,
    required this.onMediaTypeChanged,
    required this.onFileSelected,
    this.onClear,
    this.videoOnly = false,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source);
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
        await _pickImage(context, source);
      } else if (action == MediaPickerRecoveryAction.gallery) {
        await _pickImage(context, ImageSource.gallery);
      }
    }
  }

  Future<void> _pickVideo(BuildContext context, ImageSource source) async {
    try {
      final picked = await ImagePicker().pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
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
        await _pickVideo(context, source);
      } else if (action == MediaPickerRecoveryAction.gallery) {
        await _pickVideo(context, ImageSource.gallery);
      }
    }
  }

  void _showVideoSourceSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(l10n.feedbackFromCamera),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickVideo(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(l10n.feedbackFromGallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickVideo(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: GlassDecoration.elevated(borderRadius: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: palette.primary,
                ),
                title: Text(
                  l10n.feedbackFromCamera,
                  style: TextStyle(color: palette.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: palette.primary,
                ),
                title: Text(
                  l10n.feedbackFromGallery,
                  style: TextStyle(color: palette.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    if (isUploading) {
      return Container(
        height: 56,
        decoration: GlassDecoration.card(borderRadius: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.feedbackUploading,
              style: TextStyle(color: palette.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (selectedFile != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: GlassDecoration.accentCard(
          palette.primary,
          borderRadius: 14,
        ),
        child: Row(
          children: [
            Icon(
              mediaType == 'VIDEO'
                  ? Icons.videocam_rounded
                  : Icons.image_rounded,
              color: palette.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedFile!.path.split('/').last,
                style: TextStyle(color: palette.textPrimary, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, color: palette.textDisabled, size: 18),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!videoOnly) ...[
          Row(
            children: [
              _TypeChip(
                label: l10n.feedbackSelectImage,
                icon: Icons.image_outlined,
                selected: mediaType == 'IMAGE',
                onTap: () => onMediaTypeChanged('IMAGE'),
                palette: palette,
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: l10n.feedbackSelectVideo,
                icon: Icons.videocam_outlined,
                selected: mediaType == 'VIDEO',
                onTap: () => onMediaTypeChanged('VIDEO'),
                palette: palette,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: () {
            if (mediaType == 'VIDEO') {
              _showVideoSourceSheet(context);
            } else {
              _showImageSourceSheet(context);
            }
          },
          child: Container(
            height: 56,
            decoration: GlassDecoration.elevated(borderRadius: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  mediaType == 'VIDEO'
                      ? Icons.video_call_outlined
                      : Icons.add_photo_alternate_outlined,
                  color: palette.textDisabled,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  mediaType == 'VIDEO'
                      ? l10n.feedbackSelectVideo
                      : l10n.feedbackSelectImage,
                  style: TextStyle(color: palette.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final dynamic palette;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: selected
            ? GlassDecoration.accentCard(palette.primary, borderRadius: 12)
            : GlassDecoration.card(borderRadius: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? palette.primary : palette.textDisabled,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected ? palette.primary : palette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
