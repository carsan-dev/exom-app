import 'dart:async';

import 'package:exom_app/features/splash/presentation/v4d/v4d_timeline.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The opening in progress, as Inicio sees it from under the splash.
@immutable
class V4dOpening {
  const V4dOpening({
    required this.elapsed,
    required this.centre,
    required this.reduced,
  });

  /// Inicio is mounted under the opaque X and the opening has not started:
  /// it waits for Inicio's content (D3-Q6).
  const V4dOpening.waiting({required this.centre, required this.reduced})
    : elapsed = double.negativeInfinity;

  /// ms since the opening started; negative while it has not started.
  final double elapsed;

  /// Centre of the X on screen (logical px), the origin of Inicio's scale.
  final Offset centre;

  /// Reduced motion: Inicio does not scale and the header logo is shown.
  final bool reduced;
}

/// Hand-off from the splash to Inicio (L5-D3, «Arquitectura»).
///
/// The splash publishes the opening here only after the gates are resolved
/// with a valid session and Inicio as the destination, right before it
/// navigates to Inicio; the curtain that keeps playing over Inicio updates it
/// every frame and clears it when Inicio is usable. Null at any other time,
/// so Inicio built later (or for any other reason) is never affected.
///
/// r3 (D3-Q6): the opening waits under the opaque X until Inicio has painted
/// content. Inicio's shell reports it ([watchInicioContent]); the curtain
/// reads [inicioContent].
abstract final class V4dHandoff {
  static final ValueNotifier<V4dOpening?> current = ValueNotifier(null);

  /// True while an opening is handed to Inicio.
  static bool get active => current.value != null;

  /// True once Inicio has painted content during the current hand-off.
  static final ValueNotifier<bool> inicioContent = ValueNotifier(false);

  /// Inicio's data has reached its widgets: it is reported at the end of the
  /// next frame, the one that paints it. Ignored outside a hand-off.
  static void reportInicioContent() {
    if (!active || inicioContent.value) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (active) inicioContent.value = true;
      }, debugLabel: 'V4dHandoff.inicioContent')
      ..ensureVisualUpdate();
  }

  /// Reports the first of Inicio's [states] for which [isContent] holds (see
  /// [reportInicioContent]). Only during a hand-off: otherwise [states] is
  /// not read and null is returned. Cancel the result when Inicio goes away.
  static StreamSubscription<S>? watchInicioContent<S>(
    Stream<S> Function() states,
    bool Function(S state) isContent,
  ) {
    if (!active) return null;
    late final StreamSubscription<S> subscription;
    subscription = states().listen((state) {
      if (!isContent(state)) return;
      subscription.cancel();
      reportInicioContent();
    });
    return subscription;
  }

  /// D3-Q9: true while the splash hands off to the login under its curtain
  /// (the X opens onto the login). The login route enters with no transition
  /// only then; Inicio is not involved ([current] stays null).
  static final ValueNotifier<bool> loginEntry = ValueNotifier(false);

  /// Ends a hand-off: no opening and no content reported.
  static void clear() {
    current.value = null;
    inicioContent.value = false;
    loginEntry.value = false;
  }

  @visibleForTesting
  static void reset() => clear();
}

/// Uniform scale by [scale] about [origin].
Matrix4 scaleAboutMatrix(Offset origin, double scale) =>
    Matrix4.translationValues(origin.dx, origin.dy, 0)
        .multiplied(Matrix4.diagonal3Values(scale, scale, 1))
        .multiplied(Matrix4.translationValues(-origin.dx, -origin.dy, 0));

/// Inicio behind the window: scales 1.06 → 1 from the X centre over the
/// first [V4dTimeline.inicioScale] ms of the opening. Always the same widget
/// tree (a [Transform]), so the end of the opening never rebuilds Inicio.
class V4dHomeEntrance extends StatelessWidget {
  const V4dHomeEntrance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V4dOpening?>(
      valueListenable: V4dHandoff.current,
      child: child,
      builder: (context, opening, child) {
        var transform = Matrix4.identity();
        if (opening != null && !opening.reduced) {
          final p = V4dTimeline.enter.transform(
            V4dTimeline.progress(opening.elapsed, 0, V4dTimeline.inicioScale),
          );
          final scale = 1.06 - 0.06 * p;
          final c = opening.centre;
          transform = scaleAboutMatrix(c, scale);
        }
        return Transform(transform: transform, child: child);
      },
    );
  }
}

/// Landing of the header logo: hidden until [V4dTimeline.landingDelay] ms
/// into the opening, then fades in over [V4dTimeline.landingFade] ms.
/// Always the same widget tree (an [Opacity]).
class V4dHeaderLanding extends StatelessWidget {
  const V4dHeaderLanding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V4dOpening?>(
      valueListenable: V4dHandoff.current,
      child: child,
      builder: (context, opening, child) {
        final opacity = opening == null || opening.reduced
            ? 1.0
            : V4dTimeline.progress(
                opening.elapsed,
                V4dTimeline.landingDelay,
                V4dTimeline.landingFade,
              );
        return Opacity(opacity: opacity, child: child);
      },
    );
  }
}
