import 'dart:async';
import 'dart:math' as math;

import 'package:exom_app/core/navigation/page_aware_bottom_sheet.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Top radius of every EXOM sheet (plan §6).
const double kExomSheetRadius = 20;

/// Opens an EXOM modal bottom sheet (sketch «A · Hoja de registro», motion
/// card §8b) and returns its result.
///
/// The sheet is an [ExomSheetRoute] pushed through [pushPageAwareRoute], the
/// same page-aware mechanism as `showPageAwareModalBottomSheet`: it closes
/// itself when the router location changes. On top of that:
///
/// * **Motion** ([ExomMotion.of]): slides in over 280 ms on
///   `Cubic(.22,.75,.18,1)` and out over 200 ms on `Cubic(.4,0,1,1)`; the
///   scrim fades on its own 200 ms linear timing. Closing mid-way reverses
///   from the current position. With reduced motion there is no slide: the
///   panel and the scrim fade over 120 ms in and out.
/// * **Drag** ([enableDrag]): the sheet follows the finger 1:1 from its drag
///   handle and from any part of the panel that does not scroll; content that
///   overflows and scrolls keeps its own vertical drag, so such a sheet is
///   dragged from the handle. Releasing past 30 % of the sheet height or with
///   a downward fling faster than [ExomSheetRoute.flingVelocity] closes it;
///   otherwise it returns in 200 ms. With reduced motion the drag still
///   follows the finger and closes; it snaps back without animation.
/// * **Dismissal** ([isDismissible]): scrim tap, system/predictive back,
///   Escape and the iOS accessibility escape close the sheet. With
///   `isDismissible: false` none of them does (the content must pop it).
/// * **Layout**: `panel` surface, top radius 20, 1 px `rule` outline, no
///   shadow, a 40x4 handle; content in a scroll view capped at 90 % of the
///   screen height, above the keyboard and the bottom safe area. Builders
///   return plain (non-scrolling) content.
/// * **Semantics**: modal barrier labelled `sheetBarrierA11y`; the panel
///   scopes and names the route.
/// * **Repeated triggers**: while a sheet opened from the same [context] is
///   still open or closing (until its subtree is disposed), another call
///   opens nothing: a repeated trigger is ignored and resolves to null. Only
///   the original caller receives the sheet's result. Callers should still
///   disable their trigger while awaiting.
///
/// The returned future completes only after the sheet has been fully removed
/// and its subtree disposed (the "wait until destroyed" contract of
/// `showSetPerformanceSheet`), so the caller cannot replace or pop its page
/// while the sheet still owns inherited dependencies or text inputs. Disable
/// with [waitForDisposal].
Future<T?> showExomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool waitForDisposal = true,
}) {
  if (_openSheets[context] != null) {
    // Still open or closing: ignore the repeated trigger.
    return Future<T?>.value();
  }
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final route = ExomSheetRoute<T>(
    builder: builder,
    motion: ExomMotion.of(context),
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    barrierLabel: AppLocalizations.of(context).sheetBarrierA11y,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
  );

  Future<T?> run() async {
    try {
      final result = await pushPageAwareRoute<T>(
        context,
        route,
        useRootNavigator: useRootNavigator,
      );
      if (waitForDisposal) await route.disposed;
      return result;
    } finally {
      _openSheets[context] = null;
    }
  }

  final future = run();
  _openSheets[context] = future;
  return future;
}

final Expando<Future<Object?>> _openSheets = Expando('exom-open-sheets');

