import 'package:exom_app/core/widgets/exom_large_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Distance the user must scroll toward the end, in one direction, before the
/// footer hides (L5-D63).
const double kExomScrollAwayFooterHideDistance = 8;

/// Show: slide up and fade in (L5-D63).
const Duration kExomScrollAwayFooterShow = Duration(milliseconds: 200);

/// Hide: slide down and fade out (L5-D63).
const Duration kExomScrollAwayFooterHide = Duration(milliseconds: 160);

/// Whether a pinned footer may scroll away in [context] (L5-D63): only with
/// large text ([kExomLargeTextScale]; below it the footer stays fixed, exactly
/// as before), and never with a screen reader (TalkBack/VoiceOver).
bool exomScrollAwayFooterEnabled(BuildContext context) =>
    exomIsLargeText(context) && !MediaQuery.accessibleNavigationOf(context);

/// Visibility of a pinned footer that hides while the user scrolls the body
/// toward its end and comes back when they scroll back (L5-D63).
///
/// Feed it the body's scroll notifications ([handleScrollNotification],
/// [handleMetricsNotification]). Only the user's own drags and flings move it
/// ([UserScrollNotification] direction): programmatic scrolls never hide the
/// footer. It shows again at the end of the content and when the content does
/// not scroll at all, so nothing stays out of reach.
class ExomScrollAwayFooterController extends ChangeNotifier
    implements ValueListenable<bool> {
  bool _visible = true;
  ScrollDirection _userDirection = ScrollDirection.idle;
  double _hideDistance = 0;

  /// Whether the footer is shown.
  @override
  bool get value => _visible;

  /// Shows the footer.
  void show() => _set(true);

  void _set(bool visible) {
    if (visible) _hideDistance = 0;
    if (_visible == visible) return;
    _visible = visible;
    notifyListeners();
  }

  /// Handles a notification of the body's scroll view. Never stops it.
  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final metrics = notification.metrics;
    if (notification is UserScrollNotification) {
      _userDirection = notification.direction;
      _hideDistance = 0;
      if (_userDirection == ScrollDirection.forward) _set(true);
      return false;
    }
    if (_atEndOrStatic(metrics)) {
      _set(true);
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (_userDirection == ScrollDirection.reverse && delta > 0) {
        _hideDistance += delta;
        if (_hideDistance >= kExomScrollAwayFooterHideDistance) _set(false);
      } else if (_userDirection == ScrollDirection.forward && delta < 0) {
        _set(true);
      }
    }
    return false;
  }

  /// Handles a change of the body's content or viewport size: a body that no
  /// longer scrolls, or that now ends where it is, shows the footer.
  bool handleMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth == 0 && _atEndOrStatic(notification.metrics)) {
      _set(true);
    }
    return false;
  }

  static bool _atEndOrStatic(ScrollMetrics metrics) =>
      metrics.hasContentDimensions &&
      (metrics.maxScrollExtent <= metrics.minScrollExtent ||
          metrics.extentAfter < 0.5);
}

/// Pinned footer that slides down and fades out when [controller] hides it
/// (L5-D63): shows in [kExomScrollAwayFooterShow] (ease out cubic), hides in
/// [kExomScrollAwayFooterHide] (ease in cubic), instantly when the platform
/// asks for no animations. While hidden it takes no taps and is out of the
/// semantics tree. It moves only by translation, so its slot keeps its height
/// and the body's bottom padding keeps room for it.
class ExomScrollAwayFooter extends StatefulWidget {
  const ExomScrollAwayFooter({
    super.key,
    required this.controller,
    required this.child,
  });

  final ExomScrollAwayFooterController controller;
  final Widget child;

  @override
  State<ExomScrollAwayFooter> createState() => _ExomScrollAwayFooterState();
}

class _ExomScrollAwayFooterState extends State<ExomScrollAwayFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: kExomScrollAwayFooterShow,
    reverseDuration: kExomScrollAwayFooterHide,
    value: widget.controller.value ? 1 : 0,
  );

  // Hiding runs the controller backwards: the flipped ease-in reads as ease in
  // cubic over time.
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic.flipped,
  );

  late final Animation<Offset> _slide = _curve.drive(
    Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVisibility);
  }

  @override
  void didUpdateWidget(ExomScrollAwayFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onVisibility);
      widget.controller.addListener(_onVisibility);
      _onVisibility();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVisibility);
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _onVisibility() {
    if (!mounted) return;
    final visible = widget.controller.value;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = visible ? 1 : 0;
    } else if (visible) {
      _animation.forward();
    } else {
      _animation.reverse();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.controller.value;
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(opacity: _curve, child: widget.child),
        ),
      ),
    );
  }
}
