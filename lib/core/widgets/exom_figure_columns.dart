import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart' show exomFigureSpans;
import 'package:flutter/material.dart';

/// One figure of an [ExomFigureColumns]: an already formatted [value] (L5-D5),
/// an optional [unit] and the [label] that names it.
@immutable
class ExomFigure {
  const ExomFigure({required this.value, required this.label, this.unit});

  final String value;
  final String label;
  final String? unit;

  @override
  bool operator ==(Object other) =>
      other is ExomFigure &&
      other.value == value &&
      other.label == label &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(value, label, unit);
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
class ExomFigureColumns extends StatelessWidget {
  const ExomFigureColumns({
    super.key,
    required this.items,
    this.numbered = true,
  });

  final List<ExomFigure> items;

  /// Shows an [ExomIndexNumber] («01», «02»…) above each figure.
  final bool numbered;

  /// A figure may shrink to this fraction of its natural size inside a row.
  static const double _minFigureScale = 0.5;

  /// `.x-cols > div` paddings: first column 20 left, the others 14 left plus a
  /// 1 px rule; 12 right.
  static const double _padFirst = ExomSpacing.xl;
  static const double _padNext = 14;
  static const double _padEnd = ExomSpacing.md;

  /// `.x-cols-n`: 3.5 em of 16 px, height .85, tracking -.02 em.
  static TextStyle _figureStyle(Color color) => ExomType.section.copyWith(
    fontSize: 56,
    height: 0.85,
    letterSpacing: -1.12,
    color: color,
  );

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
    final labelStyle = Theme.of(context).textTheme.bodyMedium!;
    final figureStyle = _figureStyle(context.exomPalette.data);
    final column = maxWidth / items.length;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final inner =
          column -
          (i == 0 ? _padFirst : _padNext + ExomRule.hairline) -
          _padEnd;
      final figure = _measure(
        _figureSpan(item, figureStyle),
        scaler,
        direction,
      );
      if (figure * _minFigureScale > inner) return false;
      for (final word in item.label.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        if (_measure(
              TextSpan(text: word, style: labelStyle),
              scaler,
              direction,
            ) >
            inner) {
          return false;
        }
      }
    }
    return true;
  }

  Widget _cell(
    BuildContext context,
    ExomFigure item,
    int index, {
    required EdgeInsetsGeometry padding,
    required BoxBorder? border,
  }) {
    final palette = context.exomPalette;
    final unit = item.unit;
    return DecoratedBox(
      decoration: BoxDecoration(border: border),
      child: Padding(
        padding: padding,
        child: Semantics(
          container: true,
          label: '${item.label}: ${item.value}${unit == null ? '' : ' $unit'}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (numbered) ...[
                ExomIndexNumber(index + 1),
                const SizedBox(height: 6),
              ],
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 56 * 0.025),
                  child: Text.rich(
                    _figureSpan(item, _figureStyle(palette.data)),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(item.label, style: Theme.of(context).textTheme.bodyMedium),
            ],
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
