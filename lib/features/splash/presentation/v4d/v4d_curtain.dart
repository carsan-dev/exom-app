import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_scene.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_timeline.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The rest of the V4d opening, played in the root overlay over Inicio once
/// the splash has handed off (gates resolved, valid session, destination
/// Inicio). It keeps the splash's clock ([origin]), so its first frame is
/// the splash's next one; it publishes the opening in [V4dHandoff] for
/// Inicio's scale and the header landing, and removes itself ([onDone]) when
/// Inicio is usable or on a tap (a tap jumps to the end).
///
/// r3 (D3-Q6): without [openAt] the X stays opaque over Inicio, which is
/// being built under it, until Inicio has painted content
/// ([V4dHandoff.inicioContent]) or [V4dTimeline.contentCap] ms have passed
/// since [readyAt] ([V4dTimeline.inicioOpeningStart]); then the opening plays
/// with its usual length. r4 (D3-Q8): in reduced motion the fade waits in
/// the same way ([V4dTimeline.reducedInicioFadeStart]).
///
/// r4 (D3-Q9): with [content] [V4dWindowContent.login] it plays the opening
/// onto the login instead, from a fixed [openAt]; it does not publish
/// anything to Inicio ([V4dHandoff.current] stays null) and Inicio is never
/// built.
class V4dCurtain extends StatefulWidget {
  const V4dCurtain({
    super.key,
    required this.origin,
    required this.startAt,
    required this.readyAt,
    this.openAt,
    required this.centre,
    required this.reduced,
    required this.entrySkipped,
    required this.slowStart,
    required this.onDone,
    this.content = V4dWindowContent.inicio,
  }) : assert(content != V4dWindowContent.neutral),
       assert(
         content == V4dWindowContent.inicio || (openAt != null && !reduced),
       );

  /// Frame time stamp of the splash's first frame.
  final Duration origin;

  /// Splash time (ms) at the hand-off: shown until the first own frame.
  final double startAt;

  /// Splash time (ms) at which the gates resolved (`t_ready`).
  final double readyAt;

  /// Start of the opening (reduced motion: start of the fade), in ms; null:
  /// it waits for Inicio's content (D3-Q6).
  final double? openAt;
  final Offset centre;
  final bool reduced;
  final bool entrySkipped;
  final bool slowStart;
  final VoidCallback onDone;

  /// What is mounted under the curtain: Inicio or, D3-Q9, the login.
  final V4dWindowContent content;

  @override
  State<V4dCurtain> createState() => _V4dCurtainState();
}

class _V4dCurtainState extends State<V4dCurtain>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _layouts = V4dLayoutCache();
  late double _time = widget.startAt;
  late double? _openAt = widget.openAt;

  /// Splash time of the frame on which Inicio painted content.
  double? _contentAt;
  bool _finished = false;

  double get _end =>
      widget.reduced ? V4dTimeline.reducedFade : V4dTimeline.usable;

  @override
  void initState() {
    super.initState();
    V4dHandoff.inicioContent.addListener(_onInicioContent);
    _onInicioContent();
    _resolveOpening();
    _publish();
    _ticker.start();
  }

  /// Runs at the end of the frame that painted Inicio's content, whose time
  /// is [_time].
  void _onInicioContent() {
    if (V4dHandoff.inicioContent.value) _contentAt ??= _time;
  }

  void _resolveOpening() {
    _openAt ??= widget.reduced
        ? V4dTimeline.reducedInicioFadeStart(
            ready: widget.readyAt,
            content: _contentAt,
            now: _time,
          )
        : V4dTimeline.inicioOpeningStart(
            ready: widget.readyAt,
            content: _contentAt,
            now: _time,
            entrySkipped: widget.entrySkipped,
          );
  }

  void _publish() {
    // Only Inicio follows the opening (scale, header landing).
    if (widget.content != V4dWindowContent.inicio) return;
    final open = _openAt;
    V4dHandoff.current.value = open == null
        ? V4dOpening.waiting(centre: widget.centre, reduced: widget.reduced)
        : V4dOpening(
            elapsed: _time - open,
            centre: widget.centre,
            reduced: widget.reduced,
          );
  }

  void _onTick(Duration elapsed) {
    if (_finished) return;
    final stamp = SchedulerBinding.instance.currentFrameTimeStamp;
    _time = (stamp - widget.origin).inMicroseconds / 1000;
    _resolveOpening();
    final open = _openAt;
    if (open != null && _time - open >= _end) {
      _finish();
      return;
    }
    _publish();
    setState(() {});
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _ticker.stop();
    V4dHandoff.clear();
    widget.onDone();
  }

  @override
  void dispose() {
    V4dHandoff.inicioContent.removeListener(_onInicioContent);
    _ticker.dispose();
    if (!_finished) V4dHandoff.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _openAt;
    final Widget scene;
    if (widget.reduced) {
      final o = open == null ? -1.0 : _time - open;
      scene = V4dReducedScene(
        fade: V4dTimeline.progress(o, 0, V4dTimeline.reducedFade),
        slowStart: false,
        content: widget.content,
        onTap: _finish,
      );
    } else {
      final l10n = AppLocalizations.of(context);
      scene = LayoutBuilder(
        builder: (context, constraints) => V4dScene(
          layout: _layouts.resolve(
            size: constraints.biggest,
            brightness: Theme.of(context).brightness,
            textScaler: MediaQuery.textScalerOf(context),
            welcome: [l10n.splashWelcomeFirst, l10n.splashWelcomeSecond],
            baseStyle: DefaultTextStyle.of(context).style,
          ),
          time: _time,
          openAt: open,
          entrySkipped: widget.entrySkipped,
          slowStart: widget.slowStart,
          content: widget.content,
          onTap: _finish,
        ),
      );
    }
    // Inicio (or the login) is not usable yet: its semantics stay behind the
    // curtain.
    return BlockSemantics(
      child: Material(type: MaterialType.transparency, child: scene),
    );
  }
}
