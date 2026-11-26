import 'dart:ui' as ui;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:exom_app/core/widgets/exom_launch_symbol.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_geometry.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_timeline.dart';
import 'package:exom_app/features/splash/presentation/v4d/x_glyph.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Colour of the X (fill and rim of the window): lime in dark, carbon in
/// light like the X of [ExomWordmark] (D3-Q3; the sketch had lime with an
/// olive rim in light).
Color v4dXInk(ThemeData theme) {
  final palette =
      theme.extension<ExomThemePalette>() ??
      (theme.brightness == Brightness.dark
          ? AppTheme.dark.extension<ExomThemePalette>()!
          : AppTheme.light.extension<ExomThemePalette>()!);
  return theme.brightness == Brightness.dark
      ? palette.data
      : palette.textPrimary;
}

/// Where everything of the V4d scene sits for one screen (sketch `geo` and
/// the top of `run`): the lockup «a» (symbol left of «EXOM») across the width
/// with 20 dp margins, the welcome under it and the X window on the X of the
/// word. The block (lockup and welcome) is centred vertically.
@immutable
class V4dLayout {
  const V4dLayout._({
    required this.size,
    required this.em,
    required this.rowTop,
    required this.symbolRest,
    required this.bootstrapSymbol,
    required this.wordOrigin,
    required this.window,
    required this.maxScale,
    required this.maskBottom,
    required this.riseDistance,
    required this.welcomeTop,
    required this.welcomeFontSize,
    required this.slowTop,
  });

  static const double margin = 20;

  /// Sketch: the welcome starts 30 px under the baseline of «EXOM».
  static const double welcomeGap = 30;

  /// Welcome type: Barlow Condensed 800, 60 px, line height .95.
  static const double welcomeSize = 60;
  static const double welcomeLineHeight = 0.95;
  static const double welcomeLetterSpacingEm = -0.02;

  final Size size;

  /// Font size of «EXOM» (the lockup em).
  final double em;
  final double rowTop;
  final Rect symbolRest;
  final Rect bootstrapSymbol;
  final Offset wordOrigin;
  final V4dXWindow window;
  final double maxScale;

  /// Bottom edge of the mask the word (and its X) rises behind.
  final double maskBottom;
  final double riseDistance;
  final double welcomeTop;
  final double welcomeFontSize;
  final double slowTop;

  Offset get xCentre => window.centre;

  static TextStyle wordStyle(double em) => TextStyle(
    fontFamily: ExomBrandLogo.fontFamily,
    fontWeight: FontWeight.w800,
    fontSize: em,
    height: 1.0,
    letterSpacing: em * ExomBrandLogo.letterSpacingEm,
  );

  static TextStyle welcomeStyle(double fontSize) => TextStyle(
    fontFamily: AppTheme.displayFontFamily,
    fontWeight: FontWeight.w800,
    fontSize: fontSize,
    height: welcomeLineHeight,
    letterSpacing: fontSize * welcomeLetterSpacingEm,
  );

  static TextPainter _paint(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
    maxLines: 1,
  )..layout();

