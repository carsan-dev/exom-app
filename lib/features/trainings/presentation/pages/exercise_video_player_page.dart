import 'dart:async';
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class ExerciseVideoPlayerPage extends StatefulWidget {
  final String title;
  final Uri videoUri;

  /// Builds the controller for [videoUri]; tests inject a fake one. Production
  /// callers leave it null and get the network controller on a platform view.
  @visibleForTesting
  final VideoPlayerController Function(Uri uri)? controllerFactory;

  const ExerciseVideoPlayerPage({
    super.key,
    required this.title,
    required this.videoUri,
    this.controllerFactory,
  });

  @override
  State<ExerciseVideoPlayerPage> createState() =>
      _ExerciseVideoPlayerPageState();
}

class _ExerciseVideoPlayerPageState extends State<ExerciseVideoPlayerPage> {
  VideoPlayerController? _controller;
  Object? _initializationError;
  bool _isInitializing = true;
  bool _isSpeedBoostActive = false;
  double? _speedBeforeBoost;
  bool _controlsVisible = true;
  Timer? _idleTimer;

  /// Fingers on the screen: while any is down (a hold, a scrubber drag) the
  /// countdown waits, and it restarts when the last one lifts.
  int _activePointers = 0;

  /// The play glyph is 28 dp centred in a 56 dp button, so it sits 14 dp in
  /// from the button edge; the sketch pulls the button back by that much
  /// (`margin-left:-14px`) to line the glyph up with the content edge.
  static const double _playGlyphInset = 14;

  /// Idle time before the controls fade out (D17-3). The sketch only fixes the
  /// 160 ms fade; 3 s is the proposed value, pending the owner's decision.
  static const Duration _idleDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A screen reader switched on (or off) re-evaluates the countdown.
    _armIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
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

