import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The first frame and the duration of a local clip, nothing else: it never
/// plays. [initialize] opens the file; [duration], [size] and [buildFrame]
/// are only meaningful after it completes. [dispose] releases the decoder and
/// may be called at any time, also while [initialize] is pending.
abstract class LocalVideoPreview {
  Future<void> initialize();
  Duration get duration;
  Size get size;
  Widget buildFrame(BuildContext context);
  Future<void> dispose();
}

typedef LocalVideoPreviewFactory = LocalVideoPreview Function(File file);

/// Test seam for the pages that build the last-set video sheet without their
/// own factory (active exercise, circuit): when set, the default factory
/// returns its preview instead of opening `video_player`. Tests reset it.
@visibleForTesting
LocalVideoPreviewFactory? debugLocalVideoPreviewFactoryOverride;

/// Default [LocalVideoPreviewFactory]: a muted `VideoPlayerController.file`
/// that is initialized and never played, so it shows the first frame.
LocalVideoPreview createPlayerLocalVideoPreview(File file) =>
    debugLocalVideoPreviewFactoryOverride?.call(file) ??
    _PlayerLocalVideoPreview(file);

class _PlayerLocalVideoPreview implements LocalVideoPreview {
  _PlayerLocalVideoPreview(File file)
    : _controller = VideoPlayerController.file(file);

  final VideoPlayerController _controller;

  @override
  Future<void> initialize() async {
    await _controller.initialize();
    await _controller.setVolume(0);
    // Some Android decoders only paint a frame after a seek when paused.
    await _controller.seekTo(Duration.zero);
  }

  @override
  Duration get duration => _controller.value.duration;

  @override
  Size get size => _controller.value.size;

  @override
  Widget buildFrame(BuildContext context) => VideoPlayer(_controller);

  @override
  Future<void> dispose() => _controller.dispose();
}

/// How long the thumbnail waits for a clip before keeping the icon box.
const Duration kLocalVideoPreviewTimeout = Duration(seconds: 10);

/// Longest wait for the previous player's release before opening the next.
const Duration kLocalVideoDisposeWait = Duration(seconds: 1);

/// Releases still in flight, shared by every thumbnail: a new clip opens
/// only once they finish (or after [kLocalVideoDisposeWait]), so two native
/// players never overlap when «Cambiar» unmounts one thumbnail and the next
/// clip mounts another.
final Set<Future<void>> _pendingDisposals = <Future<void>>{};

/// Forgets releases left by earlier tests (one that never finishes would
/// delay every later clip by [kLocalVideoDisposeWait]).
@visibleForTesting
void debugResetLocalVideoDisposals() => _pendingDisposals.clear();

/// Disposes [preview] without letting a synchronous throw or a failed future
/// escape, and tracks the release in [_pendingDisposals] until it ends.
void _disposeQuietly(LocalVideoPreview preview) {
  Future<void> release;
  try {
    release = preview.dispose().catchError((Object _) {});
  } on Object {
    return;
  }
  _pendingDisposals.add(release);
  unawaited(release.whenComplete(() => _pendingDisposals.remove(release)));
}

/// Fade of the frame over the icon box (reduced motion: none).
const Duration _frameFade = Duration(milliseconds: 150);

/// «0:42», «12:05» or, from one hour, «1:02:03». Whole seconds, rounded
/// down, except that a clip shorter than a second shows «0:01».
String formatClipDuration(Duration duration) {
  var total = duration.inSeconds;
  if (total == 0 && duration > Duration.zero) total = 1;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// The 56 dp box of «Vídeo preparado» (L5-E3d): the outlined box with
/// [ExomIcons.video] while the clip opens or when it cannot be read, and the
/// clip's first frame (cover, clipped to the same box and outline) once it is
/// ready, faded in over the box. Decorative: excluded from semantics.
///
/// Owns at most one [LocalVideoPreview]: a new [file] releases the previous
/// one before opening the next, and unmounting releases it, also while it is
/// still initializing. [onDuration] gets the clip's duration when it is known
/// and positive.
class LocalVideoThumbnail extends StatefulWidget {
  const LocalVideoThumbnail({
    super.key,
    required this.file,
    this.previewFactory = createPlayerLocalVideoPreview,
    this.onDuration,
  });

  final File file;
  final LocalVideoPreviewFactory previewFactory;
  final ValueChanged<Duration>? onDuration;

  @override
  State<LocalVideoThumbnail> createState() => _LocalVideoThumbnailState();
}

class _LocalVideoThumbnailState extends State<LocalVideoThumbnail> {
  LocalVideoPreview? _preview;
  bool _ready = false;
  Timer? _timeout;

  /// Bounds the wait for earlier releases (see [_pendingDisposals]).
  Timer? _disposeWait;

  /// Bumped on every release, so a late `initialize` of a released preview
  /// is ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(LocalVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _release();
      _open();
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    _generation++;
    _timeout?.cancel();
    _timeout = null;
    _disposeWait?.cancel();
    _disposeWait = null;
    _ready = false;
    final preview = _preview;
    _preview = null;
    if (preview != null) _disposeQuietly(preview);
  }

  /// Completes when the releases pending now have finished, or after
  /// [kLocalVideoDisposeWait] if one hangs. Never errors.
  Future<void> _previousReleases() {
    if (_pendingDisposals.isEmpty) return Future<void>.value();
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    unawaited(Future.wait(_pendingDisposals.toList()).then((_) => finish()));
    _disposeWait = Timer(kLocalVideoDisposeWait, finish);
    return done.future;
  }

  Future<void> _open() async {
    final generation = ++_generation;
    // The icon box shows while the previous player is released.
    await _previousReleases();
    if (generation != _generation || !mounted) return;
    _disposeWait?.cancel();
    _disposeWait = null;
    final LocalVideoPreview preview;
    try {
      preview = widget.previewFactory(widget.file);
    } on Object {
      return;
    }
    _preview = preview;
    _timeout = Timer(kLocalVideoPreviewTimeout, () {
      if (generation != _generation || !mounted) return;
      setState(_release);
    });
    try {
      await preview.initialize();
    } on Object {
      if (generation == _generation && mounted) setState(_release);
      return;
    }
    if (generation != _generation || !mounted) return;
    _timeout?.cancel();
    _timeout = null;
    final size = preview.size;
    final duration = preview.duration;
    setState(() => _ready = !size.isEmpty);
    if (duration > Duration.zero) widget.onDuration?.call(duration);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final preview = _preview;
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: palette.borderSoft),
          borderRadius: BorderRadius.circular(2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                ExomIcons.video,
                size: 24,
                color: palette.textPrimary,
              ),
            ),
            if (_ready && preview != null)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: PerformanceProfile.animationDuration(
                  context,
                  _frameFade,
                ),
                builder: (context, opacity, child) =>
                    Opacity(opacity: opacity, child: child),
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: preview.size.width,
                    height: preview.size.height,
                    child: preview.buildFrame(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
