import 'dart:math' as math;

import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_app_bar.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// «Sesión hecha» milestone (L5-E6a; sketch `e-migradas.html`, frame `f-fin`;
/// plan decision L5-D22).
///
/// The training detail pushes it (a local route, no router path) only once the
/// server has confirmed the session completion. It is celebration and summary
/// with data the detail already has: the session name, its exercises and its
/// planned sets, and the confirmed state. It never shows or asks for the RPE or
/// the note (they are asked before completing, in the closing sheet).
///
/// Leaving it — «Volver a Inicio», the close icon or the system back — runs
/// [onContinue] once (the detail passes today's navigation to Inicio). If the
/// account changed while it was open ([isSameSession] is false), it closes
/// without running [onContinue].
///
/// It enters with the app's push transition (M1) and plays the milestone
/// animation once (L5-E6b, plan §8 c, sketch `e-migradas.html` demo (a)):
///
/// * 0-450 ms: a straight lime band of 96 dp crosses the whole page from the
///   bottom to the top and leaves ([ExomMotion.milestoneBand]); it never stays.
/// * 140-840 ms: the letters of «Sesión hecha.» rise .45 em and fade in, each
///   [ExomMotion.milestoneLetterStagger] after the previous one, 260 ms each.
/// * 540-780 ms: the session name rises 8 dp and fades in, as a block.
/// * 250-850 ms: the figures count up ([ExomMotion.milestoneCount]).
///
/// The whole of it lasts [ExomMotionSpec.milestoneTotal] (900 ms). The server
/// state, the close icon and the footer are in place from the first frame. A
/// touch anywhere jumps to the final pose, and the exits (button, close icon,
/// system back) only work from [ExomMotion.milestoneInteractiveAfter] (300 ms);
/// before, they jump to the final pose too. With reduced motion the body fades
/// in over 150 ms with the final values (no band, no letters, no count); the
/// exits keep the same 300 ms guard.
class TrainingMilestonePage extends StatefulWidget {
  const TrainingMilestonePage({
    super.key,
    required this.trainingName,
    required this.exercises,
    required this.sets,
    required this.isSameSession,
    required this.onContinue,
  });

  final String trainingName;

  /// Exercises of the session.
  final int exercises;

  /// Planned sets of the session (the detail's rule: circuit sets x rounds).
  final int sets;

  /// Whether the session that confirmed the completion is still the current
  /// one.
  final bool Function() isSameSession;

  /// Today's navigation after a confirmed completion.
  final VoidCallback onContinue;

  @override
  State<TrainingMilestonePage> createState() => _TrainingMilestonePageState();
}

