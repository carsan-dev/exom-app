import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class ExerciseVideoPreview extends StatelessWidget {
  final String title;
  final String? videoUrl;
  final String? thumbnailUrl;
  final VoidCallback? onTap;

  const ExerciseVideoPreview({
    super.key,
    required this.title,
    this.videoUrl,
    this.thumbnailUrl,
    this.onTap,
  });

  bool get _hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final canOpenVideo = _hasVideo && onTap != null;
    final thumbnailUrl = this.thumbnailUrl?.trim();
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canOpenVideo ? onTap : null,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: GlassDecoration.card(borderRadius: 28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: hasThumbnail
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: PerformanceProfile.imageCacheWidth(
                          context,
                          MediaQuery.sizeOf(context).width,
                        ),
                        placeholder: (context, imageUrl) =>
                            Container(color: palette.surfaceVariant),
                        errorWidget: (context, imageUrl, error) =>
                            _PreviewPlaceholder(
                              title: title,
                              description: l10n.activeExerciseNoVideo,
                            ),
                      )
                    : _PreviewPlaceholder(
                        title: title,
                        description: l10n.activeExerciseNoVideo,
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ),
              if (canOpenVideo)
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: context.trainingAccent,
                      size: 46,
                    ),
                  ),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            canOpenVideo
                                ? l10n.video
                                : l10n.activeExerciseNoVideo,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  final String title;
  final String description;

  const _PreviewPlaceholder({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Container(
      color: palette.surfaceVariant,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, color: palette.textDisabled, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
