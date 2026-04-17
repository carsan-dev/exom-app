import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ExerciseVideoPlayerPage extends StatefulWidget {
  final String title;
  final Uri videoUri;

  const ExerciseVideoPlayerPage({
    super.key,
    required this.title,
    required this.videoUri,
  });

  @override
  State<ExerciseVideoPlayerPage> createState() =>
      _ExerciseVideoPlayerPageState();
}

class _ExerciseVideoPlayerPageState extends State<ExerciseVideoPlayerPage> {
  VideoPlayerController? _controller;
  Object? _initializationError;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeController() async {
    final previousController = _controller;

    setState(() {
      _isInitializing = true;
      _initializationError = null;
      _controller = null;
    });

    await previousController?.dispose();

    final controller = VideoPlayerController.networkUrl(widget.videoUri);

    try {
      await controller.initialize();
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (error) {
      await controller.dispose();

      if (!mounted) return;

      setState(() {
        _initializationError = error;
        _isInitializing = false;
      });
    }
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }

    setState(() {});
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final currentPosition = controller.value.position;
    final duration = controller.value.duration;
    final targetMilliseconds = (currentPosition + offset).inMilliseconds.clamp(
      0,
      duration.inMilliseconds,
    );

    await controller.seekTo(Duration(milliseconds: targetMilliseconds));
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final twoDigitsMinutes = minutes.toString().padLeft(2, '0');
    final twoDigitsSeconds = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$twoDigitsMinutes:$twoDigitsSeconds';
    }

    return '$minutes:$twoDigitsSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title.isEmpty ? l10n.video : widget.title),
      ),
      body: _isInitializing
          ? const LoadingWidget()
          : _initializationError != null ||
                controller == null ||
                !controller.value.isInitialized
          ? Center(
              child: ErrorWidget2(
                message: l10n.errorServer,
                onRetry: _initializeController,
              ),
            )
          : ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final videoSize = value.size;
                final hasVideoSize =
                    videoSize.width > 0 && videoSize.height > 0;
                final screenIsLandscape = screenSize.width > screenSize.height;
                final videoIsLandscape = hasVideoSize
                    ? videoSize.width >= videoSize.height
                    : true;
                final videoFit = screenIsLandscape == videoIsLandscape
                    ? BoxFit.cover
                    : BoxFit.contain;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: SizedBox.expand(
                        child: FittedBox(
                          fit: videoFit,
                          child: SizedBox(
                            width: videoSize.width,
                            height: videoSize.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onDoubleTap: () =>
                                _seekBy(const Duration(seconds: -5)),
                            child: const SizedBox(),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onDoubleTap: () =>
                                _seekBy(const Duration(seconds: 5)),
                            child: const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            stops: const [0, 0.2, 0.58, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VideoProgressIndicator(
                                controller,
                                allowScrubbing: true,
                                padding: EdgeInsets.zero,
                                colors: VideoProgressColors(
                                  playedColor: Colors.white,
                                  bufferedColor: Colors.white30,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  IconButton.filled(
                                    onPressed: _togglePlayback,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                    ),
                                    icon: Icon(
                                      value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${_formatDuration(value.position)} / '
                                      '${_formatDuration(value.duration)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
