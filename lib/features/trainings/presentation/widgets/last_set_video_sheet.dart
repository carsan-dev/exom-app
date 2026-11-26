import 'dart:io';
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// What «Usar vídeo» returns: the chosen file and the comment as typed (the
/// caller trims it). A dismissed or cancelled sheet returns null.
typedef LastSetVideoChoice = ({File file, String notes});

/// Content of the last-set video sheet (L5-D23 ii-iii, sketch frames
/// `f-hoja-ult` and `f-hoja-vid`), shown with `showExomSheet` after the last
/// set is saved. One sheet, two states:
///
/// * **Source**: «Adjunta el vídeo de tu última serie», «Grabar ahora» as the
///   only lime action and «Elegir de la galería» as a text link.
/// * **Chosen**: «Vídeo preparado» with the set, «Cambiar» (back to the
///   source, nothing queued), the optional comment and «Usar vídeo».
///
/// «Cancelar» (L5-D43) closes it with null in both states, like the scrim,
/// drag or back. The sheet never queues anything: it only returns the
/// choice. [pickVideo] runs the picker (and its error recovery, which can
/// fall back to the gallery); while it runs the actions are disabled so the
/// video is never asked twice.
class LastSetVideoSheet extends StatefulWidget {
  const LastSetVideoSheet({
    super.key,
    required this.kicker,
    required this.pickVideo,
    this.setLabel,
  });

  /// «Sentadilla búlgara · serie 4».
  final String kicker;

  /// Picks a video from [ImageSource]; null when nothing was picked.
  final Future<File?> Function(ImageSource source) pickVideo;

  /// «Serie 4 · 8 × 62,5 kg» under «Vídeo preparado»; null hides it.
  final String? setLabel;

  @override
  State<LastSetVideoSheet> createState() => _LastSetVideoSheetState();
}

class _LastSetVideoSheetState extends State<LastSetVideoSheet> {
  final _notes = TextEditingController();
  File? _file;
  bool _picking = false;
  bool _done = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking || _done) return;
    setState(() => _picking = true);
    File? picked;
    try {
      picked = await widget.pickVideo(source);
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
          if (picked != null) _file = picked;
        });
      }
    }
  }

  void _change() {
    if (_picking || _done) return;
    setState(() => _file = null);
  }

  void _use() {
    final file = _file;
    if (file == null || _picking || _done) return;
    setState(() => _done = true);
    Navigator.of(context).pop<LastSetVideoChoice>((
      file: file,
      notes: _notes.text,
    ));
  }

  void _cancel() {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final media = MediaQuery.of(context);
    // Same frame budget as the set sheet: the content scrolls and the
    // actions stay pinned under it (see `SetPerformanceSheet`).
    final bottomSafe = MediaQueryData.fromView(View.of(context)).padding.bottom;
    final maxHeight = math.max(
      0.0,
      (media.size.height - media.padding.top - media.viewInsets.bottom) * 0.9 -
          16 -
          bottomSafe -
          1,
    );
    final chosen = _file != null;
    final busy = _picking || _done;
    final mutedStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      height: 1.4,
      color: palette.textSecondary,
    );
    final labelStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: palette.textPrimary,
    );
    final title = chosen ? l10n.videoReadyTitle : l10n.attachLastSetVideo;
    final setLabel = widget.setLabel;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExomKicker(widget.kicker, icon: ExomIcons.camera),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            label: title,
            excludeSemantics: true,
            child: Text(
              title.toUpperCase(),
              style: ExomType.headline2Section.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
          if (!chosen) ...[
            const SizedBox(height: 6),
            Text(l10n.lastSetVideoRequiredDescription, style: mutedStyle),
          ],
          if (chosen) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // No thumbnail nor duration: the app has neither (D15).
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.borderSoft),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    ExomIcons.video,
                    size: 24,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (setLabel != null) Text(setLabel, style: labelStyle),
                      Semantics(
                        label: l10n.changeVideoA11y,
                        button: true,
                        link: true,
                        onTap: busy ? null : _change,
                        excludeSemantics: true,
                        child: ExomTextLink(
                          key: const Key('last-set-video-change'),
                          label: l10n.changeVideo,
                          onTap: busy ? null : _change,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.optionalComment, style: labelStyle),
            const SizedBox(height: 6),
            TextField(
              key: const Key('last-set-video-comment'),
              controller: _notes,
              enabled: !_done,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 16,
                color: palette.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );

    final actions = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!chosen) ...[
              ExomPrimaryButton(
                key: const Key('last-set-video-record'),
                label: l10n.recordNow,
                trailingIcon: ExomIcons.camera,
                busy: _picking,
                onPressed: busy ? null : () => _pick(ImageSource.camera),
              ),
              const SizedBox(height: 4),
              Center(
                child: ExomTextLink(
                  key: const Key('last-set-video-gallery'),
                  label: l10n.chooseFromGallery,
                  onTap: busy ? null : () => _pick(ImageSource.gallery),
                ),
              ),
            ] else
              ExomPrimaryButton(
                key: const Key('last-set-video-use'),
                label: l10n.useVideo,
                trailingIcon: ExomIcons.check,
                busy: _done,
                onPressed: busy ? null : _use,
              ),
            Center(
              child: ExomQuietButton(
                key: const Key('last-set-video-cancel'),
                label: l10n.cancel,
                onPressed: _done ? null : _cancel,
              ),
            ),
          ],
        ),
      ),
    );

    return KeyedSubtree(
      key: const Key('last-set-video-sheet'),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: SingleChildScrollView(child: content)),
            actions,
          ],
        ),
      ),
    );
  }
}
