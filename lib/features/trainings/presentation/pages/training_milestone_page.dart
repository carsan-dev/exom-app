import 'dart:math' as math;

import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
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
/// No motion of its own: the milestone animation (sweep, letters, figures) is
/// L5-E6b. It enters with the app's push transition (M1).
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

class _TrainingMilestonePageState extends State<TrainingMilestonePage> {
  bool _leaving = false;

  void _leave() {
    if (_leaving) return;
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
    final figures = [
      if (widget.exercises > 0) ...[
        ExomFigure(
          value: formatFigure(context, widget.exercises),
          label: l10n.exercises.toLowerCase(),
        ),
        ExomFigure(
          value: formatFigure(context, widget.sets),
          label: l10n.sets.toLowerCase(),
        ),
      ],
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        key: const Key('training-milestone'),
        backgroundColor: palette.background,
        appBar: GlassAppBar(
          leading: IconButton(
            key: const Key('training-milestone-close'),
            icon: Icon(ExomIcons.close, color: palette.textPrimary),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _leave,
          ),
        ),
        body: ListView(
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
                    ),
                    const SizedBox(height: ExomSpacing.lg),
                    // D19: the server confirmation is system state, text
                    // colour with a check (never lime).
                    const ExomSyncStatus(state: ExomSyncState.confirmada),
                  ],
                ),
              ),
            ),
            if (figures.isNotEmpty) ...[
              const SizedBox(height: ExomSpacing.xxl),
              ExomFigureColumns(items: figures),
            ],
          ],
        ),
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
      ),
    );
  }
}

/// Poster headline of the milestone (`.e-fin-h`): Barlow Condensed 800 in
/// upper case, «Sesión hecha.» in the text colour and the session name in the
/// data colour, at 66 and 58 like the sketch.
///
/// The first line never wraps: it shrinks to the width. The name wraps between
/// words and is never ellipsised; when its longest word does not fit the width
/// the whole line shrinks until it does, so no word is cut. Assistive
/// technology gets one header in the original case.
class _MilestoneHeadline extends StatelessWidget {
  const _MilestoneHeadline({required this.first, required this.second});

  final String first;
  final String second;

  static const double _firstSize = 66;
  static const double _secondSize = 58;

  static TextStyle _style(double size, [Color? color]) => TextStyle(
    fontFamily: AppTheme.displayFontFamily,
    fontSize: size,
    fontWeight: FontWeight.w800,
    height: 0.86,
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                firstText,
                maxLines: 1,
                softWrap: false,
                style: _style(firstSize, palette.textPrimary),
              ),
              Text(secondText, style: _style(secondSize, palette.data)),
            ],
          );
        },
      ),
    );
  }
}
