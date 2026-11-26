import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// One titled text of the technique sheet (technique, common mistakes,
/// explanation).
typedef TechniqueSection = ({String title, String text});

/// Opens «Ver técnica» (L5-F4, sketch `f-resto.html`, frames `f4-video` and
/// `f4-texto`): an [ExerciseTechniqueSheet] in an EXOM sheet (square, 1 px
/// outline, handle) with «Cerrar» pinned in the sheet footer, so the content
/// scrolls under it when it does not fit (320 dp at 160 %).
Future<void> showExerciseTechniqueSheet(
  BuildContext context, {
  required String exerciseName,
  required bool hasVideo,
  required String? videoUrl,
  required String? thumbnailUrl,
  required VoidCallback onOpenVideo,
  required List<TechniqueSection> sections,
}) {
  return showExomSheet<void>(
    context: context,
    builder: (_) => ExerciseTechniqueSheet(
      exerciseName: exerciseName,
      hasVideo: hasVideo,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      onOpenVideo: onOpenVideo,
      sections: sections,
    ),
    actions: [
      Builder(
        builder: (sheetContext) => ExomSecondaryButton(
          key: const Key('technique-sheet-close'),
          label: AppLocalizations.of(sheetContext).activeExerciseTechniqueClose,
          onPressed: () => Navigator.of(sheetContext).maybePop(),
        ),
      ),
    ],
  );
}

/// Content of «Ver técnica» (principle 3: the video is folded behind this
/// sheet instead of sitting on top of the active exercise). The title and the
/// exercise name, then the video preview at full bleed when the exercise has
/// one (square play button of 56 and «Vídeo» under it), then the texts that
/// exist, numbered 01–03 in the order they appear. Without a video the sheet
/// starts with the texts. «Cerrar» is not part of the content: it is pinned
/// by [showExerciseTechniqueSheet].
class ExerciseTechniqueSheet extends StatelessWidget {
  const ExerciseTechniqueSheet({
    super.key,
    required this.exerciseName,
    required this.hasVideo,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.onOpenVideo,
    required this.sections,
  });

  final String exerciseName;
  final bool hasVideo;
  final String? videoUrl;
  final String? thumbnailUrl;
  final VoidCallback onOpenVideo;
  final List<TechniqueSection> sections;

  /// Side padding of the sheet body (`.sheet-body`); the video ignores it.
  static const double _side = 20;

  /// Gap between the blocks of the body (`.sheet-body` gap).
  static const double _gap = 18;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    const side = EdgeInsets.symmetric(horizontal: _side);
    final blocks = <Widget>[
      Padding(
        padding: side,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              label: l10n.technique,
              excludeSemantics: true,
              child: Text(
                l10n.technique.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTheme.displayFontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 0.95,
                  letterSpacing: -0.44,
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              exerciseName,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 14,
                height: 1.4,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
      if (hasVideo)
        _TechniqueVideo(
          thumbnailUrl: thumbnailUrl,
          onOpenVideo: onOpenVideo,
        ),
      for (var i = 0; i < sections.length; i++)
        Padding(
          padding: side,
          child: _TechniqueText(number: i + 1, section: sections[i]),
        ),
    ];
    return Padding(
      key: const Key('technique-sheet-body'),
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: _gap),
            blocks[i],
          ],
        ],
      ),
    );
  }
}

/// Video preview at full bleed (`.f-bleed .x-photo`, 200 high): the thumbnail
/// (or the raised surface without one) with a square play button of 56 in the
/// middle, and «Vídeo» under it. The whole preview opens the video, as
/// before; the caption is read as the button's label.
class _TechniqueVideo extends StatelessWidget {
  const _TechniqueVideo({required this.thumbnailUrl, required this.onOpenVideo});

  final String? thumbnailUrl;
  final VoidCallback onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final url = thumbnailUrl?.trim();
    final placeholder = ColoredBox(color: palette.surfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: l10n.video,
          excludeSemantics: true,
          child: SizedBox(
            key: const Key('technique-sheet-video'),
            height: 200,
            child: Material(
              color: palette.surfaceVariant,
              child: InkWell(
                onTap: onOpenVideo,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url != null && url.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        memCacheWidth: PerformanceProfile.imageCacheWidth(
                          context,
                          MediaQuery.sizeOf(context).width,
                        ),
                        placeholder: (_, _) => placeholder,
                        errorWidget: (_, _, _) => placeholder,
                      ),
                    Center(
                      child: Container(
                        key: const Key('technique-sheet-play'),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: palette.background,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Icon(
                          ExomIcons.play,
                          size: 24,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ExerciseTechniqueSheet._side,
          ),
          child: ExcludeSemantics(
            child: Text(
              l10n.video,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 14,
                height: 1.4,
                color: palette.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One numbered text (`.x-q-l` with its `.x-no`, then the body in the
/// secondary colour).
class _TechniqueText extends StatelessWidget {
  const _TechniqueText({required this.number, required this.section});

  final int number;
  final TechniqueSection section;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // `.x-q-l .x-no`: the index numeral at 1.125 em (18).
            Text(
              ExomIndexNumber.format(number),
              style: ExomIndexNumber.style(
                palette.data,
              ).copyWith(fontSize: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                section.title,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          section.text,
          style: TextStyle(
            fontFamily: AppTheme.bodyFontFamily,
            fontSize: 16,
            height: 1.45,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
