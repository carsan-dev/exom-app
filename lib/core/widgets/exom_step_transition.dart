import 'dart:ui' as ui;

import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How [ExomStepTransition] moves from one step to the next.
enum ExomStepTransitionStyle {
  /// The overlapped M9: the new step enters [ExomMotion.stepOffset] dp from
  /// the side the form advances to with a fade while the previous one fades
  /// out towards the other side.
  overlap,

  /// A horizontal push (L5-C5b): the previous step moves fully out to one
  /// side while the new one enters from the other, both fully opaque and
  /// clipped to the area of the transition, in [ExomMotion.stepSlide] on
  /// [ExomMotion.stepSlideCurve]. Going back pushes the other way. Reduced
  /// motion: the short fade of [overlap].
  slide,
}

/// M9 form step: when [step] changes, the new [child] enters
/// [ExomMotion.stepOffset] dp from the side the form advances to (the
/// reading-direction end when [step] grows, the start when it goes back) with
/// a fade, in [ExomMotion.step]; the previous step leaves towards the other
/// side. Reduced motion: a 100 ms fade, no offset.
///
/// The new step takes taps from the first frame; the leaving one ignores
/// them and is out of the semantics tree (L5-A4c). A new change mid-animation starts from where things are: each step
/// keeps the curve of the direction its animation started in until it comes
/// to rest, so reversing mid-way does not jump.
///
/// [style] picks the push of [ExomStepTransitionStyle.slide] instead; the
/// default stays the overlapped M9.
///
/// [snapshot] (overlap only, L6-S25-D2): while a step moves it is painted
/// from a raster image of its content taken once, with the same opacity and
/// offset, instead of a new group-opacity layer every frame. The picture is
/// the same; the GPU stops rendering every moving step offscreen on each
/// frame. Use it only for steps whose content does not change while they
/// move (e.g. the calendar month): when the content repaints mid-move, or it
/// holds its own layers, the step falls back to the opacity layer until it
/// comes to rest.
class ExomStepTransition extends StatefulWidget {
  const ExomStepTransition({
    super.key,
    required this.step,
    required this.child,
    this.style = ExomStepTransitionStyle.overlap,
    this.snapshot = false,
  });

  final int step;
  final Widget child;
  final ExomStepTransitionStyle style;
  final bool snapshot;

  @override
  State<ExomStepTransition> createState() => _ExomStepTransitionState();
}

class _ExomStepTransitionState extends State<ExomStepTransition> {
  /// 1 when the last change advanced, -1 when it went back.
  double _advance = 1;

  @override
  void didUpdateWidget(ExomStepTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step != oldWidget.step) {
      _advance = widget.step > oldWidget.step ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = ExomMotion.of(context);
    if (widget.style == ExomStepTransitionStyle.slide && motion.stepSlides) {
      return _StepPush(step: widget.step, child: widget.child);
    }
    final side =
        _advance *
        (Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0);
    final current = ValueKey<int>(widget.step);
    return AnimatedSwitcher(
      duration: motion.step,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == current;
        return _StepEntry(
          animation: animation,
          slides: motion.stepSlides,
          offset: motion.stepSlides
              ? motion.stepOffset * (incoming ? side : -side)
              : 0,
          incoming: incoming,
          snapshot: widget.snapshot,
          child: child,
        );
      },
      child: KeyedSubtree(key: current, child: widget.child),
    );
  }
}

/// One step inside the switcher. Its [CurvedAnimation] is created once, so
/// the curve does not change when the animation is reversed mid-way.
class _StepEntry extends StatefulWidget {
  const _StepEntry({
    required this.animation,
    required this.slides,
    required this.offset,
    required this.incoming,
    required this.snapshot,
    required this.child,
  });

  final Animation<double> animation;
  final bool slides;
  final bool snapshot;

  /// Signed distance the step sits at when fully hidden.
  final double offset;
  final bool incoming;
  final Widget child;

  @override
  State<_StepEntry> createState() => _StepEntryState();
}

class _StepEntryState extends State<_StepEntry> {
  late CurvedAnimation _curved;

  /// Side the step sits at when hidden. It only changes while the step is at
  /// rest and complete, so a rebuild mid-animation (a second change before the
  /// first ends) cannot flip it and make the step jump.
  late double _offset;

  @override
  void initState() {
    super.initState();
    _curved = _create();
    _offset = widget.offset;
  }

