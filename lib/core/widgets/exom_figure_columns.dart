import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart' show exomFigureSpans;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Colour of an [ExomFigure]: [data] (client data, the default) or [text]
/// (a reference such as «Última vez», sketch `.e-ref`).
enum ExomFigureTone { data, text }

/// Size of an [ExomFigure]: [s56] (`.x-cols-n`, the default) or [s64] (the
/// protagonist load, sketch `.e-load`, [ExomType.hero64]).
enum ExomFigureSize { s56, s64 }

/// One figure of an [ExomFigureColumns]: an already formatted [value] (L5-D5),
/// an optional [unit] and the [label] that names it.
///
/// L5-E5 (owner decision 2026-11-25), all optional and off by default: [tone],
/// [size], a [detail] line under the figure and a [semanticsLabel] that
/// replaces the default reading. An empty [value] with a [detail] paints no
/// figure, only the label and the detail («Sin datos anteriores»).
@immutable
class ExomFigure {
  const ExomFigure({
    required this.value,
    required this.label,
    this.unit,
    this.itemKey,
    this.tone = ExomFigureTone.data,
    this.size = ExomFigureSize.s56,
    this.detail,
    this.semanticsLabel,
  });

  final String value;
  final String label;
  final String? unit;

  /// Optional key of the column cell, for callers (and tests) that need to find
  /// one figure. It does not take part in equality.
  final Key? itemKey;

  final ExomFigureTone tone;
  final ExomFigureSize size;

  /// Line under the figure in the secondary text colour (DM Sans 14 / 1.4),
  /// e.g. «× 22,5 kg · RIR 2».
  final String? detail;

  /// What assistive technology reads for the cell. By default
  /// «label: value unit», followed by «, detail» when there is one.
  final String? semanticsLabel;

  bool get _paintsFigure => value.isNotEmpty || detail == null;

  @override
  bool operator ==(Object other) =>
      other is ExomFigure &&
      other.value == value &&
      other.label == label &&
      other.unit == unit &&
      other.tone == tone &&
      other.size == size &&
      other.detail == detail &&
      other.semanticsLabel == semanticsLabel;

  @override
  int get hashCode =>
      Object.hash(value, label, unit, tone, size, detail, semanticsLabel);
}

/// Figures in columns separated by hairlines (`.x-cols`, `.x-cols-n`): per
/// column an optional index «01» ([numbered]), the figure in the data colour
/// and its label in the secondary text colour.
///
/// All columns share the width equally. When a column cannot hold its content
/// at the current width and text size the widget stacks the figures in ONE
/// column, separated by hairlines. The decision is made by measuring the real
/// text (longest word of each label and the figure at the minimum size it may
/// shrink to), not from a fixed text scale: short labels keep the row where
/// long ones stack. A figure shrinks with `FittedBox(scaleDown)` to its column
/// (like the sketch's `min(3.5em, 46cqw)`), down to [_minFigureScale] of its
/// natural size before the row is given up.
///
/// With [labelsAbove] (L5-E5, `.x-k` of the active circuit and exercise) each
/// label is an [ExomKicker] above its figure; the [ExomFigure.detail], if any,
/// goes below the figure. In a row the label slots take the height of the
/// tallest label (a label that wraps does not push its neighbour's figure
/// down) and the figures share the real text baseline even at different
/// sizes (the row aligns on each figure's baseline, not on a computed offset).
class ExomFigureColumns extends StatelessWidget {
  const ExomFigureColumns({
    super.key,
    required this.items,
    this.numbered = true,
    this.alignLabels = false,
    this.labelsAbove = false,
  });

  final List<ExomFigure> items;

  /// Paints each label as an [ExomKicker] above its figure instead of below
  /// it. Off by default. The labels then already share one y in a row, so
  /// [alignLabels] has no effect.
  final bool labelsAbove;

  /// In a row, pins every label to the bottom of its cell so the labels share
  /// one y even when a wide figure shrinks to its column and ends up shorter
  /// than its neighbours. Off by default (the label follows its figure).
  final bool alignLabels;

  /// Shows an [ExomIndexNumber] («01», «02»…) above each figure.
  final bool numbered;

  /// A figure may shrink to this fraction of its natural size inside a row.
  static const double _minFigureScale = 0.5;

  /// `.x-cols > div` paddings: first column 20 left, the others 14 left plus a
  /// 1 px rule; 12 right.
  static const double _padFirst = ExomSpacing.xl;
  static const double _padNext = 14;
  static const double _padEnd = ExomSpacing.md;