class _TrainingMilestonePageState extends State<TrainingMilestonePage>
    with TickerProviderStateMixin {
  bool _leaving = false;

  /// The milestone animation, 0 to 1 over [ExomMotionSpec.milestoneTotal].
  ///
  /// `preserve`: with the platform's «remove animations» Flutter would scale a
  /// normal controller by 0.05 (150 ms fade down to ~7 ms).
  late final AnimationController _play = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );

  /// Runs once from the first frame and is never skipped: the exits work when
  /// it completes. `preserve` keeps the 300 ms in reduced motion too.
  late final AnimationController _gate = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );

  /// Motion chosen when the page opened; fixed for its lifetime so the tree
  /// never changes shape at the end of the animation.
  ExomMotionSpec? _spec;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final spec = ExomMotion.of(context);
    final current = _spec;
    if (current == null) {
      _spec = spec;
      _play.duration = spec.milestoneTotal;
      _gate.duration = ExomMotion.milestoneInteractiveAfter;
      _play.forward();
      _gate.forward();
    } else if (spec.isReduced && !current.isReduced) {
      // Reduced motion asked for mid-way: straight to the final pose.
      _skipToEnd();
    }
  }

  @override
  void dispose() {
    _play.dispose();
    _gate.dispose();
    super.dispose();
  }

  void _skipToEnd() {
    if (_play.value < 1) _play.value = 1;
  }

  void _leave() {
    if (_leaving) return;
    if (_gate.value < 1) {
      // Before 300 ms an exit only jumps to the final pose (a tap still in
      // flight from the previous screen must not leave the milestone).
      _skipToEnd();
      return;
    }
    _leaving = true;
    if (!widget.isSameSession()) {
      // Another account: close without navigating with the old session's data.
      Navigator.of(context).pop();
      return;
    }
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final reduced = _spec?.isReduced ?? true;
    // With reduced motion the values are final from the first frame.
    final play = reduced ? null : _play;
    final body = ListView(
      padding: const EdgeInsets.only(top: ExomSpacing.sm, bottom: 24),
      children: [
        // `.e-fin`: data rule across the top of the block, then the
        // headline and the server state.
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: palette.data, width: ExomRule.bar),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MilestoneHeadline(
                  first: l10n.trainingMilestoneTitle,
                  second: l10n.trainingMilestoneName(widget.trainingName),
                  play: play,
                ),
                const SizedBox(height: ExomSpacing.lg),
                // D19: the server confirmation is system state, text
                // colour with a check (never lime). Not animated.
                const ExomSyncStatus(state: ExomSyncState.confirmada),
              ],
            ),
          ),
        ),
        if (widget.exercises > 0) ...[
          const SizedBox(height: ExomSpacing.xxl),
          _MilestoneFigures(
            exercises: widget.exercises,
            sets: widget.sets,
            exercisesLabel: l10n.homeFigureExercises(widget.exercises),
            setsLabel: l10n.homeFigureSets(widget.sets),
            play: play,
          ),
        ],
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      // A touch anywhere jumps to the final pose; it does not take part in the
      // gesture arena, so the controls still get their own tap.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _skipToEnd(),
        child: CustomPaint(
          foregroundPainter: reduced
              ? null
              : _SweepPainter(play: _play, color: palette.limeFill),
          // The sweep repaints every frame; the boundary keeps the static
          // scaffold, bar and footer from being recorded again each time.
          child: RepaintBoundary(
            child: _buildScaffold(context, palette, l10n, body, reduced),
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ExomThemePalette palette,
    AppLocalizations l10n,
    Widget body,
    bool reduced,
  ) {
    return Scaffold(
      key: const Key('training-milestone'),
      backgroundColor: palette.background,
      appBar: ExomAppBar(
        leading: IconButton(
          key: const Key('training-milestone-close'),
          icon: Icon(ExomIcons.close, color: palette.textPrimary),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: _leave,
        ),
      ),
      // Reduced motion: the content fades in (the sketch's `.e-hscroll`);
      // the wrapper stays after the fade so the list is never rebuilt.
      body: reduced
          ? FadeTransition(
              key: const Key('training-milestone-reduced-fade'),
              opacity: _play,
              child: body,
            )
          : body,
      bottomNavigationBar: ExomPinnedFooter(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: ExomPrimaryButton(
          key: const Key('training-milestone-continue'),
          label: l10n.trainingMilestoneBackHome,
          trailingIcon: ExomIcons.forward,
          onPressed: _leave,
        ),
      ),
    );
  }
}

/// Timeline of the milestone animation in milliseconds from its start (sketch
/// `e-migradas.html`, demo (a), and plan §8 c). The band, the letter stagger,
/// the count and the total come from the `milestone*` constants of
/// [ExomMotion]; these are the sketch's offsets between them.
abstract final class _Timeline {
  /// The first letter of «Sesión hecha.» starts rising.
  static const double lettersStart = 140;

  /// Each letter rises in this long.
  static const double letter = 260;

  /// The last letter has landed by now, whatever the length of the line (the
  /// stagger shrinks for a line longer than the sketch's 12 letters).
  static const double lettersEnd = 840;

  /// The session name rises as a block from here, in [line].
  static const double secondLineStart = 540;
  static const double line = 240;

  /// The name rises this far (`mv-rise`).
  static const double lineRise = 8;

  /// The figures start counting.
  static const double countStart = 250;

  /// Letters of the first line rise .45 em.
  static const double letterRise = 0.45;

  static double ms(Duration duration) => duration.inMicroseconds / 1000;

  /// Progress, 0 to 1, of a step of [length] ms that starts at [start] ms,
  /// at [elapsed] ms of the animation.
  static double phase(double elapsed, double start, double length) {
    if (length <= 0) return elapsed >= start ? 1 : 0;
    return ((elapsed - start) / length).clamp(0.0, 1.0);
  }

  /// Milliseconds elapsed of the standard animation for [play].
  static double elapsed(Animation<double> play) =>
      play.value * ms(ExomMotion.milestoneMax);
}