    final factory = widget.controllerFactory;
    final controller = factory != null
        ? factory(widget.videoUri)
        : VideoPlayerController.networkUrl(
            widget.videoUri,
            viewType: VideoViewType.platformView,
          );

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
        _controlsVisible = true;
      });
      _armIdleTimer();
    } catch (error) {
      await controller.dispose();

      if (!mounted) return;

      setState(() {
        _initializationError = error;
        _isInitializing = false;
      });
    }
  }

  /// (Re)starts the idle countdown. With a screen reader active the controls
  /// never hide, so there is nothing to count.
  void _armIdleTimer() {
    _idleTimer?.cancel();
    if (_controller == null || MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    _idleTimer = Timer(_idleDelay, _hideControls);
  }

  void _hideControls() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    // Paused: the play button must stay in sight.
    if (!controller.value.isPlaying ||
        _activePointers > 0 ||
        MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    setState(() => _controlsVisible = false);
  }

  /// Any touch brings the controls back at once (it does not wait for a
  /// gesture to be recognised); the countdown waits until the touch ends.
  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    _idleTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
  }

  /// The last finger lifting (a tap, the end of a hold or of a scrubber drag)
  /// restarts the countdown.
  void _onPointerEnd(PointerEvent event) {
    if (_activePointers > 0) _activePointers--;
    if (_activePointers == 0) _armIdleTimer();
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

  Future<void> _startSpeedBoost() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying ||
        _isSpeedBoostActive) {
      return;
    }

    _speedBeforeBoost = controller.value.playbackSpeed;
    setState(() => _isSpeedBoostActive = true);

    try {
      await controller.setPlaybackSpeed(2);
    } catch (_) {
      if (!mounted || controller != _controller || !_isSpeedBoostActive) return;
      setState(() {
        _isSpeedBoostActive = false;
        _speedBeforeBoost = null;
      });
    }
  }

  Future<void> _stopSpeedBoost() async {
    if (!_isSpeedBoostActive) return;

    final controller = _controller;
    final speedToRestore = _speedBeforeBoost ?? 1;
    _speedBeforeBoost = null;
    if (mounted) {
      setState(() => _isSpeedBoostActive = false);
    } else {
      _isSpeedBoostActive = false;
    }

    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setPlaybackSpeed(speedToRestore);
    } catch (_) {
      // The player may have been disposed while the gesture was ending.
    }
  }

  Widget _interactionZone(Duration seekOffset) {
    // Touch-only shortcuts (the play button and the scrubber are the accessible
    // path): excluded from semantics so no unlabeled tappable node is exposed.
    return Expanded(
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: () => _seekBy(seekOffset),
          onLongPressStart: (_) => _startSpeedBoost(),
          onLongPressEnd: (_) => _stopSpeedBoost(),
          onLongPressCancel: _stopSpeedBoost,
          child: const SizedBox.expand(),
        ),
      ),
    );
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

    // Two-digit minutes, like the sketch (`00:12 / 00:38`).
    return '$twoDigitsMinutes:$twoDigitsSeconds';
  }

  /// Splits the exercise name over the two lines of the headline, by words.
  (String, String) _headlineLines(String title) {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.length < 2) return (words.first, '');
    final cut = (words.length / 2).ceil();
    return (words.take(cut).join(' '), words.skip(cut).join(' '));
  }

  /// The exercise name as the headline. A one-word name is a single line (the
  /// two-line headline would leave an empty second line).
  Widget _headline(BuildContext context, String title) {
    final (first, second) = _headlineLines(title);
    if (second.isNotEmpty) {
      return ExomTwoLineHeadline(
        first: first,
        second: second,
        semanticsLabel: title,
      );
    }
    return Semantics(
      header: true,
      label: title,
      excludeSemantics: true,
      child: Text(
        first.toUpperCase(),
        style: ExomType.headline2Section.copyWith(
          color: context.exomPalette.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The player is pure black in both themes (sketch A3): the dark palette is
    // forced under it so ink and lime data read on the video background, and
    // the status bar keeps light icons on that black in both themes.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: AppTheme.dark,
        child: Builder(builder: _buildPlayer),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final controller = _controller;
    final ready =
        !_isInitializing &&
            _initializationError == null &&
            controller != null &&
            controller.value.isInitialized
        ? controller
        : null;

    return Scaffold(
      backgroundColor: Colors.black, // l5-allow: video background, pure black
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: LayoutBuilder(
          builder: (context, constraints) => ready == null
              ? _buildLayout(context, constraints.biggest, null, null)
              : ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: ready,
                  builder: (context, value, child) =>
                      _buildLayout(context, constraints.biggest, ready, value),
                ),
        ),
      ),
    );
  }

  /// One stable tree for every layout (so rotating keeps the video view);
  /// [_PlayerLayout] measures the real chrome and picks the arrangement.
  Widget _buildLayout(
    BuildContext context,
    Size viewport,
    VideoPlayerController? controller,
    VideoPlayerValue? value,
  ) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final motion = ExomMotion.of(context);
    final isReady = controller != null && value != null;
    final chromeVisible =
        !isReady ||
        _controlsVisible ||
        MediaQuery.accessibleNavigationOf(context);
    final title = widget.title.trim().isEmpty ? l10n.video : widget.title;

    final videoSize = value?.size ?? Size.zero;
    final videoAspect = videoSize.width > 0 && videoSize.height > 0
        ? videoSize.width / videoSize.height
        : 16 / 9;

    Widget veil(Key key) => IgnorePointer(
      child: _ChromeFade(
        opacityKey: key,
        visible: chromeVisible,
        motion: motion,
        child: ColoredBox(
          // l5-allow: flat veil. 0.72 keeps white, ink, lime data and grey
          // text at 4.5:1 over the composite on a pure white video (0.45
          // gave 1.7-3.4:1, review 3).
          color: Colors.black.withValues(alpha: 0.72),
        ),
      ),
    );

    return SingleChildScrollView(
      child: _PlayerLayout(
        viewportHeight: viewport.height,
        padding: MediaQuery.paddingOf(context),
        videoAspect: videoAspect,
        children: [
          if (controller != null && value != null)
            LayoutId(id: _Slot.video, child: VideoPlayer(controller)),
          LayoutId(
            id: _Slot.stage,
            child: _buildStage(context, ready: isReady, l10n: l10n),
          ),
          LayoutId(
            id: _Slot.veilTop,
            child: veil(const ValueKey('video-player-veil-top')),
          ),
          LayoutId(
            id: _Slot.veilBottom,
            child: veil(const ValueKey('video-player-veil-bottom')),
          ),
          if (controller != null && value != null)
            LayoutId(
              id: _Slot.pill,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: motion.inPlaceSwitch,
                  child: _isSpeedBoostActive
                      ? _SpeedPill(
                          key: const ValueKey('video-player-speed-pill'),
                          palette: palette,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          LayoutId(
            id: _Slot.headline,
            // Scrolls in its own box when the overlay leaves it too little
            // room (very large text in landscape).
            child: Semantics(
              explicitChildNodes: true,
              sortKey: const OrdinalSortKey(1),
              child: _ChromeFade(
                visible: chromeVisible,
                motion: motion,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExomSpacing.xl,
                      ExomSpacing.sm,
                      ExomSpacing.xl,
                      0,
                    ),
                    child: _headline(context, title),
                  ),
                ),
              ),
            ),
          ),
          LayoutId(
            id: _Slot.header,
            child: Semantics(
              explicitChildNodes: true,
              sortKey: const OrdinalSortKey(0),
              child: _ChromeFade(
                visible: chromeVisible,
                motion: motion,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BackButton(color: palette.textPrimary),
                  ),
                ),
              ),
            ),
          ),
          if (controller != null && value != null)
            LayoutId(
              id: _Slot.controls,
              child: Semantics(
                explicitChildNodes: true,
                sortKey: const OrdinalSortKey(3),
                child: _ChromeFade(
                  opacityKey: const ValueKey('video-player-controls'),
                  visible: chromeVisible,
                  motion: motion,
                  child: _buildControls(
                    context,
                    controller,
                    value,
                    l10n,
                    palette,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The touch surface of the video: double tap ±5 s and hold for 2× (or the
  /// loading and error states before the video is ready).
  Widget _buildStage(
    BuildContext context, {
    required bool ready,
    required AppLocalizations l10n,
  }) {
    if (!ready) {
      return _isInitializing
          ? const LoadingWidget()
          : Center(
              child: SingleChildScrollView(
                child: ErrorWidget2(
                  message: l10n.errorServer,
                  onRetry: _initializeController,
                ),
              ),
            );
    }

    // The double tap ±5 s is touch only; a screen reader gets the same seeks
    // as custom actions on the video, which it names with the exercise.
    return Semantics(
      key: const ValueKey('video-player-stage'),
      container: true,
      // The headline already announces the exercise; the stage only names
      // what it is, so the title is not read twice.
      label: l10n.video,
      sortKey: const OrdinalSortKey(2),
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.videoPlayerRewind5): () =>
            _seekBy(const Duration(seconds: -5)),
        CustomSemanticsAction(label: l10n.videoPlayerForward5): () =>
            _seekBy(const Duration(seconds: 5)),
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _interactionZone(const Duration(seconds: -5)),
          _interactionZone(const Duration(seconds: 5)),
        ],
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    VideoPlayerController controller,
    VideoPlayerValue value,
    AppLocalizations l10n,
    ExomThemePalette palette,
  ) {
    final totalMs = value.duration.inMilliseconds;
    final fraction = totalMs > 0
        ? value.position.inMilliseconds / totalMs
        : 0.0;
    final timeStyle = ExomType.section;
    return Padding(
      padding: const EdgeInsets.only(
        top: ExomSpacing.sm,
        bottom: ExomSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The rule is the visual; the scrubber keeps the drag and gives a
          // 48 dp touch height around the 4 px line.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.xl),
            child: Semantics(
              label: l10n.videoPlayerProgress,
              child: VideoScrubber(
                controller: controller,
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: ExomProgressRule(
                      value: fraction,
                      thickness: ExomRule.bar,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: ExomSpacing.xl - _playGlyphInset,
              end: ExomSpacing.xl,
            ),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('video-player-toggle'),
                  onPressed: _togglePlayback,
                  tooltip: value.isPlaying
                      ? l10n.videoPlayerPause
                      : l10n.videoPlayerPlay,
                  iconSize: 28,
                  color: palette.textPrimary,
                  constraints: const BoxConstraints.tightFor(
                    width: 56,
                    height: 56,
                  ),
                  icon: Icon(
                    value.isPlaying
                        ? ExomIcons.pause
                        : ExomIcons.play,
                  ),
                ),
                const SizedBox(width: ExomSpacing.md),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _formatDuration(value.position),
                            style: timeStyle.copyWith(color: palette.data),
                          ),
                          TextSpan(
                            text: ' / ${_formatDuration(value.duration)}',
                            style: timeStyle.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pieces of the player arranged by [_PlayerLayout].
enum _Slot {
  video,
  stage,
  veilTop,
  veilBottom,
  pill,
  headline,
  header,
  controls,
}

/// Arranges the player from the real size of its chrome (decision L5-A2,
/// reviews F1 and F3):
///
/// * **Sketch** (portrait, when header + headline + the full-width video +
///   controls fit the screen): the video `contain` centred in the stage
///   between headline and controls.
/// * **Scroll** (portrait, landscape clip, very large text): the same column,
///   taller than the screen, with the video at full width; the page scrolls.
/// * **Overlay** (landscape screen, or a square or vertical clip that does not
///   fit with the chrome): the base page's full screen video (`cover` when
///   screen and clip share orientation, `contain` otherwise) with the chrome
///   over it, a flat veil behind it and the 2× pill in the header row.
///
/// The children are always the same, whatever the arrangement, so rotating
/// the phone keeps the video view.
class _PlayerLayout extends MultiChildRenderObjectWidget {
  const _PlayerLayout({
    required this.viewportHeight,
    required this.padding,
    required this.videoAspect,
    required super.children,
  });

  final double viewportHeight;
  final EdgeInsets padding;
  final double videoAspect;

  @override
  _RenderPlayerLayout createRenderObject(BuildContext context) =>
      _RenderPlayerLayout(
        viewportHeight: viewportHeight,
        padding: padding,
        videoAspect: videoAspect,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPlayerLayout renderObject,
  ) {
    renderObject
      ..viewportHeight = viewportHeight
      ..padding = padding
      ..videoAspect = videoAspect;
  }
}

class _RenderPlayerLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  _RenderPlayerLayout({
    required double viewportHeight,
    required EdgeInsets padding,
    required double videoAspect,
  }) : _viewportHeight = viewportHeight,
       _padding = padding,
       _videoAspect = videoAspect;

  double _viewportHeight;
  set viewportHeight(double value) {
    if (value == _viewportHeight) return;
    _viewportHeight = value;
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  double _videoAspect;
  set videoAspect(double value) {
    if (value == _videoAspect) return;
    _videoAspect = value;
    markNeedsLayout();
  }

  /// Area the video is clipped to (the stage).
  Rect _stageRect = Rect.zero;
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  Map<_Slot, RenderBox> _children() {
    final slots = <_Slot, RenderBox>{};
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as MultiChildLayoutParentData;
      slots[data.id! as _Slot] = child;
      child = data.nextSibling;
    }
    return slots;
  }

  static void _place(RenderBox? child, Rect rect) {
    if (child == null) return;
    child.layout(BoxConstraints.tight(rect.size));
    (child.parentData! as MultiChildLayoutParentData).offset = rect.topLeft;
  }

  /// [inner] scaled to [aspect], centred, filling it (`cover`) or inside it.
  static Rect _fit(Rect inner, double aspect, {required bool cover}) {
    final wide = inner.width / inner.height > aspect;
    final byHeight = cover ? !wide : wide;
    final size = byHeight
        ? Size(inner.height * aspect, inner.height)
        : Size(inner.width, inner.width / aspect);
    return Rect.fromCenter(
      center: inner.center,
      width: size.width,
      height: size.height,
    );
  }

  // computeDryLayout and the intrinsic sizes are not implemented on purpose:
  // the height depends on laying out the real chrome, and the only ancestor
  // that could ask (the LayoutBuilder in `_buildPlayer`) already asserts
  // against dry layout and intrinsics, so nothing can reach them.
  @override
  void performLayout() {
    final slots = _children();
    final width = constraints.maxWidth;
    final screenHeight = _viewportHeight;
    final top = _padding.top;
    final bottom = _padding.bottom;
    final inner = math.max(0.0, width - _padding.horizontal);
    final loose = BoxConstraints(maxWidth: inner);

    double measure(_Slot slot) {
      final child = slots[slot];
      if (child == null) return 0;
      child.layout(loose, parentUsesSize: true);
      return child.size.height;
    }

    final headerHeight = measure(_Slot.header);
    final controlsHeight = measure(_Slot.controls);
    final headlineNatural =
        slots[_Slot.headline]?.getMaxIntrinsicHeight(inner) ?? 0;
    final stacked =
        top +
        headerHeight +
        headlineNatural +
        width / _videoAspect +
        controlsHeight +
        bottom;
    final screenIsLandscape = width > screenHeight;
    final overlay =
        screenIsLandscape || (stacked > screenHeight && _videoAspect <= 1);

    final double height;
    final double headlineHeight;
    if (overlay) {
      height = screenHeight;
      final room = screenHeight - top - headerHeight - controlsHeight - bottom;
      headlineHeight = math.min(headlineNatural, math.max(0.0, room));
      _stageRect = Offset.zero & Size(width, height);
    } else {
      height = math.max(screenHeight, stacked);
      headlineHeight = headlineNatural;
      _stageRect = Rect.fromLTRB(
        0,
        top + headerHeight + headlineHeight,
        width,
        height - bottom - controlsHeight,
      );
    }
    size = constraints.constrain(Size(width, height));

    void offset(_Slot slot, Offset at) {
      final child = slots[slot];
      if (child == null) return;
      (child.parentData! as MultiChildLayoutParentData).offset = at;
    }

    offset(_Slot.header, Offset(_padding.left, top));
    _place(
      slots[_Slot.headline],
      Rect.fromLTWH(_padding.left, top + headerHeight, inner, headlineHeight),
    );
    final controlsTop = height - bottom - controlsHeight;
    offset(_Slot.controls, Offset(_padding.left, controlsTop));
    _place(slots[_Slot.stage], _stageRect);

    final videoIsLandscape = _videoAspect >= 1;
    _place(
      slots[_Slot.video],
      _fit(
        _stageRect,
        _videoAspect,
        cover: overlay && screenIsLandscape == videoIsLandscape,
      ),
    );

    final pill = slots[_Slot.pill];
    if (pill != null) {
      pill.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
      // Overlay: centred in the header row, clear of the back button and of
      // the headline. Sketch: at the top of the stage.
      final pillTop = overlay
          ? top + math.max(0.0, (headerHeight - pill.size.height) / 2)
          : _stageRect.top + ExomSpacing.md;
      offset(_Slot.pill, Offset((width - pill.size.width) / 2, pillTop));
    }

    // The veil exists only in the overlay, behind header + headline and
    // behind the controls.
    _place(
      slots[_Slot.veilTop],
      overlay
          ? Rect.fromLTWH(0, 0, width, top + headerHeight + headlineHeight)
          : Rect.zero,
    );
    _place(
      slots[_Slot.veilBottom],
      overlay ? Rect.fromLTRB(0, controlsTop, width, height) : Rect.zero,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final current = child;
      final data = current.parentData! as MultiChildLayoutParentData;
      if (data.id == _Slot.video) {
        _clipLayer.layer = context.pushClipRect(
          needsCompositing,
          offset,
          _stageRect,
          (context, offset) =>
              context.paintChild(current, offset + data.offset),
          oldLayer: _clipLayer.layer,
        );
      } else {
        context.paintChild(current, offset + data.offset);
      }
      child = data.nextSibling;
    }
  }

  /// Top-most first. The headline lets the touch through to the video, so a
  /// double tap or a hold over it still works in the overlay.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final current = child;
      final data = current.parentData! as MultiChildLayoutParentData;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            current.hitTest(result, position: transformed),
      );
      if (hit && data.id != _Slot.headline) return true;
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}

/// Fades a piece of the player chrome in and out (M4, 160 ms; 120 ms with
/// reduced motion). Hidden, it takes no touch and no semantics, so the first
/// touch only brings it back.
class _ChromeFade extends StatelessWidget {
  const _ChromeFade({
    this.opacityKey,
    required this.visible,
    required this.motion,
    required this.child,
  });

  /// Key of the inner [AnimatedOpacity], for tests.
  final Key? opacityKey;
  final bool visible;
  final ExomMotionSpec motion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedOpacity(
          key: opacityKey,
          opacity: visible ? 1 : 0,
          duration: motion.inPlaceSwitch,
          curve: ExomMotion.inPlaceCurve,
          child: child,
        ),
      ),
    );
  }
}

/// «2×» state while the video is held: flat box, radius 4, no circle.
class _SpeedPill extends StatelessWidget {
  const _SpeedPill({super.key, required this.palette});

  final ExomThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6), // l5-allow: video veil
        borderRadius: BorderRadius.circular(ExomRadius.control),
        border: Border.all(color: palette.textPrimary.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ExomIcons.fastForward,
            color: palette.textPrimary,
            size: 18,
          ),
          const SizedBox(width: ExomSpacing.xs),
          Text(
            '2×',
            style: ExomType.section.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }
}
