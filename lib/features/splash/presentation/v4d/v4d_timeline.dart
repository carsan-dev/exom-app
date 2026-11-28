import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Timeline of V4d «La X de la palabra» (L5-D3; sketch `m10-arranque.html`,
/// objects `C`, `USABLE` and `R` of the V4d engine). Every time is in ms
/// from the splash's first frame; `o` is ms since the opening started.
///
/// * Entry 0–~420: the symbol travels from where the bootstrap screen left
///   it (D3-Q4) while «EXOM» and the welcome rise.
/// * Rest until [rest] (660).
/// * Opening, destination onboarding or locked account: starts when the
///   gates are resolved (`t_ready`); if that is before [rest], what is left
///   of the entry and the rest is skipped (case (2) of the contract).
/// * Opening, destination login (r4, D3-Q9): the login is mounted under the
///   opaque X [handOffOtherDestination] ms after `t_ready` (as the splash
///   always left) and the X opens onto it with the opening of Inicio and no
///   wait for content, starting so that it begins to empty on the frame
///   after the login is mounted ([loginOpeningStart]); usable [usable] ms
///   after the opening starts.
/// * Opening, destination Inicio (r3, D3-Q6, replaces case (2) there): Inicio
///   is built under the opaque X at `t_ready` and the opening starts when it
///   has painted content, at the latest [contentCap] ms after `t_ready`, and
///   never before [rest] unless a tap ended the entry
///   ([inicioOpeningStart]). Inicio is usable [usable] ms after the opening
///   starts: `max(1450, t_open + 790)`.
/// * Inside the opening (r3, D3-Q7): the X stays filled and still while the
///   ink fades ([inkFade]), then grows ([growStart]–[grow]) and empties from
///   its centre as it starts to grow ([empty] ms).
/// * Reduced motion ([reducedHold], [reducedFade]): fixed lockup and a
///   120 ms fade from `max(600, t_ready)`. With destination Inicio (r4,
///   D3-Q8) the fade also waits for Inicio's content, at the latest
///   [contentCap] ms after `t_ready` ([reducedInicioFadeStart]).
abstract final class V4dTimeline {
  /// Entry curve of the sketch (`E`), the same as the sheets'.
  static const Curve enter = Cubic(0.22, 0.75, 0.18, 1);

  /// Rise of the symbol, the word and each welcome line (`C.sym[2]`).
  static const double rise = 360;

  /// The welcome rises 40 ms after the word, its lines 20 ms apart.
  static const double welcomeDelay = 40;
  static const double welcomeStagger = 20;

  /// End of the entry (the second welcome line lands).
  static const double entryEnd = welcomeDelay + welcomeStagger + rise;

  /// End of the rest: nominal start of the opening (`C.open[0]`).
  static const double rest = 660;

  /// Symbol, word and welcome scale 1 → 1.04 and fade out at once; the X
  /// stays filled and still meanwhile (D3-Q7).
  static const double inkFade = 160;

  /// The X starts to grow (and to empty) once the ink has faded (D3-Q7; it
  /// grew from 0 before r3).
  static const double growStart = inkFade;

  /// The X grows (expo-in) from [growStart] until, at [grow] ms into the
  /// opening (unchanged), the window is larger than the screen.
  static const double grow = 440;

  /// The X empties from the centre outwards over [empty] ms from
  /// [growStart], while it starts to grow (D3-Q7).
  static const double empty = 100;

  /// End of the emptying: from here only the rim of the window is left.
  static const double emptyEnd = growStart + empty;

  /// Inicio, mounted behind, scales 1.06 → 1 from the X centre.
  static const double inicioScale = 680;

  /// Inicio usable after the opening starts: 1000 + 150 + 300 − 660.
  static const double usable = 790;

  /// The header logo fades in (landing) 440 ms into the opening.
  static const double landingDelay = 440;
  static const double landingFade = 120;

  /// Destination other than Inicio: the splash leaves [handOffOtherDestination]
  /// ms after `t_ready`, the former exit time. Onboarding and locked account:
  /// the window opens on a neutral background at `t_ready`. Login (D3-Q9):
  /// the login is mounted under the X at that moment ([loginOpeningStart]).
  static const double handOffOtherDestination = 650;

  /// Reduced motion (`R = {hold: 600, fade: 120}`).
  static const double reducedHold = 600;
  static const double reducedFade = 120;

  /// After this time without resolved gates the splash shows the slow-start
  /// icon and phrase.
  static const double slowStart = 2000;

  /// Start of the opening for gates resolved at [ready] ms, destination other
  /// than Inicio.
  static double openingStart(double ready) => ready;

  /// D3-Q6: longest wait for Inicio's content after `t_ready`.
  static const double contentCap = 600;

  /// D3-Q6: start of the opening with destination Inicio, for gates resolved
  /// at [ready] ms and Inicio's content painted at [content] ms (null: not
  /// yet), seen at [now] ms; null while it still has to wait. It is
  /// `min(content, ready + contentCap)`, and never before [rest] unless
  /// [entrySkipped] (a tap ended the entry and the rest).
  static double? inicioOpeningStart({
    required double ready,
    required double? content,
    required double now,
    required bool entrySkipped,
  }) {
    final trigger = _inicioTrigger(ready: ready, content: content, now: now);
    if (trigger == null) return null;
    return entrySkipped ? trigger : math.max(rest, trigger);
  }

  /// `min(content, ready + contentCap)` once known at [now]; null before.
  static double? _inicioTrigger({
    required double ready,
    required double? content,
    required double now,
  }) {
    final cap = ready + contentCap;
    if (content != null && content < cap) return content;
    if (now >= cap) return cap;
    return null;
  }

  /// D3-Q9: start of the opening onto the login, mounted under the opaque X
  /// at [mountAt] ms: `max(rest, mountAt - growStart)`, so the X starts to
  /// empty no earlier than the frame after the login is there. With the
  /// login mounted at `t_ready + handOffOtherDestination` it is
  /// `max(660, t_ready + 490)`.
  static double loginOpeningStart(double mountAt) =>
      math.max(rest, mountAt - growStart);

  /// Reduced motion: start of the fade for gates resolved at [ready] ms,
  /// destination other than Inicio.
  static double reducedFadeStart(double ready) => math.max(reducedHold, ready);

  /// D3-Q8: reduced motion, destination Inicio: start of the fade for gates
  /// resolved at [ready] ms and Inicio's content painted at [content] ms
  /// (null: not yet), seen at [now] ms; null while it still has to wait. It
  /// is `max(reducedHold, min(content, ready + contentCap))`.
  static double? reducedInicioFadeStart({
    required double ready,
    required double? content,
    required double now,
  }) {
    final trigger = _inicioTrigger(ready: ready, content: content, now: now);
    return trigger == null ? null : math.max(reducedHold, trigger);
  }

  /// Scale of the X [o] ms into the opening: 1 until [growStart], then
  /// expo-in up to [maxScale] at [grow].
  static double growScale(double o, double maxScale) {
    final f = progress(o, growStart, grow - growStart);
    return 1 + (maxScale - 1) * (math.pow(2, 10 * f) - 1) / 1023;
  }

  /// Emptying ratio of the X [o] ms into the opening: 0 (filled) until
  /// [growStart], then ease-out cubic to 1 at [emptyEnd].
  static double holeRatio(double o) {
    final x = progress(o, growStart, empty);
    return 1 - math.pow(1 - x, 3).toDouble();
  }

  /// Progress 0..1 of a step that starts at [start] and lasts [duration].
  static double progress(double t, double start, double duration) =>
      ((t - start) / duration).clamp(0.0, 1.0);
}