  /// Computes the layout for [size]; [welcome] are the two welcome lines (any
  /// case: they are measured upper case, as painted) and [textScaler] the
  /// system text scale, which the welcome follows (the lockup does not, as in
  /// [ExomBrandLogo]). [baseStyle] is the inherited [DefaultTextStyle] the
  /// painted texts merge with (its leading distribution moves the baseline),
  /// so the window sits exactly on the X of [ExomWordmark].
  factory V4dLayout.compute({
    required Size size,
    required Brightness brightness,
    required TextScaler textScaler,
    required List<String> welcome,
    TextStyle baseStyle = const TextStyle(),
  }) {
    final available = size.width - 2 * margin;
    final probe = _paint(
      ExomBrandLogo.wordmark,
      baseStyle.merge(wordStyle(100)),
    );
    final wordEm = probe.width / 100;
    probe.dispose();
    final em =
        available /
        (ExomBrandLogo.symbolWidthEm + ExomBrandLogo.gapEm + wordEm);
    final word = _paint(ExomBrandLogo.wordmark, baseStyle.merge(wordStyle(em)));
    final baseline = word.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final xBox = word
        .getBoxesForSelection(
          const TextSelection(baseOffset: 1, extentOffset: 2),
        )
        .first;
    word.dispose();

    // Welcome: follows the text scale but never wider than the margins.
    var welcomeFontSize = textScaler.scale(welcomeSize);
    var widest = 0.0;
    for (final line in welcome) {
      final p = _paint(
        line.toUpperCase(),
        baseStyle.merge(welcomeStyle(welcomeFontSize)),
      );
      if (p.width > widest) widest = p.width;
      p.dispose();
    }
    if (widest > available) welcomeFontSize *= available / widest;
    final welcomeHeight = welcome.length * welcomeFontSize * welcomeLineHeight;

    final blockHeight = baseline + welcomeGap + welcomeHeight;
    final rowTop = (size.height - blockHeight) / 2;
    final symbolW = em * ExomBrandLogo.symbolWidthEm;
    final symbolH = em * ExomBrandLogo.symbolHeightEm;
    final symbolRest = Rect.fromLTWH(
      margin,
      rowTop + (em - symbolH) / 2,
      symbolW,
      symbolH,
    );
    final wordOrigin = Offset(
      margin + symbolW + em * ExomBrandLogo.gapEm,
      rowTop,
    );
    final unit = em / xGlyphUnitsPerEm;
    final xOrigin = Offset(wordOrigin.dx + xBox.left, rowTop + baseline);
    final centre = Offset(
      xOrigin.dx + xGlyphCentre.dx * unit,
      xOrigin.dy - xGlyphCentre.dy * unit,
    );
    final window = V4dXWindow(
      centre: centre,
      unit: unit,
      rim: V4dXWindow.rimFor(brightness),
    );
    final welcomeTop = rowTop + baseline + welcomeGap;
    return V4dLayout._(
      size: size,
      em: em,
      rowTop: rowTop,
      symbolRest: symbolRest,
      // Where the native splash and the bootstrap screen leave the symbol;
      // V4d starts with it exactly there (D3-Q4).
      bootstrapSymbol: ExomLaunchSymbol.rectIn(size),
      wordOrigin: wordOrigin,
      window: window,
      maxScale: window.solveMaxScale(size),
      maskBottom: rowTop + em,
      riseDistance: em + 2,
      welcomeTop: welcomeTop,
      welcomeFontSize: welcomeFontSize,
      slowTop: welcomeTop + welcomeHeight + 16,
    );
  }
}

/// Keeps the last [V4dLayout] and recomputes it only when its inputs change
/// (the max scale search is not per-frame work).
class V4dLayoutCache {
  Object? _key;
  V4dLayout? _layout;

  V4dLayout resolve({
    required Size size,
    required Brightness brightness,
    required TextScaler textScaler,
    required List<String> welcome,
    TextStyle baseStyle = const TextStyle(),
  }) {
    final key = (
      size,
      brightness,
      textScaler.scale(V4dLayout.welcomeSize),
      welcome.join('\n'),
      baseStyle,
    );
    if (key != _key || _layout == null) {
      _key = key;
      _layout = V4dLayout.compute(
        size: size,
        brightness: brightness,
        textScaler: textScaler,
        welcome: welcome,
        baseStyle: baseStyle,
      );
    }
    return _layout!;
  }
}

/// What fills the window of the X once it empties.
enum V4dWindowContent {
  /// Inicio is mounted under the curtain: the window is transparent.
  inicio,

  /// The login is mounted under the curtain (D3-Q9): the window is
  /// transparent; Inicio is not built.
  login,

  /// Any other destination: a neutral background (Inicio is not built).
  neutral,
}

/// One frame of V4d. Pure function of its fields: the splash and the curtain
/// that keeps playing over Inicio draw the same picture for the same time.
class V4dScene extends StatelessWidget {
  const V4dScene({
    super.key,
    required this.layout,
    required this.time,
    required this.openAt,
    required this.entrySkipped,
    required this.slowStart,
    required this.content,
    this.onTap,
  });

  static const slowStartKey = ValueKey<String>('splash-slow-start');

  final V4dLayout layout;

  /// ms since the splash's first frame.
  final double time;

  /// Start of the opening (ms), null while the gates are pending.
  final double? openAt;

  /// A tap ended the entry early: the lockup is in its rest pose.
  final bool entrySkipped;
  final bool slowStart;
  final V4dWindowContent content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final open = openAt;
    final o = open == null ? -1.0 : time - open;
    final opening = o >= 0;
    // The entry is skipped once the opening starts (case (2)) or on a tap.
    final e = entrySkipped || opening ? V4dTimeline.entryEnd : time;
    final rise = V4dTimeline.progress(e, 0, V4dTimeline.rise);
    final riseEased = V4dTimeline.enter.transform(rise);
    final entryRunning = rise < 1;

