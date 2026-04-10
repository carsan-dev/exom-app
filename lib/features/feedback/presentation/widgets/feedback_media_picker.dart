import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class FeedbackMediaPicker extends StatelessWidget {
  final File? selectedFile;
  final String mediaType;
  final bool isUploading;
  final ValueChanged<String> onMediaTypeChanged;
  final ValueChanged<File> onFileSelected;
  final VoidCallback? onClear;

  const FeedbackMediaPicker({
    super.key,
    required this.selectedFile,
    required this.mediaType,
    required this.isUploading,
    required this.onMediaTypeChanged,
    required this.onFileSelected,
    this.onClear,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked != null) {
      onFileSelected(File(picked.path));
    }
  }

  Future<void> _pickVideo(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked != null) {
      onFileSelected(File(picked.path));
    }
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
        GestureDetector(
          onTap: () {
            if (mediaType == 'VIDEO') {
              _pickVideo(context);
            } else {
              _showImageSourceSheet(context);
            }
          },
          child: Container(
            height: 56,
            decoration: GlassDecoration.card(borderRadius: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  mediaType == 'VIDEO'
                      ? Icons.video_library_outlined
                      : Icons.add_photo_alternate_outlined,
                  color: palette.textDisabled,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  mediaType == 'VIDEO'
                      ? l10n.feedbackFromGallery
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