/// Modal route behind [showExomSheet]. Public for tests and for the scrim
/// colour; open sheets with [showExomSheet].
class ExomSheetRoute<T> extends PopupRoute<T> {
  ExomSheetRoute({
    required this.builder,
    required this.motion,
    required this.isDismissible,
    required this.enableDrag,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final WidgetBuilder builder;
  final ExomMotionSpec motion;
  final bool isDismissible;
  final bool enableDrag;
  final CapturedThemes capturedThemes;

  /// Scrim colour (same as the Material modal sheet default).
  static const Color scrimColor = Colors.black54;

  /// Fraction of the sheet height past which releasing a drag closes it.
  static const double closeThreshold = 0.3;

  /// Downward release speed (logical px/s) that closes regardless of the
  /// distance; the same threshold as the Material bottom sheet.
  static const double flingVelocity = 700;

  /// Duration of the return to the open position after a short drag.
  static const Duration settleDuration = Duration(milliseconds: 200);

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => isDismissible;

  @override
  Color get barrierColor => scrimColor;

  @override
  Duration get transitionDuration => motion.sheetEnter;

  @override
  Duration get reverseTransitionDuration => motion.sheetExit;

  @override
  RoutePopDisposition get popDisposition =>
      isDismissible ? super.popDisposition : RoutePopDisposition.doNotPop;

  final Completer<void> _disposed = Completer<void>();
  bool _frameMounted = false;

  /// Completes once the route is removed and the sheet subtree disposed.
  Future<void> get disposed => _disposed.future;

  void _completeDisposed() {
    if (!_disposed.isCompleted) _disposed.complete();
  }

  // Own scrim timing (200 ms linear, 120 ms reduced), independent of the
  // sheet's 280/200 ms.
  AnimationController? _scrim;

  // Curve that maps the route controller to the visible fraction of the
  // sheet. Switched (keeping the visible position) when the motion changes:
  // enter -> exit on pop, linear while dragging, enter while settling.
  Curve _curve = Curves.linear;

  /// Visible fraction of the sheet, 0 (hidden) to 1 (open).
  double get shownFraction => _curve.transform(controller!.value);

  void _setShown(double shown, Curve curve) {
    _curve = curve;
    controller!.value = _invert(curve, shown.clamp(0.0, 1.0));
  }

  static double _invert(Curve curve, double y) {
    if (y <= 0) return 0;
    if (y >= 1) return 1;
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 32; i++) {
      final mid = (lo + hi) / 2;
      if (curve.transform(mid) < y) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  @override
  void install() {
    super.install();
    _curve = motion.sheetSlides ? motion.sheetEnterCurve : Curves.linear;
    _scrim = AnimationController(vsync: navigator!, duration: motion.scrim);
  }

  @override
  TickerFuture didPush() {
    _scrim!.forward();
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    if (motion.sheetSlides && controller != null) {
      // Reverse from wherever the sheet is now (mid-enter, mid-drag or
      // mid-settle) on the exit curve, without a jump.
      // The controller runs 1 -> 0, so the flipped curve makes the visible
      // motion an ease-in (slow start, fast end).
      _setShown(shownFraction, motion.sheetExitCurve.flipped);
    }
    _scrim?.reverse();
    return super.didPop(result);
  }

  @override
  void dispose() {
    _scrim?.dispose();
    _scrim = null;
    if (!_frameMounted) _completeDisposed();
    super.dispose();
  }

  @override
  Widget buildModalBarrier() {
    return AnimatedModalBarrier(
      color: _scrim!.drive(
        ColorTween(begin: scrimColor.withValues(alpha: 0), end: scrimColor),
      ),
      dismissible: barrierDismissible,
      semanticsLabel: barrierLabel,
      barrierSemanticsDismissible: semanticsDismissible,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return capturedThemes.wrap(
      _ExomSheetFrame(
        route: this,
        child: Builder(builder: builder),
      ),
    );
  }

  // Drag hooks used by the frame (standard motion only).

  void _beginDrag() {
    // Follow the finger 1:1 from the current visible position.
    _setShown(shownFraction, Curves.linear);
  }

  void _dragBy(double fraction) {
    controller!.value = (controller!.value - fraction).clamp(0.0, 1.0);
  }

  void _settle() {
    _setShown(shownFraction, motion.sheetEnterCurve);
    controller!.animateTo(1, duration: settleDuration);
  }
}

class _ExomSheetFrame extends StatefulWidget {
  const _ExomSheetFrame({required this.route, required this.child});

  final ExomSheetRoute<dynamic> route;
  final Widget child;

  @override
  State<_ExomSheetFrame> createState() => _ExomSheetFrameState();
}

class _ExomSheetFrameState extends State<_ExomSheetFrame> {
  final GlobalKey _panelKey = GlobalKey();

  // Reduced motion: the finger offset (no slide animation exists).
  final ValueNotifier<double> _reducedDrag = ValueNotifier<double>(0);

  // True between a drag start that this sheet accepted and its end/cancel.
  bool _dragging = false;

  // Net downward finger travel (logical px) of the current drag.
  double _dragTravel = 0;

  ExomSheetRoute<dynamic> get _route => widget.route;
  bool get _slides => _route.motion.sheetSlides;

  @override
  void initState() {
    super.initState();
    _route._frameMounted = true;
  }

  @override
  void dispose() {
    _reducedDrag.dispose();
    _route._completeDisposed();
    super.dispose();
  }

  double get _panelHeight {
    final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize && box.size.height > 0
        ? box.size.height
        : 1;
  }

  bool get _canDrag =>
      _route.enableDrag &&
      _route.isCurrent &&
      _route.animation!.status != AnimationStatus.reverse;

  void _onDragStart(DragStartDetails details) {
    if (!_canDrag) return;
    _dragging = true;
    _dragTravel = 0;
    if (_slides) _route._beginDrag();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging || !_canDrag) return;
    final delta = details.primaryDelta ?? 0;
    _dragTravel += delta;
    if (_slides) {
      _route._dragBy(delta / _panelHeight);
    } else {
      _reducedDrag.value = (_reducedDrag.value + delta).clamp(
        0.0,
        _panelHeight,
      );
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    if (!_canDrag) return;
    final velocity = details.primaryVelocity ?? 0;
    // Downward distance travelled during this gesture (not the distance from
    // the fully open position, which a mid-enter grab would inflate).
    final dragged = _dragTravel / _panelHeight;
    final close =
        velocity > ExomSheetRoute.flingVelocity ||
        (velocity >= -ExomSheetRoute.flingVelocity &&
            dragged > ExomSheetRoute.closeThreshold);
    if (close) {
      Navigator.of(context).pop();
    } else if (_slides) {
      _route._settle();
    } else {
      _reducedDrag.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final media = MediaQuery.of(context);
    // 90 % of the space between the status bar and the keyboard; the
    // content scrolls beyond that.
    final maxHeight = math.max(
      0.0,
      (media.size.height - media.padding.top - media.viewInsets.bottom) * 0.9,
    );

    Widget panel = Material(
      key: const Key('exom-sheet-panel'),
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kExomSheetRadius),
        ),
        side: BorderSide(color: palette.borderSoft, width: 1),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Center(
                child: Container(
                  key: const Key('exom-sheet-handle'),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );

    panel = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: MaterialLocalizations.of(context).bottomSheetLabel,
      onDismiss: _route.isDismissible
          ? () => Navigator.of(context).maybePop()
          : null,
      child: panel,
    );

    panel = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onVerticalDragStart: _route.enableDrag ? _onDragStart : null,
      onVerticalDragUpdate: _route.enableDrag ? _onDragUpdate : null,
      onVerticalDragEnd: _route.enableDrag ? _onDragEnd : null,
      onVerticalDragCancel: _route.enableDrag
          ? () => _onDragEnd(DragEndDetails(primaryVelocity: 0))
          : null,
      child: ConstrainedBox(
        key: _panelKey,
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: panel,
      ),
    );

    if (_slides) {
      panel = AnimatedBuilder(
        animation: _route.animation!,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(0, 1 - _route.shownFraction),
          child: child,
        ),
        child: panel,
      );
    } else {
      // Reduced motion: the whole panel (surface, outline and content) fades
      // as one; nothing pops in before it.
      panel = FadeTransition(
        key: const Key('exom-sheet-fade'),
        opacity: _route.animation!,
        child: ValueListenableBuilder<double>(
          valueListenable: _reducedDrag,
          builder: (context, dy, child) =>
              Transform.translate(offset: Offset(0, dy), child: child),
          child: panel,
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: panel,
      ),
    );
  }
}