/// Poster headline of the milestone (`.e-fin-h`): Barlow Condensed 800 in
/// upper case, «Sesión hecha.» in the text colour and the session name in the
/// data colour, at 66 and 58 like the sketch.
///
/// The first line never wraps: it shrinks to the width. The name wraps between
/// words and is never ellipsised; when its longest word does not fit the width
/// the whole line shrinks until it does, so no word is cut. Assistive
/// technology gets one header in the original case.
///
/// While [play] runs, the letters of the first line rise one after another and
/// the name rises as a block; at the end (or without [play]) it is the plain
/// headline.
class _MilestoneHeadline extends StatelessWidget {
  const _MilestoneHeadline({
    required this.first,
    required this.second,
    required this.play,
  });

  final String first;
  final String second;

  /// The milestone animation; null with reduced motion (final pose).
  final Animation<double>? play;

  static const double _firstSize = 66;
  static const double _secondSize = 58;

  /// Line height .95, not the sketch's .86: in Barlow Condensed 800 the
  /// capital diacritics reach .883 em (Á É Í Ó Ú), .899 (Ñ) and .92 (Ü), so
  /// at .86 the acute of «VÍDEO» touched the line above. .95 leaves .03 em of
  /// air over a Ü, the same line height as the ExomType two-line headlines.
  static TextStyle _style(double size, [Color? color]) => TextStyle(
    fontFamily: AppTheme.displayFontFamily,
    fontSize: size,
    fontWeight: FontWeight.w800,
    height: 0.95,
    letterSpacing: -0.02 * size,
    color: color,
  );

  /// Font size at which the widest of [words] fits [maxWidth], capped at
  /// [size].
  static double _fit(
    BuildContext context,
    Iterable<String> words,
    double size,
    double maxWidth,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final word in words) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: _style(size)),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    if (widest <= maxWidth || widest == 0) return size;
    // Half a pixel of slack so rounding never pushes the word past the edge.
    return size * math.max(0, maxWidth - 0.5) / widest;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final firstText = first.toUpperCase();
    final secondText = second.toUpperCase();
    return Semantics(
      header: true,
      // The app bar has no title: this names the route when it opens.
      namesRoute: true,
      label: '$first $second',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final firstSize = _fit(context, [firstText], _firstSize, width);
          final secondSize = _fit(
            context,
            secondText.split(RegExp(r'\s+')),
            _secondSize,
            width,
          );
          final firstStyle = _style(firstSize, palette.textPrimary);
          final firstLine = Text(
            firstText,
            maxLines: 1,
            softWrap: false,
            style: firstStyle,
          );
          final secondLine = Text(
            secondText,
            style: _style(secondSize, palette.data),
          );
          final animation = play;
          if (animation == null) {
            return _column(firstLine, secondLine);
          }
          final letters = _letterWindows(context, firstText, firstStyle);
          final rise =
              _Timeline.letterRise *
              MediaQuery.textScalerOf(context).scale(firstSize);
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              if (animation.value >= 1) {
                return _column(firstLine, secondLine);
              }
              final elapsed = _Timeline.elapsed(animation);
              final name = ExomMotion.sheetEnterCurve.transform(
                _Timeline.phase(
                  elapsed,
                  _Timeline.secondLineStart,
                  _Timeline.line,
                ),
              );
              return _column(
                _risingLetters(firstLine, letters, elapsed, rise),
                Transform.translate(
                  offset: Offset(0, _Timeline.lineRise * (1 - name)),
                  child: Opacity(opacity: name, child: secondLine),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Widget _column(Widget first, Widget second) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [first, second],
  );

  /// Horizontal window of each visible character of [text] as laid out by the
  /// first line's [Text]: from half way to the previous character to half way
  /// to the next one, so the windows cover the line exactly once (a glyph
  /// that overhangs its advance is still drawn whole).
  static List<(double, double)> _letterWindows(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      textHeightBehavior: DefaultTextStyle.of(context).textHeightBehavior,
      maxLines: 1,
    )..layout();
    final boxes = <(double, double)>[];
    var offset = 0;
    for (final character in text.characters) {
      final end = offset + character.length;
      if (character.trim().isNotEmpty) {
        final range = painter.getBoxesForSelection(
          TextSelection(baseOffset: offset, extentOffset: end),
        );
        if (range.isNotEmpty) {
          boxes.add((
            range.map((box) => box.left).reduce(math.min),
            range.map((box) => box.right).reduce(math.max),
          ));
        }
      }
      offset = end;
    }
    painter.dispose();
    final windows = <(double, double)>[];
    for (var i = 0; i < boxes.length; i++) {
      final left = i == 0
          ? double.negativeInfinity
          : (boxes[i - 1].$2 + boxes[i].$1) / 2;
      final right = i == boxes.length - 1
          ? double.infinity
          : (boxes[i].$2 + boxes[i + 1].$1) / 2;
      windows.add((left, right));
    }
    return windows;
  }

  /// [line] drawn once per letter window, each copy clipped to its window and
  /// rising on its own step, so the letters keep the exact layout (kerning
  /// and tracking) of the final line.
  static Widget _risingLetters(
    Text line,
    List<(double, double)> windows,
    double elapsed,
    double rise,
  ) {
    if (windows.isEmpty) return line;
    final count = windows.length;
    final stagger = count < 2
        ? 0.0
        : math.min(
            _Timeline.ms(ExomMotion.milestoneLetterStagger),
            (_Timeline.lettersEnd - _Timeline.lettersStart - _Timeline.letter) /
                (count - 1),
          );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < count; i++)
          _risingLetter(
            line,
            windows[i],
            ExomMotion.sheetEnterCurve.transform(
              _Timeline.phase(
                elapsed,
                _Timeline.lettersStart + i * stagger,
                _Timeline.letter,
              ),
            ),
            rise,
          ),
      ],
    );
  }

  static Widget _risingLetter(
    Text line,
    (double, double) window,
    double progress,
    double rise,
  ) {
    return Transform.translate(
      offset: Offset(0, rise * (1 - progress)),
      child: Opacity(
        opacity: progress,
        child: ClipRect(
          clipper: _LetterWindow(window.$1, window.$2),
          child: line,
        ),
      ),
    );
  }
}

