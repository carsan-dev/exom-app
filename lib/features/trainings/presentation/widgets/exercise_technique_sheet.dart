import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_video_preview.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// One titled text of the technique sheet (technique, common mistakes,
/// explanation).
typedef TechniqueSection = ({String title, String text});

/// Content of «Ver técnica» (principle 3: the video is folded behind this
/// sheet instead of sitting on top of the active exercise). Shows the video
/// preview first when the exercise has one, then the exercise texts.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final bodyStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      height: 1.45,
      color: palette.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.technique.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTheme.displayFontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.0,
                letterSpacing: -0.44,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            exerciseName,
            style: bodyStyle.copyWith(fontSize: 14, height: 1.4),
          ),
          if (hasVideo) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ExerciseVideoPreview(
                title: exerciseName,
                videoUrl: videoUrl,
                thumbnailUrl: thumbnailUrl,
                onTap: onOpenVideo,
              ),
            ),
          ],
          for (final section in sections) ...[
            const SizedBox(height: 18),
            Text(
              section.title,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(section.text, style: bodyStyle),
          ],
          const SizedBox(height: 20),
          ExomSecondaryButton(
            label: MaterialLocalizations.of(context).closeButtonLabel,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