  @override
  void didUpdateWidget(_StepEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.slides != widget.slides) {
      _curved.dispose();
      _curved = _create();
    }
    if (widget.animation.value >= 1) _offset = widget.offset;
  }

  CurvedAnimation _create() => widget.slides
      ? CurvedAnimation(
          parent: widget.animation,
          curve: ExomMotion.stepCurve,
          reverseCurve: ExomMotion.sheetExitCurve.flipped,
        )
      : CurvedAnimation(parent: widget.animation, curve: Curves.linear);

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
    final offset = _offset;
    // The leaving step is only painted: it takes no taps and a screen reader
    // does not read it (L5-A4c), so the content is never announced twice.
    return IgnorePointer(
      ignoring: !widget.incoming,
      child: ExcludeFocus(
        excluding: !widget.incoming,
        child: ExcludeSemantics(
          excluding: !widget.incoming,
          child: widget.snapshot
              ? _SnapshotStep(
                  progress: curved,
                  offset: offset,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  child: widget.child,
                )
              : FadeTransition(
                  opacity: curved,
                  child: AnimatedBuilder(
                    animation: curved,
                    child: widget.child,
                    builder: (context, child) => Transform.translate(
                      offset: Offset((1 - curved.value) * offset, 0),
                      child: child,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The push of [ExomStepTransitionStyle.slide]. Two steps at most are
/// painted: [_a] and [_b] move as one strip, [_b] at `side * (1 - t)` widths
/// and [_a] at `-side * t` widths, where t is the curved progress. Advancing
/// runs t to 1 ([_b] is the step on screen); going back to [_a] mid-way runs
/// it back to 0 from where it is, so the push reverses without a jump. A
/// change to a third step mid-way jumps: the step on screen until then
/// becomes the one that leaves, from its place, and the other one is
/// dropped, so steps never pile up.
class _StepPush extends StatefulWidget {
  const _StepPush({required this.step, required this.child});

  final int step;
  final Widget child;

  @override
  State<_StepPush> createState() => _StepPushState();
}

class _StepPushState extends State<_StepPush>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ExomMotion.stepSlide,
    value: 1,
  )..addStatusListener(_onStatus);
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: ExomMotion.stepSlideCurve,
  );

  /// The step the strip leaves from (null at rest) and its last child.
  int? _a;
  Widget? _aChild;

  /// The step the strip moves to and its last child.
  late int _b;
  late Widget _bChild;

  /// 1 when the strip moves towards the start (advancing), -1 otherwise.
  double _side = 1;

  /// True while the step on screen is [_b] (the strip runs or rests at 1).
  bool _towardsB = true;

  /// True while a new push resets the strip to 0 (that is not a rest).
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    _b = widget.step;
    _bChild = widget.child;
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted || _restarting || status.isAnimating || _a == null) return;
    final dismissed = status.isDismissed;
    setState(() {
      if (dismissed) {
        // Rest on [_a]: it becomes the only step.
        _b = _a!;
        _bChild = _aChild ?? _bChild;
        _towardsB = true;
      }
      _a = null;
      _aChild = null;
    });
    // Back to the rest value of a single step (no listener work left: [_a]
    // is already null).
    if (dismissed) _controller.value = 1;
  }

  @override
  void didUpdateWidget(_StepPush oldWidget) {
    super.didUpdateWidget(oldWidget);
    final step = widget.step;
    final onScreen = _towardsB ? _b : _a;
    if (step == onScreen) return;
    if (_controller.isAnimating && step == (_towardsB ? _a : _b)) {
      // Back to the step that is leaving: the push runs the other way from
      // where it is.
      if (_towardsB) {
        _bChild = oldWidget.child;
        _controller.reverse();
      } else {
        _aChild = oldWidget.child;
        _controller.forward();
      }
      _towardsB = !_towardsB;
      return;
    }
    // A new push from the step on screen (a jump when one was running).
    _a = oldWidget.step;
    _aChild = oldWidget.child;
    _b = step;
    _side = step > oldWidget.step ? 1 : -1;
    _towardsB = true;
    _restarting = true;
    _controller.value = 0;
    _restarting = false;
    _controller.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _slot(int step, Widget child, double dx, {required bool active}) {
    // The step that leaves is only painted: it takes no taps and a screen
    // reader does not read it (L5-A4c).
    return KeyedSubtree(
      key: ValueKey<(String, int)>(('exom-step-push', step)),
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: KeyedSubtree(key: ValueKey<int>(step), child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final side = _side * (rtl ? -1.0 : 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final a = _a;
            final aChild = _aChild;
            final moving = a != null && aChild != null;
            final t = _progress.value;
            final bOnScreen = _towardsB;
            return ClipRect(
              // Clipped only while moving, so a step at rest paints as it
              // did.
              clipBehavior: moving ? Clip.hardEdge : Clip.none,
              child: Stack(
                alignment: AlignmentDirectional.topStart,
                children: [
                  if (moving && bOnScreen)
                    _slot(a, aChild, -side * t * width, active: false),
                  if (moving && !bOnScreen)
                    _slot(_b, _bChild, side * (1 - t) * width, active: false),
                  if (bOnScreen)
                    _slot(
                      _b,
                      widget.child,
                      moving ? side * (1 - t) * width : 0,
                      active: true,
                    )
                  else if (moving)
                    _slot(a, widget.child, -side * t * width, active: true),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// A moving step of [ExomStepTransition.snapshot]: the opacity and the
/// horizontal offset of the overlap (`FadeTransition` over
/// `Transform.translate`) in one render object that, while the step moves,
/// paints a raster image of its content taken on the first moving frame.
///
/// The image is the content rendered once offscreen at the device pixel
/// ratio and drawn with the step's alpha on the physical pixel grid, which is
/// what the group-opacity layer composites, without rendering the content
/// offscreen again on every frame (L6-S25-D2). At rest (alpha 255) and when
/// hidden (alpha 0) it paints like the original; taps, semantics and paint
/// transforms follow the offset exactly as the translation did.
///
/// It falls back to the original opacity layer, until the step comes to
/// rest, when the image could hide a change or not land on the pixel grid:
/// the content repaints or is laid out again mid-move, it contains layers of
/// its own (a repaint boundary, an opacity...), whose updates would not reach
/// this object, or the transform to the screen is not a plain translation
/// (then scaled by the device pixel ratio).
class _SnapshotStep extends SingleChildRenderObjectWidget {
  const _SnapshotStep({
    required this.progress,
    required this.offset,
    required this.devicePixelRatio,
    required super.child,
  });

  /// Curved progress of the step: its opacity; `1 - progress` of [offset] is
  /// its horizontal shift.
  final Animation<double> progress;

  /// Signed distance the step sits at when fully hidden.
  final double offset;
  final double devicePixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSnapshotStep(
    progress: progress,
    offset: offset,
    devicePixelRatio: devicePixelRatio,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSnapshotStep renderObject,
  ) {
    renderObject
      ..progress = progress
      ..offset = offset
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderSnapshotStep extends RenderProxyBox {
  _RenderSnapshotStep({
    required Animation<double> progress,
    required double offset,
    required double devicePixelRatio,
  }) : _progress = progress,
       _offset = offset,
       _devicePixelRatio = devicePixelRatio {
    _readProgress();
  }

  /// Ink of the content may reach outside its box (display numerals with a
  /// line height under 1): the image covers this margin around it.
  static const double _margin = 32;

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (value == _progress) return;
    if (attached) _progress.removeListener(_onProgress);
    _progress = value;
    if (attached) _progress.addListener(_onProgress);
    _onProgress();
  }

  double _offset;
  set offset(double value) {
    if (value == _offset) return;
    _offset = value;
    _onProgress();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _dropImage();
    _markSelf();
  }

  int _alpha = 255;
  double _dx = 0;

  /// The image of the content while the step moves, and the local rect it
  /// covers.
  ui.Image? _image;
  Rect? _imageRect;

  /// The content changed (or cannot be imaged) during this move: it is
  /// painted live under an opacity layer until the step comes to rest.
  bool _live = false;

  /// This object is marking itself (a new alpha or offset), not its content.
  bool _markingSelf = false;

  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle<OpacityLayer>();

  bool get _atRest => _alpha == 0 || (_alpha == 255 && _dx == 0);

  /// The values of the original `FadeTransition` and `Transform.translate`.
  void _readProgress() {
    final t = _progress.value;
    _alpha = ui.Color.getAlphaFromOpacity(t);
    _dx = (1 - t) * _offset;
  }

  void _onProgress() {
    final oldAlpha = _alpha;
    final oldDx = _dx;
    _readProgress();
    if (_alpha == oldAlpha && _dx == oldDx) return;
    // Composited while visible, like the original `FadeTransition`.
    if ((oldAlpha > 0) != (_alpha > 0)) markNeedsCompositingBitsUpdate();
    if (oldAlpha == 0 || _alpha == 0 || _dx != oldDx) {
      markNeedsSemanticsUpdate();
    }
    if (_atRest) {
      _dropImage();
      _live = false;
    }
    _markSelf();
  }

  void _markSelf() {
    _markingSelf = true;
    markNeedsPaint();
    _markingSelf = false;
  }

  void _dropImage() {
    _image?.dispose();
    _image = null;
    _imageRect = null;
  }

  @override
  void markNeedsPaint() {
    // A repaint that does not come from this object is a change of the
    // content (or of its layout): the image would hide it.
    if (!_markingSelf && _image != null) {
      _dropImage();
      _live = true;
    }
    super.markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => child != null && _alpha > 0;

  @override
  bool get alwaysNeedsCompositing => child != null && _alpha > 0;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(_onProgress);
    _onProgress();
  }

  @override
  void detach() {
    _progress.removeListener(_onProgress);
    _dropImage();
    super.detach();
  }

  @override
  void dispose() {
    _dropImage();
    _opacityLayer.layer = null;
    super.dispose();
  }

  @override
  bool paintsChild(RenderBox child) => _alpha > 0;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final child = this.child;
    if (child != null && _alpha != 0) visitor(child);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_dx, 0, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: Offset(_dx, 0),
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || _alpha == 0) {
      _opacityLayer.layer = null;
      return;
    }
    final shift = Offset(_dx, 0);
    if (_alpha == 255) {
      _opacityLayer.layer = null;
      context.paintChild(child, offset + shift);
      return;
    }
    if (!_live && _paintImage(context, offset)) {
      _opacityLayer.layer = null;
      return;
    }
    _live = true;
    _opacityLayer.layer = context.pushOpacity(
      offset,
      _alpha,
      (context, offset) => context.paintChild(child, offset + shift),
      oldLayer: _opacityLayer.layer,
    );
  }

  /// Draws the image of the content (taken on the first call of the move)
  /// on the physical pixel grid; false when it cannot.
  bool _paintImage(PaintingContext context, Offset offset) {
    if (size.isEmpty) return false;
    final ratio = _devicePixelRatio;
    // Local to global logical pixels (what `getTransformTo(null)` gives: the
    // view's scale by the device pixel ratio is not part of it) must be a
    // plain translation; then local to physical pixels is that translation
    // and the scale by the ratio, so the image (rendered at that ratio) maps
    // 1:1 onto the physical pixels.
    final toScreen = getTransformTo(null);
    final m = toScreen.storage;
    final plain =
        m[1] == 0 &&
        m[2] == 0 &&
        m[3] == 0 &&
        m[4] == 0 &&
        m[6] == 0 &&
        m[7] == 0 &&
        m[15] == 1 &&
        (m[0] - 1).abs() < 1e-6 &&
        (m[5] - 1).abs() < 1e-6;
    if (!plain) return false;
    var image = _image;
    var rect = _imageRect;
    if (image == null || rect == null) {
      // The image's corner goes on a physical pixel of the step's place at
      // rest: the content is rendered with the same subpixel phase as when
      // it is painted live, so the image without offset is the content at
      // rest, and nothing jumps when the step gets there.
      final margin = (Offset.zero & size).inflate(_margin);
      final corner =
          MatrixUtils.transformPoint(toScreen, margin.topLeft) * ratio;
      final phase = Offset(
        corner.dx - corner.dx.floorToDouble(),
        corner.dy - corner.dy.floorToDouble(),
      );
      rect = margin.shift(-phase / ratio);
      image = _takeImage(rect, ratio);
      if (image == null) return false;
      _image = image;
      _imageRect = rect;
    }
    // Snaps the image's origin to a physical pixel: drawn 1:1 it is the
    // content as rendered offscreen, not resampled. The rounding is done in
    // physical pixels, so the step moves by whole physical pixels.
    final local = rect.topLeft + Offset(_dx, 0);
    final screen = MatrixUtils.transformPoint(toScreen, local) * ratio;
    final snap = Offset(
      (screen.dx.roundToDouble() - screen.dx) / ratio,
      (screen.dy.roundToDouble() - screen.dy) / ratio,
    );
    final destination = Rect.fromLTWH(
      offset.dx + local.dx + snap.dx,
      offset.dy + local.dy + snap.dy,
      image.width / ratio,
      image.height / ratio,
    );
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    context.canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()
        ..color = ui.Color.fromARGB(_alpha, 0, 0, 0)
        ..filterQuality = FilterQuality.low,
    );
    return true;
  }

  /// The content rendered into an image of [rect] (local), or null when it
  /// holds layers of its own: their updates would not reach this object.
  ui.Image? _takeImage(Rect rect, double ratio) {
    final layer = OffsetLayer();
    final context = _ImageContext(layer, rect);
    context.paintChild(child!, Offset.zero);
    context.finish();
    final first = layer.firstChild;
    final flat =
        first == null || (first is PictureLayer && first.nextSibling == null);
    final image = flat ? layer.toImageSync(rect, pixelRatio: ratio) : null;
    layer.dispose();
    return image;
  }
}

/// Painting context of the image of a [_RenderSnapshotStep]: it ends the
/// recording, so the picture is in its layer before the image is taken.
class _ImageContext extends PaintingContext {
  _ImageContext(super.containerLayer, super.estimatedBounds);

  void finish() => stopRecordingIfNeeded();
}
