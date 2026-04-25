import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class ExerciseVideoPreview extends StatefulWidget {
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

  @override
  State<ExerciseVideoPreview> createState() => _ExerciseVideoPreviewState();
}

class _ExerciseVideoPreviewState extends State<ExerciseVideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _hasError = false;

  bool get _hasVideo =>
      widget.videoUrl != null && widget.videoUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializeController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeController() async {
    final previousController = _controller;
    _controller = null;
    _hasError = false;

    final rawUrl = widget.videoUrl?.trim();
    final uri = rawUrl == null || rawUrl.isEmpty ? null : Uri.tryParse(rawUrl);
    if (uri == null) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
      await previousController?.dispose();
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
      });
    }

    await previousController?.dispose();

    final controller = VideoPlayerController.networkUrl(uri);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    final hasInitialized = controller != null && controller.value.isInitialized;
    final canOpenVideo = _hasVideo && widget.onTap != null;
    final thumbnailUrl = widget.thumbnailUrl?.trim();
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canOpenVideo ? widget.onTap : null,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: GlassDecoration.card(borderRadius: 28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: hasInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      )
                    : hasThumbnail
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, imageUrl) => Container(
                          color: palette.surfaceVariant,
                        ),
                        errorWidget: (context, imageUrl, error) =>
                            _PreviewPlaceholder(
                          title: widget.title,
                          description: l10n.activeExerciseNoVideo,
                        ),
                      )
                    : _PreviewPlaceholder(
                        title: widget.title,
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
              if (_isInitializing)
                const Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
              if (_hasError && !hasThumbnail)
                Center(
                  child: Text(
                    l10n.activeExerciseNoVideo,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
                            widget.title,
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
                            canOpenVideo ? l10n.video : l10n.activeExerciseNoVideo,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canOpenVideo)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 18,
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

  const _PreviewPlaceholder({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Container(
      color: palette.surfaceVariant,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            color: palette.textDisabled,
            size: 42,
          ),
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
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
