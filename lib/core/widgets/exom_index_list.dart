import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:flutter/material.dart';

/// One destination of an [ExomIndexList].
@immutable
class ExomIndexItem {
  const ExomIndexItem({
    required this.title,
    this.icon,
    this.leading,
    this.selected = false,
    this.status,
    this.onTap,
    this.titleKey,
  });

  final String title;

  /// Key of the painted title `Text` (the tutorial locates it by key).
  final Key? titleKey;

  /// Trailing icon; a chevron by default when [onTap] is set.
  final IconData? icon;

  /// Leading icon that replaces the position number («01»…) in its column
  /// (22, secondary colour; primary when [selected]). Null keeps the number.
  final IconData? leading;

  /// Current destination: primary-colour icon, a 2 px primary rule on the left
  /// edge of the entry, announced as selected. Needs no [leading] to be set,
  /// but is only drawn by the icon variant.
  final bool selected;

  /// Short status after the title (e.g. «3 nuevas»), DM Sans 14 / 600.
  final String? status;
  final VoidCallback? onTap;
}

/// Numbered index (`.x-ixs > .x-ix`): destinations that should not look like
/// settings. Each entry shows its position as «01», «02»… ([ExomIndexNumber] in
/// the data colour), the title in the section style (Barlow Condensed 800,
/// 22, painted upper case; read in its original case), an optional status and
/// a trailing icon.
///
/// Entries are at least 60 tall, padded 10/20, with a 1 px `rule` on top; the
/// list closes with a bottom rule. Each entry is one merged node, a button when
/// tappable; pressed and disabled behave as [ExomRowSurface].
///
/// A list placed right under a block that already closes with a rule sets
/// [joinsPrevious] to drop the top rule of its first entry and share that
/// rule instead of opening an empty strip between two rules.
class ExomIndexList extends StatelessWidget {
  const ExomIndexList({
    super.key,
    required this.items,
    this.joinsPrevious = false,
  });

  final List<ExomIndexItem> items;

  /// True when the list directly follows a block that ends with a rule.
  final bool joinsPrevious;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.exomPalette.borderSoft,
            width: ExomRule.hairline,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _IndexEntry(
              n: i + 1,
              item: items[i],
              topRule: i > 0 || !joinsPrevious,
            ),
        ],
      ),
    );
  }
}

class _IndexEntry extends StatelessWidget {
  const _IndexEntry({
    required this.n,
    required this.item,
    required this.topRule,
  });

  final int n;
  final ExomIndexItem item;
  final bool topRule;

  // `.x-ix .x-no`: .75em of the 22 px title, 0.2em down, 1.6em wide.
  static const double _numberSize = 22 * 0.75;

  static double _textWidth(
    String text,
    TextStyle style,
    TextScaler scaler,
    BuildContext context,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Width of the widest word of [text], so it is never split.
  static double _longestWordWidth(
    String text,
    TextStyle style,
    TextScaler scaler,
    BuildContext context,
  ) {
    var longest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      longest = math.max(longest, _textWidth(word, style, scaler, context));
    }
    return longest.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final scaler = MediaQuery.textScalerOf(context);
    final icon = item.icon ?? (item.onTap == null ? null : ExomIcons.next);
    final status = item.status;
    final leading = item.leading;
    final selected = item.selected && leading != null;
    final entry = MergeSemantics(
      child: Semantics(
        button: item.onTap != null,
        selected: selected ? true : null,
        child: ExomRowSurface(
          key: const Key('exom-index-entry'),
          onTap: item.onTap,
          minHeight: 60,
          topRule: topRule,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final titleText = item.title.toUpperCase();
              final titleStyle = ExomType.section.copyWith(
                color: palette.textPrimary,
              );
              final numberStyle = ExomIndexNumber.style(
                palette.data,
              ).copyWith(fontSize: _numberSize);
              final numberText = ExomIndexNumber.format(n);
              // With an icon the column is fixed (22 + 2 x 2, `.x-ix .lead`):
              // it does not grow with the text scale.
              final numberWidth = leading != null
                  ? 26.0
                  : math.max(
                      scaler.scale(_numberSize * 1.6),
                      _textWidth(numberText, numberStyle, scaler, context),
                    );
              final iconWidth = icon == null ? 0.0 : 14.0 + 22;
              // Inline, title and status share what is left equally (the
              // status only takes what it needs, the title keeps the half).
              final inlineTitleWidth =
                  (constraints.maxWidth - 14 - iconWidth) / 2 -
                  numberWidth -
                  14;
              // The title has priority: the status goes under it as soon as
              // the inline column would break a word of the title.
              final stacked =
                  status != null &&
                  inlineTitleWidth <
                      _longestWordWidth(titleText, titleStyle, scaler, context);
              final title = Semantics(
                label: item.title,
                excludeSemantics: true,
                child: Text(titleText, key: item.titleKey, style: titleStyle),
              );
              final statusText = status == null
                  ? null
                  : Text(
                      status,
                      textAlign: stacked ? TextAlign.start : TextAlign.end,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: palette.textSecondary,
                      ),
                    );
              return Row(
                children: [
                  // Number and title share the top edge (`align-self:
                  // flex-start` of the number); the rest is centred.
                  Expanded(
                    child: Row(
                      crossAxisAlignment: leading != null
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        if (leading != null)
                          // The icon takes the number's column, centred in
                          // the entry (`.x-ix .lead`).
                          SizedBox(
                            width: numberWidth,
                            child: Center(
                              child: Icon(
                                leading,
                                size: 22,
                                color: selected
                                    ? palette.textPrimary
                                    : palette.textSecondary,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.only(
                              top: scaler.scale(_numberSize * 0.2),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: numberWidth,
                              ),
                              child: Text(numberText, style: numberStyle),
                            ),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: stacked
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    title,
                                    const SizedBox(height: 4),
                                    ?statusText,
                                  ],
                                )
                              : title,
                        ),
                      ],
                    ),
                  ),
                  if (statusText != null && !stacked) ...[
                    const SizedBox(width: 14),
                    // Flexible so a long status wraps instead of overflowing.
                    Flexible(child: statusText),
                  ],
                  if (icon != null) ...[
                    const SizedBox(width: 14),
                    Icon(icon, size: 22, color: palette.textPrimary),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
    if (!selected) return entry;
    return Stack(
      children: [
        entry,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 2,
          // Decoration only: the tap on its 2 px reaches the entry.
          child: IgnorePointer(
            child: ColoredBox(
              key: const Key('exom-index-selected-rule'),
              color: palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