/// Clips to a vertical strip from [left] to [right], unbounded vertically (the
/// display line has a height under 1, so its glyphs overflow its box).
class _LetterWindow extends CustomClipper<Rect> {
  const _LetterWindow(this.left, this.right);

  final double left;
  final double right;

  static const double _far = 100000;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    left.isFinite ? left : -_far,
    -_far,
    right.isFinite ? right : _far,
    _far,
  );

  @override
  bool shouldReclip(_LetterWindow oldClipper) =>
      oldClipper.left != left || oldClipper.right != right;
}

/// The two figures of the milestone (`.e-fin-cols`): exercises and planned
/// sets, counting up from 0 between 250 and 850 ms while [play] runs.
class _MilestoneFigures extends StatelessWidget {
  const _MilestoneFigures({
    required this.exercises,
    required this.sets,
    required this.exercisesLabel,
    required this.setsLabel,
    required this.play,
  });

  final int exercises;
  final int sets;
  final String exercisesLabel;
  final String setsLabel;

  /// The milestone animation; null with reduced motion (final values).
  final Animation<double>? play;

  Widget _columns(BuildContext context, double progress) {
    int at(int value) => progress >= 1 ? value : (value * progress).round();
    return ExomFigureColumns(
      items: [
        ExomFigure(
          value: formatFigure(context, at(exercises)),
          label: exercisesLabel,
        ),
        ExomFigure(value: formatFigure(context, at(sets)), label: setsLabel),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final animation = play;
    if (animation == null) return _columns(context, 1);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (animation.value >= 1) return _columns(context, 1);
        final count = _Timeline.phase(
          _Timeline.elapsed(animation),
          _Timeline.countStart,
          _Timeline.ms(ExomMotion.milestoneCount),
        );
        return _columns(
          context,
          ExomMotion.milestoneCountCurve.transform(count),
        );
      },
    );
  }
}

/// The sweep (`.e-sweep`): a straight lime band of 96 dp, full width, that
/// crosses the page from below its bottom edge to above its top edge in
/// [ExomMotion.milestoneBand] and leaves. It is the only large lime of the
/// milestone and never stays; it is horizontal (no crossed bands, L5-D11).
class _SweepPainter extends CustomPainter {
  _SweepPainter({required this.play, required this.color})
    : super(repaint: play);

  final Animation<double> play;
  final Color color;

  static const double band = 96;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = _Timeline.phase(
      _Timeline.elapsed(play),
      0,
      _Timeline.ms(ExomMotion.milestoneBand),
    );
    if (progress <= 0 || progress >= 1) return;
    final top =
        size.height +
        (-band - size.height) *
            ExomMotion.milestoneBandCurve.transform(progress);
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, band),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      oldDelegate.play != play || oldDelegate.color != color;
}