    final inkP = opening
        ? V4dTimeline.enter.transform(
            V4dTimeline.progress(o, 0, V4dTimeline.inkFade),
          )
        : 0.0;
    final s = opening ? V4dTimeline.growScale(o, layout.maxScale) : 1.0;
    final r = opening ? V4dTimeline.holeRatio(o) : 0.0;
    // D3-Q7: filled while the ink fades, emptied while it starts to grow.
    final fillVisible = !opening || o < V4dTimeline.emptyEnd;
    final window = layout.window;
    final hole = r > 0 ? window.hole(r, s) : null;

    // Symbol: from the bootstrap box along an arc to its place in the
    // lockup (D3-Q4).
    final from = layout.bootstrapSymbol.center;
    final to = layout.symbolRest.center;
    final control = Offset(to.dx, from.dy);
    final k = riseEased;
    final along =
        from * ((1 - k) * (1 - k)) + control * (2 * (1 - k) * k) + to * (k * k);
    final symbolScale = ui.lerpDouble(
      layout.bootstrapSymbol.height / layout.symbolRest.height,
      1,
      k,
    )!;
    final wordShift = layout.riseDistance * (1 - riseEased);
    final wordOpacity = (riseEased / 0.12).clamp(0.0, 1.0);

    final ink = Opacity(
      opacity: 1 - inkP,
      child: Transform(
        transform: scaleAboutMatrix(layout.xCentre, 1 + 0.04 * inkP),
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: layout.symbolRest,
              child: Transform.translate(
                offset: along - to,
                child: Transform.scale(
                  scale: symbolScale,
                  child: ExomBrandSymbol(
                    height: layout.symbolRest.height,
                    excludeSemantics: true,
                    // D3-E1: the first frames draw the bootstrap screen's
                    // symbol, already decoded, while this one decodes.
                    placeholderBuilder: (_) => ExomLaunchSymbolPicture(
                      height: layout.symbolRest.height,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: layout.maskBottom,
              child: ClipRect(
                clipBehavior: entryRunning ? Clip.hardEdge : Clip.none,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: layout.wordOrigin.dx,
                      top: layout.wordOrigin.dy + wordShift,
                      child: Opacity(
                        opacity: wordOpacity,
                        child: ExomWordmark(height: layout.em),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: V4dLayout.margin,
              right: V4dLayout.margin,
              top: layout.welcomeTop,
              child: _Welcome(
                first: l10n.splashWelcomeFirst,
                second: l10n.splashWelcomeSecond,
                fontSize: layout.welcomeFontSize,
                time: e,
                firstColor: palette.textPrimary,
                secondColor: palette.data,
              ),
            ),
            if (slowStart)
              Positioned(
                left: V4dLayout.margin,
                right: V4dLayout.margin,
                top: layout.slowTop,
                child: V4dSlowStart(
                  key: slowStartKey,
                  label: l10n.splashSlowStart,
                ),
              ),
          ],
        ),
      ),
    );

    final xInk = v4dXInk(theme);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Skipping is a visual shortcut: it is not offered as an action, so the
      // lockup and the welcome stay separate nodes for screen readers.
      excludeFromSemantics: true,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (content == V4dWindowContent.neutral)
            ColoredBox(color: palette.background),
          ClipPath(
            clipper: _WindowClipper(hole),
            clipBehavior: hole == null ? Clip.none : Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: palette.background),
                ink,
              ],
            ),
          ),
          ClipRect(
            clipper: _MaskClipper(layout.maskBottom),
            clipBehavior: entryRunning ? Clip.hardEdge : Clip.none,
            child: Transform.translate(
              offset: Offset(0, wordShift),
              child: Opacity(
                opacity: wordOpacity,
                child: CustomPaint(
                  painter: _XPainter(
                    outer: window.outer(s),
                    inner: window.inner(s),
                    hole: hole,
                    fill: fillVisible,
                    color: xInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.first,
    required this.second,
    required this.fontSize,
    required this.time,
    required this.firstColor,
    required this.secondColor,
  });

  final String first;
  final String second;
  final double fontSize;
  final double time;
  final Color firstColor;
  final Color secondColor;

  Widget _line(String text, Color color, double start) {
    final p = V4dTimeline.enter.transform(
      V4dTimeline.progress(time, start, V4dTimeline.rise),
    );
    final lineHeight = fontSize * V4dLayout.welcomeLineHeight;
    return ClipRect(
      clipBehavior: p < 1 ? Clip.hardEdge : Clip.none,
      child: Transform.translate(
        offset: Offset(0, 1.3 * lineHeight * (1 - p)),
        child: Opacity(
          opacity: (p / 0.12).clamp(0.0, 1.0),
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
            style: V4dLayout.welcomeStyle(fontSize).copyWith(color: color),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$first $second',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _line(first, firstColor, V4dTimeline.welcomeDelay),
          _line(
            second,
            secondColor,
            V4dTimeline.welcomeDelay + V4dTimeline.welcomeStagger,
          ),
        ],
      ),
    );
  }
}

/// Slow start (> 2 s): cloud icon and phrase in the secondary colour, no
/// lime, nothing animates (d-acceso.html «Arranque lento»).
class V4dSlowStart extends StatelessWidget {
  const V4dSlowStart({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final iconSize = MediaQuery.textScalerOf(context).scale(18);
    return Semantics(
      liveRegion: true,
      container: true,
      label: label,
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(ExomIcons.syncing, size: iconSize, color: palette.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reduced motion: the lockup fixed at the centre over the background; the
/// fade (to Inicio or to the neutral background) is [fade] 0..1.
class V4dReducedScene extends StatelessWidget {
  const V4dReducedScene({
    super.key,
    required this.fade,
    required this.slowStart,
    required this.content,
    this.onTap,
  });

  /// Reduced lockup size (sketch `.dx-rd .lockup`, 56 px).
  static const double lockupHeight = 56;

  final double fade;
  final bool slowStart;
  final V4dWindowContent content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final scene = LayoutBuilder(
      builder: (context, constraints) {
        final centreY = constraints.maxHeight / 2;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: palette.background),
            Opacity(
              opacity: content == V4dWindowContent.neutral ? 1 - fade : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Center(child: ExomBrandLogo(height: lockupHeight)),
                  if (slowStart)
                    Positioned(
                      left: V4dLayout.margin,
                      right: V4dLayout.margin,
                      top: centreY + lockupHeight / 2 + 24,
                      child: Center(
                        child: IntrinsicWidth(
                          child: V4dSlowStart(
                            key: V4dScene.slowStartKey,
                            label: l10n.splashSlowStart,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Skipping is a visual shortcut: it is not offered as an action, so the
      // lockup and the welcome stay separate nodes for screen readers.
      excludeFromSemantics: true,
      onTap: onTap,
      child: content == V4dWindowContent.inicio
          ? Opacity(opacity: 1 - fade, child: scene)
          : scene,
    );
  }
}

/// Clips to everything but the hole (screen rectangle plus the hole, even
/// odd); no hole, no clip.
class _WindowClipper extends CustomClipper<Path> {
  _WindowClipper(this.hole);

  final List<Offset>? hole;

  @override
  Path getClip(Size size) {
    final rect = (Offset.zero & size).inflate(20);
    final h = hole;
    return evenOddPath([
      [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft],
      ?h,
    ]);
  }

  @override
  bool shouldReclip(_WindowClipper oldClipper) => oldClipper.hole != hole;
}

/// The mask the word rises behind: everything above [bottom].
class _MaskClipper extends CustomClipper<Rect> {
  _MaskClipper(this.bottom);

  final double bottom;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-1e4, -1e4, 1e4, bottom);

  @override
  bool shouldReclip(_MaskClipper oldClipper) => oldClipper.bottom != bottom;
}

/// The X: rim between the outer and inner contours, and the fill between
/// the inner contour and the hole while the X is still emptying.
class _XPainter extends CustomPainter {
  _XPainter({
    required this.outer,
    required this.inner,
    required this.hole,
    required this.fill,
    required this.color,
  });

  final List<Offset> outer;
  final List<Offset> inner;
  final List<Offset>? hole;
  final bool fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    // One path (rim and fill together while the X empties), so no
    // antialiasing seam shows along the inner contour.
    final h = hole;
    canvas.drawPath(evenOddPath(fill ? [outer, ?h] : [outer, inner]), paint);
  }

  @override
  bool shouldRepaint(_XPainter oldDelegate) =>
      oldDelegate.outer != outer ||
      oldDelegate.inner != inner ||
      oldDelegate.hole != hole ||
      oldDelegate.fill != fill ||
      oldDelegate.color != color;
}