  /// `.x-cols-n`: 3.5 em of 16 px, height .85, tracking -.02 em. [s64] is the
  /// protagonist load ([ExomType.hero64]).
  static TextStyle _figureStyle(
    Color color, [
    ExomFigureSize size = ExomFigureSize.s56,
  ]) => switch (size) {
    ExomFigureSize.s56 => ExomType.section.copyWith(
      fontSize: 56,
      height: 0.85,
      letterSpacing: -1.12,
      color: color,
    ),
    ExomFigureSize.s64 => ExomType.hero64.copyWith(color: color),
  };

  static Color _figureColor(ExomThemePalette palette, ExomFigure item) =>
      switch (item.tone) {
        ExomFigureTone.data => palette.data,
        ExomFigureTone.text => palette.textPrimary,
      };

  static TextStyle _detailStyle(ExomThemePalette palette) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 14,
    height: 1.4,
    color: palette.textSecondary,
  );

  static Iterable<String> _words(String text) =>
      text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);

  static InlineSpan _figureSpan(ExomFigure item, TextStyle style) {
    return TextSpan(
      style: style,
      children: exomFigureSpans(
        value: item.value,
        unit: item.unit,
        fontSize: style.fontSize!,
      ),
    );
  }

  double _measure(InlineSpan span, TextScaler scaler, TextDirection direction) {
    final painter = TextPainter(
      text: span,
      textScaler: scaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  bool _fitsInRow(BuildContext context, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final palette = context.exomPalette;
    final labelStyle = labelsAbove
        ? ExomType.kicker
        : Theme.of(context).textTheme.bodyMedium!;
    final detailStyle = _detailStyle(palette);
    final column = maxWidth / items.length;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final inner =
          column -
          (i == 0 ? _padFirst : _padNext + ExomRule.hairline) -
          _padEnd;
      if (item._paintsFigure) {
        final figure = _measure(
          _figureSpan(item, _figureStyle(palette.data, item.size)),
          scaler,
          direction,
        );
        if (figure * _minFigureScale > inner) return false;
      }
      final label = labelsAbove ? item.label.toUpperCase() : item.label;
      final words = [
        for (final word in _words(label))
          TextSpan(text: word, style: labelStyle),
        for (final word in _words(item.detail ?? ''))
          TextSpan(text: word, style: detailStyle),
      ];
      for (final word in words) {
        if (_measure(word, scaler, direction) > inner) return false;
      }
    }
    return true;
  }

  /// The figure of [item], scaled down to its column; its baseline is the
  /// baseline of the text (see [_ScaledBaseline]).
  Widget _figure(ExomThemePalette palette, ExomFigure item) {
    return _ScaledBaseline(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: _figureStyle(palette.data, item.size).fontSize! * 0.025,
          ),
          child: Text.rich(
            _figureSpan(
              item,
              _figureStyle(_figureColor(palette, item), item.size),
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }

  static String _semanticsOf(ExomFigure item) {
    final unit = item.unit;
    final detail = item.detail;
    final valueText = '${item.value}${unit == null ? '' : ' $unit'}';
    return item.semanticsLabel ??
        (item._paintsFigure
            ? '${item.label}: $valueText${detail == null ? '' : ', $detail'}'
            : '${item.label}: $detail');
  }

  /// A cell of the row with [labelsAbove]: the index and the label, at the top
  /// of the row, outside the figures' baseline alignment so every label shares
  /// one y. Read through the figure cell, so it is excluded from semantics.
  Widget _labelCell(ExomFigure item, int index, EdgeInsetsGeometry padding) {
    return ExcludeSemantics(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (numbered) ...[
              ExomIndexNumber(index + 1),
              const SizedBox(height: 6),
            ],
            ExomKicker(item.label),
          ],
        ),
      ),
    );
  }

  /// The figure (and its detail below) of a cell of the row with [labelsAbove].
  /// The row aligns these cells on the baseline of the figure's text; a cell
  /// without a figure has no baseline and stays at the top.
  Widget _figureCell(
    BuildContext context,
    ExomFigure item,
    EdgeInsetsGeometry padding,
  ) {
    final palette = context.exomPalette;
    final detail = item.detail;
    return KeyedSubtree(
      key: item.itemKey,
      child: Padding(
        padding: padding,
        child: Semantics(
          container: true,
          label: _semanticsOf(item),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item._paintsFigure) _figure(palette, item),
              if (detail != null) ...[
                if (item._paintsFigure) const SizedBox(height: 6),
                item._paintsFigure
                    ? Text(detail, style: _detailStyle(palette))
                    : IgnoreBaseline(
                        child: Text(detail, style: _detailStyle(palette)),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    ExomFigure item,
    int index, {
    required EdgeInsetsGeometry padding,
    required BoxBorder? border,
  }) {
    final palette = context.exomPalette;
    final detail = item.detail;
    final figure = _figure(palette, item);
    return KeyedSubtree(
      key: item.itemKey,
      child: DecoratedBox(
        decoration: BoxDecoration(border: border),
        child: Padding(
          padding: padding,
          child: Semantics(
            container: true,
            label: _semanticsOf(item),
            excludeSemantics: true,
            // With [alignLabels] the figure goes on top and the label is pinned
            // to the bottom: in a row every cell is stretched to the same height,
            // so the labels share one y. Stacked, the cell has no extra height
            // and this is the plain column.
            child: labelsAbove
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (numbered) ...[
                        ExomIndexNumber(index + 1),
                        const SizedBox(height: 6),
                      ],
                      ExomKicker(item.label),
                      if (item._paintsFigure) ...[
                        const SizedBox(height: 6),
                        figure,
                      ],
                      if (detail != null) ...[
                        const SizedBox(height: 6),
                        Text(detail, style: _detailStyle(palette)),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: alignLabels
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    mainAxisAlignment: alignLabels
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (numbered) ...[
                            ExomIndexNumber(index + 1),
                            const SizedBox(height: 6),
                          ],
                          if (item._paintsFigure) ...[
                            figure,
                            const SizedBox(height: 6),
                          ],
                          if (detail != null) ...[
                            Text(detail, style: _detailStyle(palette)),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final palette = context.exomPalette;
    final rule = BorderSide(
      color: palette.borderSoft,
      width: ExomRule.hairline,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: rule),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final row =
              items.length == 1 || _fitsInRow(context, constraints.maxWidth);
          if (!row) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++)
                  _cell(
                    context,
                    items[i],
                    i,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      _padFirst,
                      14,
                      _padEnd,
                      16,
                    ),
                    border: i == 0 ? null : Border(top: rule),
                  ),
              ],
            );
          }
          if (labelsAbove) {
            // Labels on top, then the figures on the real baseline of their
            // text (a figure cell's baseline is its text's): two rows, with
            // the hairlines drawn by a row of their own behind them.
            EdgeInsetsGeometry side(int i, double top, double bottom) =>
                EdgeInsetsDirectional.fromSTEB(
                  i == 0 ? _padFirst : _padNext,
                  top,
                  _padEnd,
                  bottom,
                );
            return Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: i == 0
                                  ? null
                                  : BorderDirectional(start: rule),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _labelCell(items[i], i, side(i, 14, 6)),
                          ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _figureCell(
                              context,
                              items[i],
                              side(i, 0, 16),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _cell(
                      context,
                      items[i],
                      i,
                      padding: EdgeInsetsDirectional.fromSTEB(
                        i == 0 ? _padFirst : _padNext,
                        14,
                        _padEnd,
                        16,
                      ),
                      border: i == 0 ? null : BorderDirectional(start: rule),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Wraps a figure scaled down by a [FittedBox] and reports the baseline of its
/// text scaled by the same factor. [FittedBox] reports the child's unscaled
/// baseline, so a figure that shrinks to its column would otherwise sit on a
/// different baseline than its neighbours.
class _ScaledBaseline extends SingleChildRenderObjectWidget {
  const _ScaledBaseline({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderScaledBaseline();
}

class _RenderScaledBaseline extends RenderProxyBox {
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final fitted = child;
    if (fitted is! RenderFittedBox) {
      return super.computeDistanceToActualBaseline(baseline);
    }
    final natural = fitted.child;
    final distance = fitted.getDistanceToActualBaseline(baseline);
    if (natural is! RenderBox || distance == null || natural.size.width == 0) {
      return distance;
    }
    return distance * fitted.size.width / natural.size.width;
  }

  /// The same scaled baseline in a dry pass: [RenderFittedBox] would report
  /// its child's unscaled one. The child is measured as [RenderFittedBox] lays
  /// it out (unconstrained) and scaled by the factor of the dry fitted size.
  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final fitted = child;
    if (fitted is! RenderFittedBox) {
      return super.computeDryBaseline(constraints, baseline);
    }
    final natural = fitted.child;
    if (natural is! RenderBox) {
      return super.computeDryBaseline(constraints, baseline);
    }
    const unconstrained = BoxConstraints();
    final distance = natural.getDryBaseline(unconstrained, baseline);
    final naturalWidth = natural.getDryLayout(unconstrained).width;
    if (distance == null || naturalWidth == 0) return distance;
    return distance * fitted.getDryLayout(constraints).width / naturalWidth;
  }
}
