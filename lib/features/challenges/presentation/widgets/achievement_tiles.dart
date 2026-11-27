import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// One achievement of [AchievementTiles].
class AchievementTileData {
  const AchievementTileData({
    required this.name,
    required this.unlocked,
    this.description = '',
  });

  final String name;

  /// How the achievement is earned; empty when the tile only shows the name.
  final String description;
  final bool unlocked;
}

/// Flat achievement tiles (`.x-tiles`): a grid of square tiles 2 dp apart.
/// Two columns when the longest word of the visible names and descriptions
/// fits the text width of a two-column tile, measured with the same styles and
/// the same text scaler; one column otherwise, so a word is never split
/// (L5-B2 round 3).
///
/// Unlocked: `raised` fill, the medal in the data colour and the name in the
/// text colour, weight 600. Locked: no fill, a 1 px rule outline, the lock and
/// the name in the secondary colour, weight 400. No radius, shadow or gold.
/// Each tile is at least 56 high; tiles of a row share its height. Names and
/// descriptions wrap and are never truncated: the description of a locked
/// achievement is the only place that says how to earn it. A locked tile is
/// announced as such.
class AchievementTiles extends StatelessWidget {
  const AchievementTiles({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<AchievementTileData> items;
  final EdgeInsetsGeometry padding;

  static const double gap = 2;
  static const double minTileHeight = 56;

  /// Space a tile takes beside its text: 12 dp of padding each side, the 20 dp
  /// icon and the 10 dp between icon and text.
  static const double tileChrome = 12 * 2 + 20 + 10;

  static TextStyle _nameStyle(bool unlocked) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 14,
    height: 1.25,
    fontWeight: unlocked ? FontWeight.w600 : FontWeight.w400,
  );

  static TextStyle _descriptionStyle() => const TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );

  /// Width of the longest word of the names and descriptions in [items].
  static double longestWord(
    List<AchievementTileData> items,
    TextScaler scaler,
  ) {
    var longest = 0.0;
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    for (final item in items) {
      for (final word in item.name.split(RegExp(r'\s+'))) {
        if (word.isNotEmpty) {
          longest = math.max(longest, measure(word, _nameStyle(item.unlocked)));
        }
      }
      for (final word in item.description.split(RegExp(r'\s+'))) {
        if (word.isNotEmpty) {
          longest = math.max(longest, measure(word, _descriptionStyle()));
        }
      }
    }
    return longest;
  }

  /// Key of each tile, for tests.
  static const Key tileKey = ValueKey('achievement-tile');

  @override
  Widget build(BuildContext context) {
    final longestWord = AchievementTiles.longestWord(
      items,
      MediaQuery.textScalerOf(context),
    );
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final twoColumnText = (width - gap) / 2 - tileChrome;
          final columns = longestWord <= twoColumnText ? 2 : 1;
          final tileWidth = (width - gap * (columns - 1)) / columns;
          final rows = <Widget>[];
          for (var start = 0; start < items.length; start += columns) {
            final end = math.min(start + columns, items.length);
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = start; i < start + columns; i++) ...[
                      if (i > start) const SizedBox(width: gap),
                      SizedBox(
                        width: tileWidth,
                        child: i < end ? _Tile(item: items[i]) : null,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) const SizedBox(height: gap),
                rows[r],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});

  final AchievementTileData item;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final unlocked = item.unlocked;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AchievementTiles.minTileHeight,
      ),
      child: MergeSemantics(
        child: DecoratedBox(
          key: AchievementTiles.tileKey,
          decoration: unlocked
              ? BoxDecoration(color: palette.surfaceElevated)
              : BoxDecoration(
                  border: Border.all(color: palette.borderSoft, width: 1),
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    unlocked ? ExomIcons.achievement : ExomIcons.locked,
                    size: 20,
                    color: unlocked ? palette.data : palette.textSecondary,
                    semanticLabel: unlocked
                        ? null
                        : AppLocalizations.of(context).achievementLocked,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AchievementTiles._nameStyle(unlocked).copyWith(
                          color: unlocked
                              ? palette.textPrimary
                              : palette.textSecondary,
                        ),
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: AchievementTiles._descriptionStyle().copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
